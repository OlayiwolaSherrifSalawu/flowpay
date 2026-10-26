import { TransactionBuilder } from '@stellar/stellar-sdk';
import {
  InsufficientFundsError,
  InvalidRequestError,
  StellarError,
  StellarSubmitTimeoutError,
  ValidationError,
} from '../../core/errors.js';
import { Money } from '../../core/money.js';
import { isPostgresDb, prisma } from '../../db/index.js';
import { recordInMemoryActivity } from '../../routes/activity.routes.js';
import { StellarAccountService, assertAccountId } from '../../stellar/accounts.js';
import { assetFor, explorerTxUrl, getNetworkConfig, STELLAR_CURRENCIES, type StellarCurrency } from '../../stellar/config.js';
import { accountForUser, resolveRecipient, userForAccount, type ResolvedRecipient } from '../../stellar/directory.js';
import { StellarHorizon } from '../../stellar/horizon.js';
import { buildTransferTx, quoteFunding, assertCanReceive, type FundingQuote } from '../../stellar/payments.js';
import { TransferInterpreter } from '../ai/transfer_interpreter.js';
import type {
  BalanceInspectionResult,
  FundingSourceOption,
  TransferExecuteResult,
  TransferIntent,
  TransferProposalPayload,
} from './types.js';
import { TransferValidator } from './validator.js';

/**
 * Stellar-native transfers.
 *
 *   intent → live funding quotes (real balances + path-finding)
 *          → unsigned tx (payment / path payment) → device signs
 *          → submit → COMPLETED (real hash) | PENDING (timeout, reconcile) | FAILED (reason)
 *
 * The backend never holds user keys. A proposal is only executable with the exact
 * transaction we built (signed tx hash must equal the proposal ID).
 */

interface PendingProposal {
  userId: string;
  sourceAccountId: string;
  intent: TransferIntent;
  recipient: ResolvedRecipient;
  fundingOption: FundingSourceOption;
  expiresAt: number;
}

const pendingProposals = new Map<string, PendingProposal>();

let horizon = new StellarHorizon();
let accounts = new StellarAccountService(horizon);

/** Testing hook: inject a Horizon wrapper backed by a fake gateway. */
export function setTransferHorizonForTests(h: StellarHorizon): void {
  horizon = h;
  accounts = new StellarAccountService(h);
  pendingProposals.clear();
}

function asStellarCurrency(code: string): StellarCurrency {
  const upper = code.toUpperCase();
  if (!(STELLAR_CURRENCIES as readonly string[]).includes(upper)) {
    throw new ValidationError(`${code} is not supported. FlowPay supports ${STELLAR_CURRENCIES.join(', ')}.`);
  }
  return upper as StellarCurrency;
}

function validateIntent(intent: unknown): TransferIntent {
  try {
    return TransferValidator.validateIntent(intent);
  } catch (err) {
    throw new ValidationError((err as Error).message);
  }
}

async function sourceAccountFor(userId: string, claimed?: string): Promise<string> {
  const linked = await accountForUser(userId);
  if (claimed) {
    assertAccountId(claimed);
    if (linked && linked !== claimed) {
      throw new InvalidRequestError('That wallet is not the one linked to your FlowPay account.');
    }
    return claimed;
  }
  if (!linked) throw new InvalidRequestError('Your FlowPay wallet is not set up yet.');
  return linked;
}

function toFundingOption(q: FundingQuote, sourceAccountId: string, target: Money): FundingSourceOption {
  const zero = Money.zero(q.currency);
  const label = q.requiresConversion ? `${q.currency} → ${target.currency} (Stellar path payment)` : `Direct ${q.currency} transfer`;
  return {
    fundingWalletId: `${sourceAccountId}:${q.currency}`,
    fundingCurrency: q.currency,
    fundingWalletName: `${q.currency} balance`,
    availableBalanceMinor: q.available.amountMinor.toString(),
    availableBalanceFormatted: q.available.toMajorString(),
    requiresConversion: q.requiresConversion,
    conversionLabel: label,
    exchangeRate: q.rate,
    convertedDebitMinor: q.sourceAmount.amountMinor.toString(),
    convertedDebitFormatted: q.sourceAmount.toMajorString(),
    // Stellar's network fee is paid in XLM (~0.00001), not in the funding currency.
    networkFeeMinor: '0',
    networkFeeFormatted: zero.toMajorString(),
    serviceFeeMinor: '0',
    serviceFeeFormatted: zero.toMajorString(),
    // Conversion cost is already inside the quoted rate; slippage headroom shown here.
    fxFeeMinor: q.sendMax.subtract(q.sourceAmount).amountMinor.toString(),
    fxFeeFormatted: q.sendMax.subtract(q.sourceAmount).toMajorString(),
    totalDebitMinor: q.sendMax.amountMinor.toString(),
    totalDebitFormatted: q.sendMax.toMajorString(),
    totalDebit: q.sendMax.toMajorString(),
    targetPaymentMinor: target.amountMinor.toString(),
    targetPaymentFormatted: target.toMajorString(),
    // @ts-expect-error extra field consumed by the mobile client
    targetCurrency: target.currency,
  };
}

async function recordActivity(entry: { id: string; action: string; actor: string; details: Record<string, unknown> }) {
  const record = {
    id: entry.id,
    category: 'PERSONAL',
    action: entry.action,
    actor: entry.actor,
    detailsJson: entry.details,
    createdAt: new Date().toISOString(),
  };
  recordInMemoryActivity(record);
  if (isPostgresDb()) {
    try {
      await prisma.auditActivity.create({
        data: { id: record.id, category: record.category, action: record.action, actor: record.actor, detailsJson: record.detailsJson as any },
      });
    } catch (dbErr: any) {
      console.warn('[Transfers] activity persistence failed:', dbErr.message);
    }
  }
}

const newId = (prefix: string) => `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;

export class TransferService {
  /** Natural-language intent → structured intent (AI is advisory; nothing moves here). */
  static async interpret(prompt: string): Promise<TransferIntent> {
    const rawIntent = await TransferInterpreter.interpret(prompt);
    return validateIntent(rawIntent);
  }

  /** Real balances + live quotes for every currency the sender holds. */
  static async inspectBalances(args: { userId: string; accountId?: string; intent: unknown }): Promise<BalanceInspectionResult> {
    const intent = validateIntent(args.intent);
    const target = Money.fromMinor(intent.amountMinor, asStellarCurrency(intent.currency));
    const sourceAccountId = await sourceAccountFor(args.userId, args.accountId);
    const summary = await accounts.getSummary(sourceAccountId);
    if (!summary.exists) {
      return { intent, isDirectFunded: false, allFundingOptions: [], isPossible: false, reason: 'Your wallet is not active on Stellar yet.' };
    }

    const quotes = await quoteFunding(horizon, summary, target);
    const options = quotes.map((q) => toFundingOption(q, sourceAccountId, target));
    const feasible = quotes.filter((q) => q.feasible);
    const recommended = feasible[0] ?? quotes[0];
    return {
      intent,
      isDirectFunded: feasible.some((q) => !q.requiresConversion),
      recommendedFundingOption: recommended ? toFundingOption(recommended, sourceAccountId, target) : undefined,
      allFundingOptions: options,
      isPossible: feasible.length > 0,
      reason: feasible.length > 0 ? undefined : `Not enough balance to send ${target.toMajorString()} ${target.currency}.`,
    };
  }

  /** Re-quotes the chosen funding currency and builds the unsigned Stellar transaction. */
  static async createProposal(args: {
    userId: string;
    accountId?: string;
    intent: unknown;
    fundingOption: { fundingCurrency: string };
  }): Promise<TransferProposalPayload & { recipientAccountId: string; recipientName: string; network: string }> {
    const intent = validateIntent(args.intent);
    const target = Money.fromMinor(intent.amountMinor, asStellarCurrency(intent.currency));
    const fundingCurrency = asStellarCurrency(args.fundingOption?.fundingCurrency ?? '');
    const sourceAccountId = await sourceAccountFor(args.userId, args.accountId);

    const recipient = await resolveRecipient(intent.recipient);
    await assertCanReceive(horizon, recipient, target.currency as StellarCurrency);

    const summary = await accounts.getSummary(sourceAccountId);
    const quote = (await quoteFunding(horizon, summary, target)).find((q) => q.currency === fundingCurrency);
    if (!quote) {
      throw new InvalidRequestError(`You can't fund this transfer from ${fundingCurrency} right now.`);
    }
    if (!quote.feasible) {
      throw new InsufficientFundsError(
        `Your ${fundingCurrency} balance (${quote.available.toMajorString()}) can't cover ${quote.sendMax.toMajorString()} ${fundingCurrency}.`
      );
    }

    const built = await buildTransferTx({ horizon, sourceAccountId, recipient, destAmount: target, funding: quote, purpose: intent.purpose });
    const fundingOption = toFundingOption(quote, sourceAccountId, target);
    pendingProposals.set(built.hash, {
      userId: args.userId,
      sourceAccountId,
      intent,
      recipient,
      fundingOption,
      expiresAt: Date.parse(built.expiresAt),
    });

    return {
      proposalId: built.hash,
      status: 'PENDING_SIGNATURES',
      hashToSign: built.hash,
      signPayload: built.xdr,
      expiresAt: built.expiresAt,
      fundingOption,
      intent,
      recipientAccountId: recipient.accountId,
      recipientName: recipient.displayName,
      network: getNetworkConfig().network,
    };
  }

  /**
   * Submits the device-signed transaction. Returns COMPLETED only for a successful Horizon
   * result; PENDING (with hash) when the outcome is unknown; throws on failure.
   */
  static async executeTransfer(args: { userId: string; proposalId: string; signedXdr: string }): Promise<TransferExecuteResult & { explorerUrl: string }> {
    const proposal = pendingProposals.get(args.proposalId);
    if (!proposal || proposal.userId !== args.userId) {
      throw new InvalidRequestError('This transfer proposal was not found or has expired. Please review the transfer again.');
    }
    if (proposal.expiresAt < Date.now()) {
      pendingProposals.delete(args.proposalId);
      throw new InvalidRequestError('This transfer proposal expired. Please review the transfer again.');
    }

    let signedHash: string;
    try {
      const tx = TransactionBuilder.fromXDR(args.signedXdr, getNetworkConfig().passphrase);
      signedHash = Buffer.from(tx.hash()).toString('hex');
    } catch {
      throw new InvalidRequestError('The signed transaction could not be read.');
    }
    if (signedHash !== args.proposalId) {
      throw new InvalidRequestError('The signed transaction does not match the transfer you reviewed.');
    }

    const { intent, recipient, fundingOption, sourceAccountId } = proposal;
    const baseDetails = {
      transferId: args.proposalId,
      recipient: recipient.displayName,
      recipientAccountId: recipient.accountId,
      amount: Money.fromMinor(intent.amountMinor, intent.currency).toMajorString(),
      currency: intent.currency,
      fundingCurrency: fundingOption.fundingCurrency,
      maxDebited: fundingOption.totalDebitFormatted,
      conversion: fundingOption.conversionLabel,
      exchangeRate: fundingOption.exchangeRate,
      purpose: intent.purpose,
      transactionHash: args.proposalId,
      explorerUrl: explorerTxUrl(args.proposalId),
      network: getNetworkConfig().network,
      sourceAccountId,
    };

    try {
      const result = await horizon.submitSignedXdr(args.signedXdr);
      pendingProposals.delete(args.proposalId);
      const activityId = newId('act_tx');
      const executedAt = new Date().toISOString();
      await recordActivity({
        id: activityId,
        action: 'TRANSFER_COMPLETED',
        actor: args.userId,
        details: { ...baseDetails, status: 'COMPLETED', ledger: result.ledger, executedAt },
      });

      const recipientUser = recipient.userId ?? (await userForAccount(recipient.accountId))?.userId;
      if (recipientUser && recipientUser !== args.userId) {
        const sender = await userForAccount(sourceAccountId);
        await recordActivity({
          id: newId('act_recv'),
          action: 'TRANSFER_RECEIVED',
          actor: recipientUser,
          details: {
            ...baseDetails,
            isIncoming: true,
            sender: args.userId,
            counterparty: sender?.fullName ?? sourceAccountId,
            amountReceived: baseDetails.amount,
            currencyReceived: intent.currency,
            status: 'COMPLETED',
            receivedAt: executedAt,
          },
        });
      }

      if (isPostgresDb()) {
        try {
          await prisma.transfer.create({
            data: {
              id: newId('tx'),
              proposalId: args.proposalId,
              userId: args.userId,
              recipient: recipient.displayName,
              recipientAddress: recipient.accountId,
              amountMinor: BigInt(intent.amountMinor),
              currency: intent.currency,
              fundingWalletId: fundingOption.fundingWalletId,
              fundingCurrency: fundingOption.fundingCurrency,
              totalDebitMinor: BigInt(fundingOption.totalDebitMinor),
              exchangeRate: fundingOption.exchangeRate?.toString() ?? null,
              feeMinor: 0n,
              status: 'COMPLETED',
              transactionHash: result.hash,
              purpose: intent.purpose ?? null,
              executedAt: new Date(executedAt),
            },
          });
        } catch (dbErr: any) {
          console.warn('[Transfers] transfer row persistence failed:', dbErr.message);
        }
      }

      return {
        proposalId: args.proposalId,
        status: 'COMPLETED',
        transactionHash: result.hash,
        timestamp: executedAt,
        auditActivityId: activityId,
        explorerUrl: explorerTxUrl(result.hash),
        details: {
          recipient: recipient.displayName,
          targetAmount: baseDetails.amount,
          targetCurrency: intent.currency,
          fundingWalletId: fundingOption.fundingWalletId,
          fundingCurrency: fundingOption.fundingCurrency,
          totalDebited: fundingOption.totalDebitFormatted,
          conversionLabel: fundingOption.conversionLabel,
          exchangeRate: fundingOption.exchangeRate,
          purpose: intent.purpose,
        },
      };
    } catch (err) {
      if (err instanceof StellarSubmitTimeoutError) {
        await recordActivity({
          id: newId('act_tx_pending'),
          action: 'TRANSFER_PENDING',
          actor: args.userId,
          details: { ...baseDetails, status: 'PENDING', note: 'Submission timed out; awaiting network confirmation.' },
        });
        throw err;
      }
      if (err instanceof StellarError) {
        await recordActivity({
          id: newId('act_tx_failed'),
          action: 'TRANSFER_FAILED',
          actor: args.userId,
          details: { ...baseDetails, status: 'FAILED', error: err.message, resultCodes: err.resultCodes },
        });
      }
      throw err;
    }
  }

  /** Indicative mid rates (units per 1 USD) from live Stellar liquidity. */
  static async getExchangeRates(): Promise<Record<string, number>> {
    const rates: Record<string, number> = { USD: 1 };
    const oneHundredUsd = '100';
    for (const c of STELLAR_CURRENCIES) {
      if (c === 'USD') continue;
      const quotes = await horizon.quoteStrictReceive([assetFor(c)], assetFor('USD'), oneHundredUsd);
      const best = quotes.reduce<number | null>((min, q) => (min === null || Number(q.sourceAmount) < min ? Number(q.sourceAmount) : min), null);
      if (best) rates[c] = best / 100;
    }
    return rates;
  }
}

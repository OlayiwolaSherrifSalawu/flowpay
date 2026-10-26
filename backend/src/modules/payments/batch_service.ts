import { InvalidRequestError, StellarError, StellarSubmitTimeoutError } from '../../core/errors.js';
import { assertAccountId } from '../../stellar/accounts.js';
import { buildBatch, serializeLeg, type BatchLegInput, type BatchLegQuote } from '../../stellar/batch.js';
import { explorerTxUrl, getNetworkConfig } from '../../stellar/config.js';
import { accountForUser, userForAccount } from '../../stellar/directory.js';
import { StellarHorizon } from '../../stellar/horizon.js';
import { ProposalStore, submitProposal } from '../../stellar/proposals.js';
import { newId, recordActivity } from '../activity/record.js';

export interface BatchContext {
  /** What this batch is for, e.g. 'AI_PLAN', 'MISSION', 'FX_CONVERT'. Shown in activity. */
  purpose: string;
  reference?: string;
}

interface BatchMeta {
  sourceAccountId: string;
  legs: BatchLegQuote[];
  context: BatchContext;
}

const store = new ProposalStore<BatchMeta>();
let horizon = new StellarHorizon();

export function setBatchHorizonForTests(h: StellarHorizon): void {
  horizon = h;
  store.clear();
}

export async function resolveSourceAccount(userId: string, claimed?: string): Promise<string> {
  const linked = await accountForUser(userId);
  if (claimed) {
    assertAccountId(claimed);
    if (linked && linked !== claimed) throw new InvalidRequestError('That wallet is not the one linked to your FlowPay account.');
    return claimed;
  }
  if (!linked) throw new InvalidRequestError('Your FlowPay wallet is not set up yet.');
  return linked;
}

export class BatchPaymentService {
  /** Quotes every leg and builds ONE unsigned transaction for the device to sign. */
  static async propose(args: { userId: string; accountId?: string; legs: BatchLegInput[]; memo?: string; context: BatchContext }) {
    const sourceAccountId = await resolveSourceAccount(args.userId, args.accountId);
    const built = await buildBatch({ horizon, sourceAccountId, legs: args.legs, memo: args.memo });
    store.put(built.hash, args.userId, built.expiresAt, { sourceAccountId, legs: built.legs, context: args.context });
    return {
      proposalId: built.hash,
      hashToSign: built.hash,
      signPayload: built.xdr,
      expiresAt: built.expiresAt,
      network: getNetworkConfig().network,
      legs: built.legs.map(serializeLeg),
      maxTotals: built.maxTotals,
      status: 'PENDING_SIGNATURES',
    };
  }

  /**
   * Submits the signed batch. COMPLETED → every leg settled (same hash). PENDING → unknown
   * outcome (rethrows StellarSubmitTimeoutError). Failure → nothing settled (atomic).
   */
  static async execute(args: { userId: string; proposalId: string; signedXdr: string }) {
    const base = { transactionHash: args.proposalId, explorerUrl: explorerTxUrl(args.proposalId), network: getNetworkConfig().network };
    let meta: BatchMeta | undefined;
    try {
      const { result, proposal } = await submitProposal({ store, horizon, userId: args.userId, proposalId: args.proposalId, signedXdr: args.signedXdr });
      meta = proposal.meta;
      const executedAt = new Date().toISOString();
      const sender = await userForAccount(meta.sourceAccountId);

      for (const leg of meta.legs) {
        const legDetails = {
          ...base,
          purpose: meta.context.purpose,
          reference: meta.context.reference,
          label: leg.label,
          recipient: leg.recipient.displayName,
          recipientAccountId: leg.recipient.accountId,
          amount: leg.destAmount.toMajorString(),
          currency: leg.destCurrency,
          fundingCurrency: leg.fundingCurrency,
          maxDebited: leg.maxSourceAmount.toMajorString(),
          conversion: leg.requiresConversion ? `${leg.fundingCurrency} → ${leg.destCurrency}` : 'Direct',
          lockedUntil: leg.lockUntil,
          status: 'COMPLETED',
          ledger: result.ledger,
          executedAt,
        };
        await recordActivity({
          action: leg.lockUntil ? 'SAVINGS_LOCKED' : leg.recipient.self ? 'FX_CONVERTED' : 'TRANSFER_COMPLETED',
          actor: args.userId,
          details: legDetails,
        });
        if (!leg.recipient.self && leg.recipient.userId && leg.recipient.userId !== args.userId) {
          await recordActivity({
            id: newId('act_recv'),
            action: 'TRANSFER_RECEIVED',
            actor: leg.recipient.userId,
            details: { ...legDetails, isIncoming: true, counterparty: sender?.fullName ?? meta.sourceAccountId, amountReceived: legDetails.amount },
          });
        }
      }
      return { ...base, proposalId: args.proposalId, status: 'COMPLETED', ledger: result.ledger, executedAt, legs: meta.legs.map(serializeLeg) };
    } catch (err) {
      if (err instanceof StellarSubmitTimeoutError || err instanceof StellarError) {
        await recordActivity({
          action: err instanceof StellarSubmitTimeoutError ? 'BATCH_PENDING' : 'BATCH_FAILED',
          actor: args.userId,
          details: { ...base, status: err instanceof StellarSubmitTimeoutError ? 'PENDING' : 'FAILED', error: err.message, resultCodes: err.resultCodes },
        });
      }
      throw err;
    }
  }
}

import { Keypair, Operation, TransactionBuilder } from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { InvalidRequestError, StellarError } from '../core/errors.js';
import { Money } from '../core/money.js';
import { summarizeAccount } from './accounts.js';
import { toStellarAmount } from './amount.js';
import { assetFor, getNetworkConfig, TESTNET_REFERENCE_RATES_PER_USD, type StellarCurrency } from './config.js';
import { StellarHorizon, type SubmitResult } from './horizon.js';

/**
 * TESTNET ONLY: sends clearly-labelled test funds from FlowPay's testnet distributor so a
 * new wallet has something to send. Refuses on mainnet, and tops up only wallets that are
 * nearly empty in that currency (so it can't be farmed).
 */
export const FAUCET_USD_EQUIVALENT = 1000n;
const TOP_UP_THRESHOLD_USD = 50n;

function usdEquivalent(units: bigint, currency: StellarCurrency): Money {
  const [w, f = ''] = TESTNET_REFERENCE_RATES_PER_USD[currency].split('.');
  const scale = 10n ** BigInt(f.length);
  const rateScaled = BigInt(w) * scale + BigInt(f || '0');
  return Money.fromMinor((units * 100n * rateScaled) / scale, currency);
}

export async function claimTestFunds(horizon: StellarHorizon, accountId: string, currency: StellarCurrency): Promise<SubmitResult & { amount: Money }> {
  if (getNetworkConfig().network !== 'testnet') {
    throw new InvalidRequestError('Test funds are only available on testnet.');
  }
  if (!env.STELLAR_DISTRIBUTOR_SECRET) {
    throw new StellarError('Testnet faucet is not configured (run npm run stellar:bootstrap).', 503, 'STELLAR_FAUCET_UNCONFIGURED');
  }

  const summary = summarizeAccount(accountId, await horizon.loadAccount(accountId));
  if (summary.missingTrustlines.includes(currency)) {
    throw new InvalidRequestError(`Enable ${currency} in your wallet before claiming test funds.`);
  }
  const held = summary.balances.find((b) => b.currency === currency)?.balance ?? Money.zero(currency);
  if (held.isGreaterThan(usdEquivalent(TOP_UP_THRESHOLD_USD, currency))) {
    throw new InvalidRequestError(`This wallet already has ${currency} test funds.`);
  }

  const amount = usdEquivalent(FAUCET_USD_EQUIVALENT, currency);
  const distributor = Keypair.fromSecret(env.STELLAR_DISTRIBUTOR_SECRET);
  const source = await horizon.loadAccount(distributor.publicKey());
  const tx = new TransactionBuilder(source, { fee: String(await horizon.baseFee()), networkPassphrase: getNetworkConfig().passphrase })
    .addOperation(Operation.payment({ destination: accountId, asset: assetFor(currency), amount: toStellarAmount(amount) }))
    .setTimeout(60)
    .build();
  tx.sign(distributor);
  const result = await horizon.submitSignedXdr(tx.toXDR());
  return { ...result, amount };
}

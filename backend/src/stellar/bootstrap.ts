/**
 * Testnet bootstrap: creates FlowPay's Stellar treasury.
 *
 *   npm run stellar:bootstrap
 *
 * 1. Generates (or reuses from .env) an ISSUER and a DISTRIBUTOR keypair.
 * 2. Funds both with Friendbot test XLM.
 * 3. Distributor trusts USD/CAD/MXN/GBP/NGN; issuer mints the supply to the distributor.
 * 4. Distributor seeds USD/<X> constant-product liquidity pools at reference FX rates, so
 *    path payments can convert between every pair (X → USD → Y).
 * 5. Writes STELLAR_ASSET_ISSUER / STELLAR_ISSUER_SECRET / STELLAR_DISTRIBUTOR_SECRET to backend/.env.
 *
 * Idempotent: re-running skips work already done. Refuses to run unless STELLAR_NETWORK=testnet.
 */
import fs from 'node:fs';
import path from 'node:path';
import {
  Asset,
  Horizon,
  Keypair,
  LiquidityPoolAsset,
  LiquidityPoolFeeV18,
  Operation,
  TransactionBuilder,
  getLiquidityPoolId,
} from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { getNetworkConfig, STELLAR_CURRENCIES, TESTNET_REFERENCE_RATES_PER_USD, type StellarCurrency } from './config.js';
import { mapHorizonError } from './horizon.js';

const USD_POOL_DEPTH = 1_000_000n; // USD per side of each pool
const USD_SUPPLY = 100_000_000n; // USD-equivalent minted per currency

const cfg = getNetworkConfig();
const server = new Horizon.Server(cfg.horizonUrl);

function log(msg: string) {
  console.log(`[stellar:bootstrap] ${msg}`);
}

/** Multiplies an integer by a decimal-string rate, returning a 7-dp Stellar amount string. */
function scale(units: bigint, rate: string): string {
  const [w, f = ''] = rate.split('.');
  const frac = f.padEnd(7, '0').slice(0, 7);
  const rate7 = BigInt(w) * 10_000_000n + BigInt(frac);
  const total = units * rate7; // 7 implied decimals
  return `${total / 10_000_000n}.${(total % 10_000_000n).toString().padStart(7, '0')}`;
}

async function friendbot(publicKey: string) {
  const res = await fetch(`${cfg.friendbotUrl}?addr=${publicKey}`);
  if (res.ok) return log(`funded ${publicKey} with test XLM`);
  const body = (await res.json().catch(() => ({}))) as any;
  if (body?.extras?.result_codes?.operations?.includes('op_already_exists') || /already/i.test(body?.detail ?? '')) {
    return log(`${publicKey} already funded`);
  }
  throw new Error(`Friendbot failed for ${publicKey}: ${body?.detail ?? res.status}`);
}

async function submit(label: string, source: Keypair, ops: any[], extraSigners: Keypair[] = []) {
  if (ops.length === 0) return log(`${label}: nothing to do`);
  const account = await server.loadAccount(source.publicKey());
  const builder = new TransactionBuilder(account, { fee: String(await server.fetchBaseFee() * 10), networkPassphrase: cfg.passphrase });
  ops.forEach((op) => builder.addOperation(op));
  const tx = builder.setTimeout(120).build();
  tx.sign(source, ...extraSigners);
  try {
    const res = await server.submitTransaction(tx);
    log(`${label}: ✓ ${res.hash}  ${cfg.explorerBaseUrl}/tx/${res.hash}`);
  } catch (err) {
    throw mapHorizonError(err, Buffer.from(tx.hash()).toString('hex'));
  }
}

function upsertEnv(file: string, values: Record<string, string>) {
  let text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  for (const [key, value] of Object.entries(values)) {
    const line = `${key}=${value}`;
    const re = new RegExp(`^${key}=.*$`, 'm');
    text = re.test(text) ? text.replace(re, line) : `${text.replace(/\n?$/, '\n')}${line}\n`;
  }
  fs.writeFileSync(file, text);
}

async function main() {
  if (cfg.network !== 'testnet') throw new Error('stellar:bootstrap only runs against testnet.');

  const issuer = process.env.STELLAR_ISSUER_SECRET ? Keypair.fromSecret(process.env.STELLAR_ISSUER_SECRET) : Keypair.random();
  const distributor = env.STELLAR_DISTRIBUTOR_SECRET ? Keypair.fromSecret(env.STELLAR_DISTRIBUTOR_SECRET) : Keypair.random();
  log(`issuer       ${issuer.publicKey()}`);
  log(`distributor  ${distributor.publicKey()}`);

  // Persist keys first so a crash mid-way never orphans funded accounts.
  const envFile = path.resolve(process.cwd(), '.env');
  upsertEnv(envFile, {
    STELLAR_NETWORK: 'testnet',
    STELLAR_ASSET_ISSUER: issuer.publicKey(),
    STELLAR_ISSUER_SECRET: issuer.secret(),
    STELLAR_DISTRIBUTOR_SECRET: distributor.secret(),
  });
  log(`wrote keys to ${envFile}`);

  await friendbot(issuer.publicKey());
  await friendbot(distributor.publicKey());

  const assets = Object.fromEntries(STELLAR_CURRENCIES.map((c) => [c, new Asset(c, issuer.publicKey())])) as Record<StellarCurrency, Asset>;
  const usd = assets.USD;
  const pools = STELLAR_CURRENCIES.filter((c) => c !== 'USD').map((c) => {
    const [a, b] = Asset.compare(usd, assets[c]) < 0 ? [usd, assets[c]] : [assets[c], usd];
    return {
      currency: c,
      shareAsset: new LiquidityPoolAsset(a, b, LiquidityPoolFeeV18),
      id: Buffer.from(getLiquidityPoolId('constant_product', { assetA: a, assetB: b, fee: LiquidityPoolFeeV18 })).toString('hex'),
      usdIsA: a === usd,
    };
  });

  // 1) Distributor trustlines: assets, then pool shares (order matters inside one tx).
  const dist = await server.loadAccount(distributor.publicKey());
  const has = (pred: (b: any) => boolean) => dist.balances.some(pred);
  const trustOps = [
    ...STELLAR_CURRENCIES.filter((c) => !has((b) => b.asset_code === c && b.asset_issuer === issuer.publicKey())).map((c) =>
      Operation.changeTrust({ asset: assets[c] })
    ),
    ...pools.filter((p) => !has((b) => b.liquidity_pool_id === p.id)).map((p) => Operation.changeTrust({ asset: p.shareAsset })),
  ];
  await submit('distributor trustlines', distributor, trustOps);

  // 2) Mint supply to distributor (only for currencies it holds none of).
  const distAfter = await server.loadAccount(distributor.publicKey());
  const mintOps = STELLAR_CURRENCIES.filter((c) => {
    const line = distAfter.balances.find((b: any) => b.asset_code === c && b.asset_issuer === issuer.publicKey()) as any;
    return !line || Number(line.balance) === 0;
  }).map((c) =>
    Operation.payment({
      destination: distributor.publicKey(),
      asset: assets[c],
      amount: scale(USD_SUPPLY, TESTNET_REFERENCE_RATES_PER_USD[c]),
      source: issuer.publicKey(),
    })
  );
  if (mintOps.length) await submit('mint supply', distributor, mintOps, [issuer]);
  else log('mint supply: nothing to do');

  // 3) Seed empty pools at reference rates (±1% price tolerance).
  const depositOps = [];
  for (const p of pools) {
    const pool = await server.liquidityPools().liquidityPoolId(p.id).call().catch(() => null);
    if (pool && Number(pool.total_shares) > 0) {
      log(`pool USD/${p.currency} already seeded (${p.id.slice(0, 8)}…)`);
      continue;
    }
    const usdAmt = scale(USD_POOL_DEPTH, '1');
    const otherAmt = scale(USD_POOL_DEPTH, TESTNET_REFERENCE_RATES_PER_USD[p.currency]);
    const [amtA, amtB] = p.usdIsA ? [usdAmt, otherAmt] : [otherAmt, usdAmt];
    const price = Number(amtA) / Number(amtB);
    depositOps.push(
      Operation.liquidityPoolDeposit({
        liquidityPoolId: p.id,
        maxAmountA: amtA,
        maxAmountB: amtB,
        minPrice: (price * 0.99).toPrecision(7),
        maxPrice: (price * 1.01).toPrecision(7),
      })
    );
  }
  await submit('seed liquidity pools', distributor, depositOps);

  log('done. Assets:');
  for (const c of STELLAR_CURRENCIES) log(`  ${c}:${issuer.publicKey()}`);
}

main().catch((err) => {
  console.error('[stellar:bootstrap] FAILED:', err?.message ?? err, err?.resultCodes ?? '');
  process.exit(1);
});

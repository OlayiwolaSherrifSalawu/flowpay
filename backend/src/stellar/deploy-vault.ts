/**
 * Deploys FlowPay's PayrollVault Soroban contract to TESTNET (idempotent where possible).
 *
 *   cd contracts && stellar contract build          # → target/wasm32v1-none/release/payroll_vault.wasm
 *   cd backend && npm run stellar:deploy-vault
 *
 * 1. Deploys the Stellar Asset Contract for FlowPay USD (skipped if it exists), so the
 *    classic USD asset can be held by contracts.
 * 2. Uploads the contract WASM and creates a new PayrollVault instance, with the
 *    distributor account as deployer (it only pays fees; it has no special rights).
 * 3. Writes STELLAR_PAYROLL_VAULT_ID to backend/.env.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { Address, Keypair, Operation, TransactionBuilder, rpc, scValToNative, xdr, type Transaction } from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { assetFor, getNetworkConfig } from './config.js';
import { PayrollVaultClient } from './soroban.js';

const cfg = getNetworkConfig();
const server = new rpc.Server(env.SOROBAN_RPC_URL ?? 'https://soroban-testnet.stellar.org');
const WASM = path.resolve(process.cwd(), '../contracts/target/wasm32v1-none/release/payroll_vault.wasm');

function log(msg: string) {
  console.log(`[stellar:deploy-vault] ${msg}`);
}

async function invoke(label: string, signer: Keypair, op: any): Promise<unknown> {
  const source = await server.getAccount(signer.publicKey());
  const tx = new TransactionBuilder(source, { fee: '1000000', networkPassphrase: cfg.passphrase }).addOperation(op).setTimeout(120).build();
  const prepared = (await server.prepareTransaction(tx)) as Transaction;
  prepared.sign(signer);
  const sent = await server.sendTransaction(prepared);
  if (sent.status === 'ERROR') throw new Error(`${label}: rejected (${JSON.stringify(sent.errorResult)})`);
  for (let i = 0; i < 30; i++) {
    const res = await server.getTransaction(sent.hash);
    if (res.status === rpc.Api.GetTransactionStatus.SUCCESS) {
      log(`${label}: ✓ ${sent.hash}  ${cfg.explorerBaseUrl}/tx/${sent.hash}`);
      return res.returnValue ? scValToNative(res.returnValue) : null;
    }
    if (res.status === rpc.Api.GetTransactionStatus.FAILED) throw new Error(`${label}: failed on-chain (${sent.hash})`);
    await new Promise((r) => setTimeout(r, 1500));
  }
  throw new Error(`${label}: not confirmed yet — check ${cfg.explorerBaseUrl}/tx/${sent.hash} before retrying`);
}

function upsertEnv(file: string, key: string, value: string) {
  let text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const re = new RegExp(`^${key}=.*$`, 'm');
  text = re.test(text) ? text.replace(re, `${key}=${value}`) : `${text.replace(/\n?$/, '\n')}${key}=${value}\n`;
  fs.writeFileSync(file, text);
}

async function main() {
  if (cfg.network !== 'testnet') throw new Error('stellar:deploy-vault only runs against testnet.');
  if (!env.STELLAR_DISTRIBUTOR_SECRET) throw new Error('Run `npm run stellar:bootstrap` first (needs STELLAR_DISTRIBUTOR_SECRET).');
  if (!fs.existsSync(WASM)) throw new Error(`Contract not built: ${WASM}\nRun \`stellar contract build\` in contracts/.`);
  const deployer = Keypair.fromSecret(env.STELLAR_DISTRIBUTOR_SECRET);

  // 1) Stellar Asset Contract for USD.
  const usd = assetFor('USD');
  const sacId = PayrollVaultClient.usdTokenId();
  try {
    await server.getContractData(sacId, xdr.ScVal.scvLedgerKeyContractInstance());
    log(`USD asset contract already deployed: ${sacId}`);
  } catch {
    await invoke('deploy USD asset contract', deployer, Operation.createStellarAssetContract({ asset: usd }));
  }

  // 2) Upload WASM + create the vault.
  const wasm = fs.readFileSync(WASM);
  log(`wasm ${wasm.length} bytes, sha256 ${crypto.createHash('sha256').update(wasm).digest('hex')}`);
  await invoke('upload PayrollVault wasm', deployer, Operation.uploadContractWasm({ wasm }));
  const created = await invoke(
    'create PayrollVault',
    deployer,
    Operation.createCustomContract({
      address: new Address(deployer.publicKey()),
      wasmHash: crypto.createHash('sha256').update(wasm).digest(),
      salt: crypto.randomBytes(32),
    })
  );
  const contractId = String(created);
  if (!contractId.startsWith('C')) throw new Error(`Unexpected contract id: ${contractId}`);

  // 3) Persist.
  upsertEnv(path.resolve(process.cwd(), '.env'), 'STELLAR_PAYROLL_VAULT_ID', contractId);
  log(`PayrollVault ${contractId}  ${cfg.explorerBaseUrl}/contract/${contractId}`);
  log(`USD token    ${sacId}`);
  log('wrote STELLAR_PAYROLL_VAULT_ID to backend/.env');
}

main().catch((err) => {
  console.error('[stellar:deploy-vault] FAILED:', err?.message ?? err);
  process.exit(1);
});

import { Keypair } from '@stellar/stellar-sdk';
import { env } from '../config/env.js';
import { InvalidRequestError, NotFoundError } from '../core/errors.js';
import { isPostgresDb, prisma } from '../db/index.js';
import { registeredUsers } from '../routes/auth.routes.js';
import { accountForUser, userForAccount } from './directory.js';
import { STELLAR_CURRENCIES, assetFor, getNetworkConfig, type StellarCurrency } from './config.js';

/**
 * SEP-1 (stellar.toml) + SEP-2 (federation) for FlowPay.
 *
 * A user can claim a payment name ("ada") and be paid at `ada*<home domain>` from
 * any Stellar wallet. Names are strictly opt-in: federation never answers for an
 * email or a user who hasn't claimed a name, so it can't be used to discover who
 * has a FlowPay account.
 */

const HANDLE_RE = /^[a-z0-9][a-z0-9._-]{2,31}$/;
const RESERVED = new Set(['admin', 'administrator', 'support', 'help', 'flowpay', 'root', 'system', 'security', 'payroll', 'stellar', 'anchor', 'issuer', 'treasury', 'test']);

// handle → userId (memory mirror; Postgres is the source of truth when connected).
const userByHandle = new Map<string, string>();

export function normalizeHandle(raw: string): string {
  const h = String(raw ?? '').trim().toLowerCase();
  if (!HANDLE_RE.test(h)) {
    throw new InvalidRequestError('Payment names are 3–32 characters: letters, numbers, ".", "_" or "-", starting with a letter or number.');
  }
  if (RESERVED.has(h)) throw new InvalidRequestError(`"${h}" is reserved. Pick another name.`);
  return h;
}

/** The domain FlowPay federation addresses live on: FLOWPAY_HOME_DOMAIN, else the host serving the request. */
export function homeDomainFor(requestHost?: string): string | null {
  const configured = env.FLOWPAY_HOME_DOMAIN?.trim().toLowerCase();
  if (configured) return configured;
  return requestHost ? requestHost.toLowerCase().split(':')[0] : null;
}

async function userIdForHandle(handle: string): Promise<string | null> {
  if (userByHandle.has(handle)) return userByHandle.get(handle)!;
  if (isPostgresDb()) {
    const row = await prisma.user.findUnique({ where: { stellarHandle: handle } });
    if (row) {
      userByHandle.set(handle, row.id);
      return row.id;
    }
  }
  return null;
}

export async function handleForUser(userId: string): Promise<string | null> {
  const mem = registeredUsers.get(userId)?.stellarHandle;
  if (mem) return mem;
  if (isPostgresDb()) {
    const row = await prisma.user.findUnique({ where: { id: userId } });
    if (row?.stellarHandle) return row.stellarHandle;
  }
  return null;
}

/** Claims (or changes) the signed-in user's payment name. Requires a linked wallet. */
export async function claimHandle(userId: string, rawHandle: string): Promise<string> {
  const handle = normalizeHandle(rawHandle);
  if (!(await accountForUser(userId))) {
    throw new InvalidRequestError('Set up your wallet before claiming a payment name.');
  }
  const owner = await userIdForHandle(handle);
  if (owner && owner !== userId) throw new InvalidRequestError(`"${handle}" is already taken.`);

  const previous = await handleForUser(userId);
  if (isPostgresDb()) {
    await prisma.user.update({ where: { id: userId }, data: { stellarHandle: handle } });
  }
  if (previous && previous !== handle) userByHandle.delete(previous);
  userByHandle.set(handle, userId);
  const mem = registeredUsers.get(userId);
  if (mem) mem.stellarHandle = handle;
  return handle;
}

export interface FederationRecord {
  stellar_address: string;
  account_id: string;
}

/** SEP-2 `type=name`. Only answers for claimed names on our own domain. */
export async function federationByName(q: string, domain: string): Promise<FederationRecord> {
  const [name, qDomain, ...rest] = String(q ?? '').split('*');
  if (!name || !qDomain || rest.length) throw new InvalidRequestError('Expected a Stellar address like name*domain.');
  if (qDomain.toLowerCase() !== domain) throw new NotFoundError(`${qDomain} is not served by this federation server.`);
  const handle = name.toLowerCase();
  const userId = await userIdForHandle(handle);
  const accountId = userId ? await accountForUser(userId) : null;
  if (!accountId) throw new NotFoundError('No account with that name.');
  return { stellar_address: `${handle}*${domain}`, account_id: accountId };
}

/** SEP-2 `type=id`. Reverse lookup only for accounts whose owner claimed a name. */
export async function federationById(accountId: string, domain: string): Promise<FederationRecord> {
  const owner = await userForAccount(String(accountId ?? ''));
  const handle = owner ? await handleForUser(owner.userId) : null;
  if (!owner || !handle) throw new NotFoundError('No public name for that account.');
  return { stellar_address: `${handle}*${domain}`, account_id: accountId };
}

const CURRENCY_NAMES: Record<StellarCurrency, string> = {
  USD: 'US Dollar',
  CAD: 'Canadian Dollar',
  MXN: 'Mexican Peso',
  GBP: 'British Pound',
  NGN: 'Nigerian Naira',
};

function tomlString(value: string): string {
  return JSON.stringify(value); // TOML basic strings share JSON's escaping rules for our content.
}

/** SEP-1 stellar.toml describing FlowPay's federation server, accounts and test assets. */
export function buildStellarToml(domain: string): string {
  const net = getNetworkConfig();
  const accounts: string[] = [];
  const lines: string[] = [];
  // Only FlowPay's own issuer: an operator may point some currencies at third-party
  // assets (e.g. Circle USDC), and we must not publish claims about those.
  const issuer = env.STELLAR_ASSET_ISSUER ?? null;
  if (issuer) accounts.push(issuer);
  if (env.STELLAR_DISTRIBUTOR_SECRET) {
    try {
      accounts.push(Keypair.fromSecret(env.STELLAR_DISTRIBUTOR_SECRET).publicKey());
    } catch {
      // Malformed secret: leave it out rather than publish something wrong.
    }
  }

  lines.push('VERSION = "2.7.0"');
  lines.push(`NETWORK_PASSPHRASE = ${tomlString(net.passphrase)}`);
  lines.push(`FEDERATION_SERVER = ${tomlString(`https://${domain}/federation`)}`);
  if (accounts.length) lines.push(`ACCOUNTS = [${[...new Set(accounts)].map(tomlString).join(', ')}]`);
  lines.push('');
  lines.push('[DOCUMENTATION]');
  lines.push('ORG_NAME = "FlowPay"');
  lines.push(`ORG_URL = ${tomlString(`https://${domain}`)}`);
  lines.push(
    `ORG_DESCRIPTION = ${tomlString('Cross-border payroll and personal money on Stellar: one employer pays a team in many countries in a single atomic transaction, signed on device.')}`
  );
  lines.push('ORG_GITHUB = "flowpay-bmoni/flowpay"');

  const isTestnet = net.network === 'testnet';
  for (const code of STELLAR_CURRENCIES) {
    let asset;
    try {
      asset = assetFor(code);
    } catch {
      continue;
    }
    if (!issuer || asset.getIssuer() !== issuer) continue;
    lines.push('');
    lines.push('[[CURRENCIES]]');
    lines.push(`code = ${tomlString(asset.getCode())}`);
    lines.push(`issuer = ${tomlString(issuer)}`);
    lines.push('display_decimals = 2');
    lines.push(`name = ${tomlString(isTestnet ? `${CURRENCY_NAMES[code]} (FlowPay test asset)` : CURRENCY_NAMES[code])}`);
    if (isTestnet) {
      lines.push('status = "test"');
      lines.push('is_asset_anchored = false');
      lines.push(
        `desc = ${tomlString(`Testnet-only ${code} issued by FlowPay for demos and testing. Not redeemable and worth nothing.`)}`
      );
    }
  }
  return lines.join('\n') + '\n';
}

/** Testing hook. */
export function resetFederationForTests(): void {
  userByHandle.clear();
}

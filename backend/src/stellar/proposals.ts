import { TransactionBuilder } from '@stellar/stellar-sdk';
import { InvalidRequestError } from '../core/errors.js';
import { getNetworkConfig } from './config.js';
import { StellarHorizon, type SubmitResult } from './horizon.js';

/**
 * Server-built, device-signed transactions. A proposal is keyed by its transaction hash,
 * belongs to one user, expires with the transaction, and can be submitted once. The
 * signed envelope must hash to the proposal ID, so a client can never swap in a
 * different transaction than the one it reviewed.
 */
export interface StoredProposal<T> {
  userId: string;
  expiresAt: number;
  meta: T;
}

export class ProposalStore<T> {
  private readonly items = new Map<string, StoredProposal<T>>();

  put(hash: string, userId: string, expiresAtIso: string, meta: T): void {
    this.prune();
    this.items.set(hash, { userId, expiresAt: Date.parse(expiresAtIso), meta });
  }

  /** Returns the proposal if it exists, belongs to `userId`, and hasn't expired. */
  take(proposalId: string, userId: string): StoredProposal<T> {
    const p = this.items.get(proposalId);
    if (!p || p.userId !== userId) {
      throw new InvalidRequestError('This proposal was not found or has expired. Please review it again.');
    }
    if (p.expiresAt < Date.now()) {
      this.items.delete(proposalId);
      throw new InvalidRequestError('This proposal expired. Please review it again.');
    }
    return p;
  }

  consume(proposalId: string): void {
    this.items.delete(proposalId);
  }

  clear(): void {
    this.items.clear();
  }

  private prune(): void {
    const now = Date.now();
    for (const [k, v] of this.items) if (v.expiresAt < now) this.items.delete(k);
  }
}

/** Throws unless `signedXdr` is the exact transaction identified by `proposalId`. */
export function assertSignedMatches(proposalId: string, signedXdr: string): void {
  let hash: string;
  try {
    hash = Buffer.from(TransactionBuilder.fromXDR(signedXdr, getNetworkConfig().passphrase).hash()).toString('hex');
  } catch {
    throw new InvalidRequestError('The signed transaction could not be read.');
  }
  if (hash !== proposalId) {
    throw new InvalidRequestError('The signed transaction does not match what you reviewed.');
  }
}

/** Verify + submit + consume. Errors propagate unchanged (FAILED / PENDING semantics). */
export async function submitProposal<T>(args: {
  store: ProposalStore<T>;
  horizon: StellarHorizon;
  userId: string;
  proposalId: string;
  signedXdr: string;
}): Promise<{ result: SubmitResult; proposal: StoredProposal<T> }> {
  const proposal = args.store.take(args.proposalId, args.userId);
  assertSignedMatches(args.proposalId, args.signedXdr);
  const result = await args.horizon.submitSignedXdr(args.signedXdr);
  args.store.consume(args.proposalId);
  return { result, proposal };
}

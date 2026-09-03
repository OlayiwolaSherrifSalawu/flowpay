import { bmoniClient } from '../../bmoni/client.js';
import type { OwnerProofChallenge, SmartWallet, WalletBalance } from '../../bmoni/types.js';

export class WalletService {
  static async getBalances(userId: string): Promise<WalletBalance[]> {
    try {
      const balances = await bmoniClient.listAccountBalances(userId);
      if (balances && balances.length > 0) return balances;
    } catch (err) {
      console.warn('[WalletService] BMONI API getBalances fallback to sandbox defaults:', err);
    }

    // Deterministic fallback balances for sandbox / demo
    return [
      { currency: 'USDB', balance: '12450.00', symbol: '$' },
      { currency: 'CNGN', balance: '4850000.00', symbol: '₦' },
      { currency: 'MEXe', balance: '52000.00', symbol: 'Mex$' },
      { currency: 'EURe', balance: '3400.00', symbol: '€' },
    ];
  }

  static async getWallets(userId: string): Promise<SmartWallet[]> {
    try {
      const wallets = await bmoniClient.listAccountSmartWallets(userId);
      if (wallets && wallets.length > 0) return wallets;
    } catch (err) {
      console.warn('[WalletService] BMONI API getWallets fallback to sandbox defaults:', err);
    }

    return [
      {
        id: 'sw_usdb_sandbox_01',
        address: '0x8f2d6B48e89405d414a3D65B2Af6d73f1d93E3C1',
        currency: 'USDB',
        chain: 'base-sepolia',
        status: 'active',
        userOwnerAddress: '0x71C...a19',
        createdAt: new Date().toISOString(),
      },
      {
        id: 'sw_cngn_sandbox_02',
        address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
        currency: 'CNGN',
        chain: 'base-sepolia',
        status: 'active',
        userOwnerAddress: '0x71C...a19',
        createdAt: new Date().toISOString(),
      },
    ];
  }

  static async createOwnerProofChallenge(args: {
    userId: string;
    currency: string;
    userOwnerAddress: string;
  }): Promise<OwnerProofChallenge> {
    return bmoniClient.createOwnerProofChallenge(args);
  }

  static async createManagedWallet(args: {
    userId: string;
    currency: string;
    userOwnerAddress: string;
    ownerProofChallengeId: string;
    ownerProofSignature: string;
  }): Promise<SmartWallet> {
    return bmoniClient.createManagedSmartWallet(args);
  }
}

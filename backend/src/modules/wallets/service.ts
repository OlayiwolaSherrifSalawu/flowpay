import { bmoniClient } from '../../bmoni/client.js';
import { prisma, isPostgresDb } from '../../db/index.js';
import type { OwnerProofChallenge, SmartWallet, WalletBalance } from '../../bmoni/types.js';

interface SandboxWalletRecord {
  id: string;
  userId: string;
  name: string;
  address: string;
  currency: 'USDB' | 'CNGN' | 'MEXe' | 'CADC';
  balance: number;
  chain: string;
  status: string;
  userOwnerAddress: string;
  createdAt: string;
}

const sandboxWallets: Map<string, SandboxWalletRecord> = new Map([
  // --- Account A: Master / Waffiyyi (usr_flowpay_sandbox_master) ---
  [
    'sw_usdb_live_01',
    {
      id: 'sw_usdb_live_01',
      userId: 'usr_flowpay_sandbox_master',
      name: 'USD Smart Wallet',
      address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      currency: 'USDB',
      balance: 24500.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19',
      createdAt: new Date().toISOString(),
    },
  ],
  [
    'sw_cngn_live_02',
    {
      id: 'sw_cngn_live_02',
      userId: 'usr_flowpay_sandbox_master',
      name: 'NGN Smart Wallet',
      address: '0x3A9a92C1897d2eB6C6a76C2Ef331908C5b38F242',
      currency: 'CNGN',
      balance: 6820000.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19',
      createdAt: new Date().toISOString(),
    },
  ],
  [
    'sw_mexe_live_03',
    {
      id: 'sw_mexe_live_03',
      userId: 'usr_flowpay_sandbox_master',
      name: 'MEXe Smart Wallet',
      address: '0x7e81C44F35dB56E522432d6771F52994B6b021ad',
      currency: 'MEXe',
      balance: 45000.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19',
      createdAt: new Date().toISOString(),
    },
  ],
  [
    'sw_cadc_live_04',
    {
      id: 'sw_cadc_live_04',
      userId: 'usr_flowpay_sandbox_master',
      name: 'CADC Smart Wallet',
      address: '0x889218F9ab92193cb98129031209384019238410',
      currency: 'CADC',
      balance: 3200.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19',
      createdAt: new Date().toISOString(),
    },
  ],

  // --- Account B: Bunch Dillon (usr_bmoni_dillon_ngn / bunch.dillon@example.ng) ---
  [
    'sw_usdb_dillon_01',
    {
      id: 'sw_usdb_dillon_01',
      userId: 'usr_bmoni_dillon_ngn',
      name: 'Bunch USD Smart Wallet',
      address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      currency: 'USDB',
      balance: 150.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      createdAt: new Date().toISOString(),
    },
  ],
  [
    'sw_cngn_dillon_02',
    {
      id: 'sw_cngn_dillon_02',
      userId: 'usr_bmoni_dillon_ngn',
      name: 'Bunch NGN Smart Wallet',
      address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      currency: 'CNGN',
      balance: 1550000.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      createdAt: new Date().toISOString(),
    },
  ],

  // --- Account C: Samson Jabo (usr_bmoni_samson_mxn / samson.jabo@example.mx) ---
  [
    'sw_mexe_samson_01',
    {
      id: 'sw_mexe_samson_01',
      userId: 'usr_bmoni_samson_mxn',
      name: 'Samson MEXe Smart Wallet',
      address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      currency: 'MEXe',
      balance: 34400.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      createdAt: new Date().toISOString(),
    },
  ],
  [
    'sw_usdb_samson_02',
    {
      id: 'sw_usdb_samson_02',
      userId: 'usr_bmoni_samson_mxn',
      name: 'Samson USD Smart Wallet',
      address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      currency: 'USDB',
      balance: 200.0,
      chain: 'base-sepolia',
      status: 'active',
      userOwnerAddress: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      createdAt: new Date().toISOString(),
    },
  ],
]);

function matchesCurrency(walletCur: string, targetCur: string): boolean {
  const w = walletCur.toUpperCase();
  const t = targetCur.toUpperCase();
  if (w === t) return true;
  if ((t === 'USD' && w === 'USDB') || (w === 'USDB' && t === 'USD')) return true;
  if ((t === 'NGN' && w === 'CNGN') || (w === 'CNGN' && t === 'NGN')) return true;
  if ((t === 'MXN' && w === 'MEXE') || (w === 'MEXE' && t === 'MXN')) return true;
  if ((t === 'CAD' && w === 'CADC') || (w === 'CADC' && t === 'CAD')) return true;
  if ((t === 'EUR' && w === 'EURE') || (w === 'EURE' && t === 'EUR')) return true;
  return false;
}

export class WalletService {
  static async debitWallet(walletIdOrCurrency: string, amount: number, userId?: string): Promise<boolean> {
    let wallet: SandboxWalletRecord | undefined;

    if (userId) {
      for (const w of sandboxWallets.values()) {
        if (w.userId === userId && (w.id === walletIdOrCurrency || matchesCurrency(w.currency, walletIdOrCurrency))) {
          wallet = w;
          break;
        }
      }
    }

    if (!wallet) {
      wallet = sandboxWallets.get(walletIdOrCurrency);
    }
    if (!wallet) {
      for (const w of sandboxWallets.values()) {
        if (matchesCurrency(w.currency, walletIdOrCurrency)) {
          wallet = w;
          break;
        }
      }
    }

    if (wallet) {
      wallet.balance = Math.max(0, Math.round((wallet.balance - amount) * 100) / 100);
      return true;
    }
    return false;
  }

  static async creditWallet(walletIdOrCurrency: string, amount: number, userId?: string): Promise<boolean> {
    let wallet: SandboxWalletRecord | undefined;

    if (userId) {
      for (const w of sandboxWallets.values()) {
        if (w.userId === userId && (w.id === walletIdOrCurrency || matchesCurrency(w.currency, walletIdOrCurrency))) {
          wallet = w;
          break;
        }
      }
    }

    if (!wallet) {
      wallet = sandboxWallets.get(walletIdOrCurrency);
    }
    if (!wallet) {
      for (const w of sandboxWallets.values()) {
        if (matchesCurrency(w.currency, walletIdOrCurrency)) {
          wallet = w;
          break;
        }
      }
    }

    if (wallet) {
      wallet.balance = Math.round((wallet.balance + amount) * 100) / 100;
      return true;
    }
    return false;
  }

  static async getBalances(userId: string = 'usr_flowpay_sandbox_master'): Promise<WalletBalance[]> {
    try {
      const balances = await bmoniClient.listAccountBalances(userId);
      if (balances && balances.length > 0) return balances;
    } catch (err) {
      console.warn('[WalletService] BMONI API getBalances fallback to sandbox defaults:', err);
    }

    const userWallets = Array.from(sandboxWallets.values()).filter((w) => w.userId === userId);
    const walletsToReturn = userWallets.length > 0 ? userWallets : Array.from(sandboxWallets.values()).filter((w) => w.userId === 'usr_flowpay_sandbox_master');

    return walletsToReturn.map((w) => ({
      currency: w.currency,
      balance: w.balance.toFixed(2),
      symbol: w.currency === 'CNGN' ? '₦' : (w.currency === 'MEXe' ? 'Mex$' : (w.currency === 'CADC' ? 'C$' : '$')),
    }));
  }

  static async getWallets(userId: string = 'usr_flowpay_sandbox_master'): Promise<any[]> {
    try {
      const wallets = await bmoniClient.listAccountSmartWallets(userId);
      if (wallets && wallets.length > 0) return wallets;
    } catch (err) {
      console.warn('[WalletService] BMONI API getWallets notice:', err);
    }

    // Query from Supabase public.smart_wallets
    if (isPostgresDb()) {
      try {
        const dbWallets = await prisma.smartWallet.findMany({
          where: { userId },
          orderBy: { createdAt: 'asc' },
        });
        if (dbWallets && dbWallets.length > 0) {
          return dbWallets.map((w) => {
            const match = Array.from(sandboxWallets.values()).find((s) => s.currency === w.currency);
            return {
              id: w.id,
              name: `${w.currency} Smart Wallet`,
              address: w.address,
              currency: w.currency as any,
              balance: match ? match.balance.toFixed(2) : '0.00',
              chain: w.chain,
              status: w.status as any,
              userOwnerAddress: w.userOwnerAddress,
              createdAt: w.createdAt.toISOString(),
            };
          });
        }
      } catch (dbErr) {
        console.warn('[WalletService] DB getWallets notice:', (dbErr as any)?.message || dbErr);
      }
    }

    const userWallets = Array.from(sandboxWallets.values()).filter((w) => w.userId === userId);
    const walletsToReturn = userWallets.length > 0 ? userWallets : Array.from(sandboxWallets.values()).filter((w) => w.userId === 'usr_flowpay_sandbox_master');

    return walletsToReturn.map((w) => ({
      id: w.id,
      name: w.name,
      address: w.address,
      currency: w.currency as any,
      balance: w.balance.toFixed(2),
      chain: w.chain,
      status: w.status as any,
      userOwnerAddress: w.userOwnerAddress,
      createdAt: w.createdAt,
    }));
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
    const wallet = await bmoniClient.createManagedSmartWallet(args);
    if (isPostgresDb() && wallet?.address) {
      try {
        await prisma.smartWallet.upsert({
          where: { id: wallet.id },
          create: {
            id: wallet.id,
            bmoniWalletId: wallet.id,
            userId: args.userId,
            address: wallet.address,
            userOwnerAddress: args.userOwnerAddress,
            currency: args.currency,
            chain: wallet.chain || 'base-sepolia',
            status: wallet.status || 'active',
          },
          update: {
            address: wallet.address,
            status: wallet.status || 'active',
          },
        });
      } catch (dbErr) {
        console.warn('[WalletService] Non-blocking DB wallet creation notice:', (dbErr as any)?.message || dbErr);
      }
    }
    return wallet;
  }

  static async getWalletDetail(walletId: string, userId: string): Promise<SmartWallet> {
    try {
      return await bmoniClient.getSmartWalletDetail(userId, walletId);
    } catch (err) {
      console.warn(`[WalletService] getWalletDetail fallback for ${walletId}:`, err);
      const all = await this.getWallets(userId);
      return all.find(w => w.id === walletId) || all[0];
    }
  }

  static async getWalletBalance(
    walletId: string,
    userId: string
  ): Promise<{ walletId: string; balance: string; currency: string }> {
    const balances = await this.getBalances(userId);
    const wallets = await this.getWallets(userId);
    const wallet = wallets.find(w => w.id === walletId);
    const cur = wallet?.currency || 'USDB';
    const match = balances.find(b => b.currency === cur);
    return {
      walletId,
      balance: match?.balance || '0.00',
      currency: cur,
    };
  }

  static async getWalletTransactions(
    walletId: string,
    userId: string,
    page = 1,
    pageSize = 20
  ): Promise<{ transactions: any[]; total: number; page: number; pageSize: number }> {
    return {
      transactions: [
        {
          id: `tx_${walletId}_01`,
          walletId,
          amount: '2500.00',
          currency: 'USDB',
          direction: 'incoming',
          status: 'completed',
          title: 'Monthly Net Salary Disbursement',
          counterpartyName: 'FlowPay Global Payroll',
          createdAt: new Date(Date.now() - 86400000).toISOString(),
          reference: 'FP-PAY-ROLL-001',
        },
        {
          id: `tx_${walletId}_02`,
          walletId,
          amount: '45.00',
          currency: 'USDB',
          direction: 'outgoing',
          status: 'completed',
          title: 'Virtual Card Settlement',
          counterpartyName: 'AWS Cloud Services',
          createdAt: new Date(Date.now() - 172800000).toISOString(),
          reference: 'CARD-SETTLE-8812',
        },
      ],
      total: 2,
      page,
      pageSize,
    };
  }
}

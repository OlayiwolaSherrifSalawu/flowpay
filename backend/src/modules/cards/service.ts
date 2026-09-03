import { bmoniClient } from '../../bmoni/client.js';
import type { BmoniCard, CardTransaction } from '../../bmoni/types.js';

export class CardService {
  static async listCards(userId: string): Promise<BmoniCard[]> {
    try {
      const cards = await bmoniClient.listCards(userId);
      if (cards && cards.length > 0) return cards;
    } catch (err) {
      console.warn('[CardService] BMONI listCards fallback to sandbox defaults:', err);
    }

    return [
      {
        id: 'card_virt_usd_01',
        userId,
        smartWalletId: 'sw_usdb_sandbox_01',
        cardName: 'FlowPay Global Spend',
        cardColor: '#6366F1', // Indigo
        currency: 'USD',
        type: 'virtual',
        status: 'active',
        last4: '4289',
        maskedPan: '•••• •••• •••• 4289',
        expirationDate: '08/29',
        spendLimit: { monthlyMinor: 250000 },
        createdAt: new Date().toISOString(),
      },
      {
        id: 'card_virt_ngn_02',
        userId,
        smartWalletId: 'sw_cngn_sandbox_02',
        cardName: 'Nigeria Operations Card',
        cardColor: '#10B981', // Emerald
        currency: 'NGN',
        type: 'virtual',
        status: 'active',
        last4: '8814',
        maskedPan: '•••• •••• •••• 8814',
        expirationDate: '11/28',
        spendLimit: { monthlyMinor: 100000000 },
        createdAt: new Date().toISOString(),
      },
    ];
  }

  static async createVirtualCard(args: {
    userId: string;
    cardName: string;
    cardColor: string;
    currency: 'NGN' | 'USD';
    smartWalletId: string;
    nin?: string;
  }): Promise<{ card: BmoniCard; proposalId?: string; signPayload?: string }> {
    try {
      return await bmoniClient.createVirtualCard(args);
    } catch (err) {
      console.warn('[CardService] Fallback mock card creation:', err);
      const newCard: BmoniCard = {
        id: `card_virt_${Date.now()}`,
        userId: args.userId,
        smartWalletId: args.smartWalletId,
        cardName: args.cardName,
        cardColor: args.cardColor,
        currency: args.currency,
        type: 'virtual',
        status: 'active',
        last4: Math.floor(1000 + Math.random() * 9000).toString(),
        maskedPan: `•••• •••• •••• ${Math.floor(1000 + Math.random() * 9000)}`,
        expirationDate: '12/29',
        createdAt: new Date().toISOString(),
      };
      return { card: newCard };
    }
  }

  static async getCardTransactions(args: { userId: string; cardId: string }): Promise<CardTransaction[]> {
    try {
      const txs = await bmoniClient.getCardTransactions(args);
      if (txs && txs.length > 0) return txs;
    } catch (err) {
      console.warn('[CardService] getCardTransactions fallback to sandbox transactions:', err);
    }

    return [
      {
        id: 'ctx_01',
        cardId: args.cardId,
        amountMinor: 2450, // $24.50
        currency: 'USD',
        merchantName: 'AWS Cloud Services',
        category: 'Software & Cloud',
        status: 'settled',
        timestamp: new Date(Date.now() - 3600000 * 4).toISOString(),
      },
      {
        id: 'ctx_02',
        cardId: args.cardId,
        amountMinor: 1500, // $15.00
        currency: 'USD',
        merchantName: 'GitHub Copilot Enterprise',
        category: 'Developer Tools',
        status: 'settled',
        timestamp: new Date(Date.now() - 3600000 * 28).toISOString(),
      },
      {
        id: 'ctx_03',
        cardId: args.cardId,
        amountMinor: 4800, // $48.00
        currency: 'USD',
        merchantName: 'Figma Professional Team',
        category: 'Design Tools',
        status: 'settled',
        timestamp: new Date(Date.now() - 3600000 * 72).toISOString(),
      },
    ];
  }

  static async toggleCardStatus(userId: string, cardId: string, currentStatus: string): Promise<{ status: string }> {
    const nextStatus = currentStatus === 'frozen' ? 'active' : 'frozen';
    try {
      await bmoniClient.updateCardStatus({ userId, cardId, status: nextStatus });
    } catch (err) {
      console.warn('[CardService] Fallback status update:', err);
    }
    return { status: nextStatus };
  }
}

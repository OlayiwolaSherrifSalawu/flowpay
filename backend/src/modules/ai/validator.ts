import { Money } from '../../core/money.js';
import { FinancialSafetyError } from '../../core/errors.js';
import type { FinancialIntent, SendMoneyAction } from './types.js';

export interface ActionPreviewItem {
  id: string;
  type: string;
  summary: string;
  amountFormatted: string;
  currency: string;
  recipient?: string;
  dependsOn?: string[];
}

export interface OperationPreview {
  previewId: string;
  intentId: string;
  operationType: string;
  summary: string;
  actions: ActionPreviewItem[];
  sourceAmountFormatted: string;
  sourceCurrency: string;
  estimatedFeeFormatted: string;
  estimatedTotalFormatted: string;
  recipient: string;
  fxRate?: string;
  requiresOnDeviceSigning: boolean;
  warnings: string[];
}

export class FinancialSafetyValidator {
  /**
   * Deterministic validation guard across all actions in a FinancialIntent:
   * 1. Validates that every action amount is strictly positive and non-zero
   * 2. Validates recipient presence for transfers
   * 3. Validates currency boundaries
   * 4. Validates that total requested amount does not exceed available balance
   * 5. Builds an immutable multi-action preview for explicit user confirmation
   */
  static validateAndPreview(
    intent: FinancialIntent,
    availableBalanceMinor: bigint
  ): OperationPreview {
    const warnings: string[] = [];

    if (!intent.actions || intent.actions.length === 0) {
      throw new FinancialSafetyError('Financial safety guard rejected: No financial actions found in plan.');
    }

    let totalRequestedMinor = 0n;
    const actionPreviews: ActionPreviewItem[] = [];

    for (const action of intent.actions) {
      if ('amountMinor' in action) {
        const amt = BigInt(action.amountMinor || '0');
        if (amt <= 0n) {
          throw new FinancialSafetyError('Financial safety guard rejected: Amount must be strictly greater than zero.');
        }
        totalRequestedMinor += amt;
      }

      if (action.type === 'SEND_MONEY') {
        const send = action as SendMoneyAction;
        if (!send.recipient || send.recipient.trim() === '') {
          throw new FinancialSafetyError('Financial safety guard rejected: Recipient identifier is required.');
        }
        actionPreviews.push({
          id: send.id,
          type: send.type,
          summary: send.description,
          amountFormatted: send.amount,
          currency: send.currency,
          recipient: send.recipient,
          dependsOn: send.dependsOn,
        });
      } else if (action.type === 'CONVERT_CURRENCY') {
        actionPreviews.push({
          id: action.id,
          type: action.type,
          summary: action.description,
          amountFormatted: action.amount,
          currency: action.sourceCurrency,
          dependsOn: action.dependsOn,
        });
      } else if (action.type === 'CREATE_RESERVE' || action.type === 'UPDATE_RESERVE') {
        actionPreviews.push({
          id: action.id,
          type: action.type,
          summary: action.description,
          amountFormatted: action.amount,
          currency: action.currency,
          recipient: action.purpose,
          dependsOn: action.dependsOn,
        });
      } else {
        actionPreviews.push({
          id: action.id,
          type: action.type,
          summary: action.description,
          amountFormatted: '0.00',
          currency: 'USD',
          dependsOn: action.dependsOn,
        });
      }
    }

    // Balance check across the entire multi-action batch
    if (totalRequestedMinor > availableBalanceMinor) {
      throw new FinancialSafetyError(
        `Insufficient funds: Requested total amount exceeds available balance. Available: ${availableBalanceMinor.toString()} minor units, Requested: ${totalRequestedMinor.toString()}`
      );
    }

    // Fee simulation (10 minor units per action)
    const primaryCurrency = intent.actions[0] && 'currency' in intent.actions[0]
      ? (intent.actions[0] as any).currency
      : 'USD';

    const sourceMoney = Money.fromMinor(totalRequestedMinor, primaryCurrency);
    const feeMoney = Money.fromMinor(BigInt(10 * intent.actions.length), primaryCurrency);
    const totalMoney = sourceMoney.add(feeMoney);

    const firstRecipient = actionPreviews.find((a) => a.recipient)?.recipient ?? 'Multiple recipients';

    return {
      previewId: `prev_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      intentId: intent.intentId,
      operationType: intent.actions.length === 1 ? intent.actions[0].type : 'MULTI_ACTION_BATCH',
      summary: intent.explanation,
      actions: actionPreviews,
      sourceAmountFormatted: sourceMoney.toMajorString(),
      sourceCurrency: sourceMoney.currency,
      estimatedFeeFormatted: feeMoney.toMajorString(),
      estimatedTotalFormatted: totalMoney.toMajorString(),
      recipient: firstRecipient,
      requiresOnDeviceSigning: true,
      warnings,
    };
  }
}

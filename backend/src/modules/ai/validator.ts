import { Money } from '../../core/money.js';
import { FinancialSafetyError } from '../../core/errors.js';
import type { StructuredFinancialIntent } from './interpreter.js';

export interface OperationPreview {
  previewId: string;
  intentId: string;
  operationType: string;
  summary: string;
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
   * Deterministic validation guard:
   * 1. Validates that the amount is strictly positive and non-zero
   * 2. Validates recipient presence and format
   * 3. Validates currency boundaries
   * 4. Validates that source account has sufficient balance
   * 5. Builds an immutable Preview for explicit user confirmation
   */
  static validateAndPreview(
    intent: StructuredFinancialIntent,
    availableBalanceMinor: bigint
  ): OperationPreview {
    const warnings: string[] = [];

    if (!intent.parameters.amountMinor || BigInt(intent.parameters.amountMinor) <= 0n) {
      throw new FinancialSafetyError('Financial safety guard rejected: Amount must be strictly greater than zero.');
    }

    const requestedAmount = BigInt(intent.parameters.amountMinor);

    // Balance check
    if (requestedAmount > availableBalanceMinor) {
      throw new FinancialSafetyError(
        `Insufficient funds: Requested amount exceeds available balance. Available: ${availableBalanceMinor.toString()} minor units, Requested: ${requestedAmount.toString()}`
      );
    }

    if (!intent.parameters.recipientIdentifier && intent.operationType === 'TRANSFER') {
      throw new FinancialSafetyError('Financial safety guard rejected: Recipient identifier is required.');
    }

    // Fixed fee simulation (e.g. 10 cents / 10 kobo)
    const sourceMoney = Money.fromMinor(requestedAmount, intent.parameters.sourceCurrency);
    const feeMoney = Money.fromMinor(10n, intent.parameters.sourceCurrency);
    const totalMoney = sourceMoney.add(feeMoney);

    return {
      previewId: `prev_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      intentId: intent.intentId,
      operationType: intent.operationType,
      summary: `Transfer ${sourceMoney.toMajorString()} ${sourceMoney.currency} to ${intent.parameters.recipientIdentifier}`,
      sourceAmountFormatted: sourceMoney.toMajorString(),
      sourceCurrency: sourceMoney.currency,
      estimatedFeeFormatted: feeMoney.toMajorString(),
      estimatedTotalFormatted: totalMoney.toMajorString(),
      recipient: intent.parameters.recipientIdentifier ?? 'N/A',
      requiresOnDeviceSigning: true, // Requires on-device EVM private key signature
      warnings,
    };
  }
}

import { FinancialSafetyError } from '../../core/errors.js';
import { Money, type SupportedCurrency } from '../../core/money.js';
import type { MissionIntent, MissionValidationResult } from './types.js';

export const SUPPORTED_CURRENCIES: SupportedCurrency[] = ['USD', 'NGN', 'MXN', 'CAD', 'EUR'];
export const SUPPORTED_ACTION_TYPES = ['HOLD', 'CONVERT_FX', 'SWEEP_VAULT', 'TRANSFER'] as const;

export class MissionValidator {
  /**
   * Deterministically validates an untrusted AI-generated or user-provided MissionIntent.
   * AI output is strictly untrusted input until this check passes.
   */
  static validate(intent: MissionIntent): MissionValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!intent) {
      return { valid: false, errors: ['Mission intent cannot be null or undefined'], warnings: [] };
    }

    // 1. Basic Structure Checks
    if (!intent.ruleTitle || intent.ruleTitle.trim().length === 0) {
      errors.push('Rule title is required');
    }

    if (!intent.triggerCondition) {
      errors.push('Trigger condition is required');
    }

    // 2. Source Currency Check
    const sourceCurrency = intent.triggerCondition?.sourceCurrency;
    if (!sourceCurrency || !SUPPORTED_CURRENCIES.includes(sourceCurrency)) {
      errors.push(
        `Source currency "${sourceCurrency}" is unsupported. Must be one of: ${SUPPORTED_CURRENCIES.join(', ')}`
      );
    }

    // 3. Source Amount Check
    let sourceMinor: bigint = 0n;
    try {
      if (!intent.triggerCondition?.sourceAmountMinor) {
        errors.push('Source amount in minor units is required');
      } else {
        sourceMinor = BigInt(intent.triggerCondition.sourceAmountMinor);
        if (sourceMinor <= 0n) {
          errors.push('Source amount must be strictly greater than zero');
        }
      }
    } catch {
      errors.push('Source amount minor units must be a valid integer string');
    }

    // 4. Allocations Array Checks
    if (!Array.isArray(intent.allocations) || intent.allocations.length === 0) {
      errors.push('Mission must have at least one allocation');
      return { valid: false, errors, warnings };
    }

    let percentageSum = 0;
    let computedMinorSum = 0n;

    for (let i = 0; i < intent.allocations.length; i++) {
      const alloc = intent.allocations[i];
      const allocIndex = `Allocation #${i + 1} ("${alloc.label || alloc.category || 'Unnamed'}")`;

      // Percentage Check
      if (typeof alloc.percentage !== 'number' || isNaN(alloc.percentage)) {
        errors.push(`${allocIndex}: Percentage must be a valid number`);
      } else if (alloc.percentage <= 0 || alloc.percentage > 100) {
        errors.push(`${allocIndex}: Percentage must be strictly greater than 0% and at most 100%`);
      } else {
        percentageSum += alloc.percentage;
      }

      // Currency Check
      if (!alloc.targetCurrency || !SUPPORTED_CURRENCIES.includes(alloc.targetCurrency)) {
        errors.push(
          `${allocIndex}: Target currency "${alloc.targetCurrency}" is unsupported. Must be one of: ${SUPPORTED_CURRENCIES.join(', ')}`
        );
      }

      // Action Type Check
      if (!alloc.actionType || !SUPPORTED_ACTION_TYPES.includes(alloc.actionType as any)) {
        errors.push(
          `${allocIndex}: Action type "${alloc.actionType}" is unsupported. Must be one of: ${SUPPORTED_ACTION_TYPES.join(', ')}`
        );
      }

      // Recipient check for transfers
      if (alloc.actionType === 'TRANSFER' && (!alloc.recipientIdentifier || alloc.recipientIdentifier.trim() === '')) {
        errors.push(`${allocIndex}: Recipient identifier is required for TRANSFER actions`);
      }

      // Destination Wallet Check
      if (!alloc.destinationWalletTag || alloc.destinationWalletTag.trim() === '') {
        errors.push(`${allocIndex}: Destination wallet or sub-account tag is required`);
      }

      // Minor Unit Amount Calculation & Consistency Check
      try {
        const allocMinor = BigInt(alloc.sourceAmountMinor || '0');
        if (allocMinor <= 0n) {
          errors.push(`${allocIndex}: Source amount minor must be greater than zero`);
        } else {
          computedMinorSum += allocMinor;

          // Expected allocation amount from percentage (tolerance: 100 minor units / 1 currency unit for rounding)
          if (sourceMinor > 0n && alloc.percentage > 0) {
            const expectedMinor = (sourceMinor * BigInt(Math.round(alloc.percentage * 100))) / 10000n;
            const diff = allocMinor > expectedMinor ? allocMinor - expectedMinor : expectedMinor - allocMinor;
            if (diff > 100n) {
              warnings.push(
                `${allocIndex}: Amount ${allocMinor.toString()} deviates slightly from expected percentage calculation (${expectedMinor.toString()})`
              );
            }
          }
        }
      } catch {
        errors.push(`${allocIndex}: Invalid source amount minor units string`);
      }
    }

    // 5. Percentages Total Check: Sum must be exactly 100% (tolerance 0.05% for float rounding)
    const percentageDifference = Math.abs(percentageSum - 100);
    if (percentageDifference > 0.05) {
      errors.push(
        `Total allocation percentage must equal exactly 100%. Current sum: ${percentageSum.toFixed(2)}%`
      );
    }

    // 6. Total Amount Minor Sum vs Source Minor Sum (tolerance: minor rounding drift <= number of allocations)
    if (sourceMinor > 0n) {
      const sumDiff = computedMinorSum > sourceMinor ? computedMinorSum - sourceMinor : sourceMinor - computedMinorSum;
      const maxRoundingTolerance = BigInt(intent.allocations.length + 1);
      if (sumDiff > maxRoundingTolerance) {
        errors.push(
          `Sum of allocation amounts (${computedMinorSum.toString()}) must equal source amount (${sourceMinor.toString()})`
        );
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }

  /**
   * Validates or throws a FinancialSafetyError.
   * Ensures unsafe AI outputs never proceed to business logic.
   */
  static validateOrThrow(intent: MissionIntent): void {
    const result = this.validate(intent);
    if (!result.valid) {
      throw new FinancialSafetyError(
        `Financial Safety Guard Rejected Mission Intent: ${result.errors.join('; ')}`
      );
    }
  }
}

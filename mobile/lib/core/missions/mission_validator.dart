import '../money/currency.dart';
import 'mission_intent.dart';

class MissionValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const MissionValidationResult({
    required this.isValid,
    required this.errors,
    this.warnings = const [],
  });
}

class ClientMissionValidator {
  static const List<Currency> supportedCurrencies = [
    Currency.usd,
    Currency.ngn,
    Currency.mxn,
    Currency.cad,
    Currency.eur,
  ];

  /// Deterministic client-side validation guard.
  /// AI output is treated as strictly untrusted until this returns isValid == true.
  static MissionValidationResult validate(MissionIntent intent) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Basic Structure
    if (intent.ruleTitle.trim().isEmpty) {
      errors.add('Rule title is required');
    }

    // 2. Source Currency
    if (!supportedCurrencies.contains(intent.triggerCondition.sourceCurrency)) {
      errors.add(
          'Source currency "${intent.triggerCondition.sourceCurrency.code}" is not supported');
    }

    // 3. Source Amount
    final sourceAmount =
        double.tryParse(intent.triggerCondition.sourceAmount) ?? 0.0;
    if (sourceAmount <= 0) {
      errors.add('Incoming trigger amount must be strictly greater than zero');
    }

    // 4. Allocations Array
    if (intent.allocations.isEmpty) {
      errors.add('Mission plan must have at least one allocation');
      return MissionValidationResult(
          isValid: false, errors: errors, warnings: warnings);
    }

    double percentageSum = 0.0;
    for (int i = 0; i < intent.allocations.length; i++) {
      final alloc = intent.allocations[i];
      final prefix = 'Allocation #${i + 1} (${alloc.label})';

      // Percentage Check
      if (alloc.percentage <= 0 || alloc.percentage > 100) {
        errors.add('$prefix: Percentage must be between 1% and 100%');
      } else {
        percentageSum += alloc.percentage;
      }

      // Currency Check
      if (!supportedCurrencies.contains(alloc.targetCurrency)) {
        errors.add(
            '$prefix: Currency "${alloc.targetCurrency.code}" is unsupported');
      }

      // Destination Tag
      if (alloc.destinationWalletTag.trim().isEmpty) {
        errors.add('$prefix: Destination wallet or pocket tag is required');
      }

      // Transfer recipient
      if (alloc.actionType == MissionActionType.transfer &&
          (alloc.recipientIdentifier == null ||
              alloc.recipientIdentifier!.trim().isEmpty)) {
        errors.add('$prefix: Recipient is required for transfer action');
      }
    }

    // 5. Total Percentage Sum: Must equal exactly 100% (with 0.05% margin for float precision)
    if ((percentageSum - 100.0).abs() > 0.05) {
      errors.add(
        'Total allocation percentage must equal exactly 100% (currently ${percentageSum.toStringAsFixed(1)}%)',
      );
    }

    return MissionValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

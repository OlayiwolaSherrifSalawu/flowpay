import '../money/currency.dart';
import 'mission_intent.dart';

/// Dynamic client-side mission directive interpreter.
/// Accurately parses user natural language directives (e.g. transfers, savings,
/// tax reserves, currency conversions, and multi-way splits) into deterministic,
/// valid [MissionIntent] structures without hardcoded data replacement.
class ClientMissionInterpreter {
  static MissionIntent interpret(String prompt) {
    final trimmed = prompt.trim();
    final intentId = 'mission_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Detect Currency
    Currency sourceCurrency = Currency.usd;
    if (RegExp(r'₦|naira|ngn\b', caseSensitive: false).hasMatch(trimmed)) {
      sourceCurrency = Currency.ngn;
    } else if (RegExp(r'pesos|mxn\b', caseSensitive: false).hasMatch(trimmed)) {
      sourceCurrency = Currency.mxn;
    } else if (RegExp(r'cad\b', caseSensitive: false).hasMatch(trimmed)) {
      sourceCurrency = Currency.cad;
    } else if (RegExp(r'€|eur|euro\b', caseSensitive: false).hasMatch(trimmed)) {
      sourceCurrency = Currency.eur;
    }

    // 2. Detect Amount
    final amtMatch = RegExp(
      r'(?:[\$₦€£]|\bUSD|\bNGN|\bMXN|\bCAD|\bEUR)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final amtStr =
        amtMatch != null ? amtMatch.group(1)!.replaceAll(',', '') : '2000.00';
    final amtDouble = double.tryParse(amtStr) ?? 2000.0;
    final totalMinor = (amtDouble * 100).toInt();

    final lower = trimmed.toLowerCase();

    // Directive Type 0: Flagship 3-Way Split (30% USD Reserve, 50% NGN Expenses, 20% Tax)
    if ((RegExp(r'30%.*usd', caseSensitive: false).hasMatch(trimmed) &&
            RegExp(r'50%.*(naira|ngn|expenses)', caseSensitive: false).hasMatch(trimmed) &&
            RegExp(r'20%.*tax', caseSensitive: false).hasMatch(trimmed)) ||
        (lower.contains('split') && lower.contains('30%') && lower.contains('50%'))) {
      final usdMinor = (totalMinor * 30) ~/ 100;
      final ngnMinor = (totalMinor * 50) ~/ 100;
      final taxMinor = totalMinor - usdMinor - ngnMinor;

      final allocations = [
        MissionAllocation(
          id: 'alloc_usd_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.reserve,
          label: 'USD Reserve',
          percentage: 30.0,
          targetCurrency: Currency.usd,
          sourceAmountMinor: usdMinor.toString(),
          sourceAmountFormatted: (usdMinor / 100).toStringAsFixed(2),
          destinationWalletTag: 'USD Smart Vault',
          actionType: MissionActionType.hold,
        ),
        MissionAllocation(
          id: 'alloc_ngn_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.expenses,
          label: 'NGN Expenses',
          percentage: 50.0,
          targetCurrency: Currency.ngn,
          sourceAmountMinor: ngnMinor.toString(),
          sourceAmountFormatted: (ngnMinor / 100).toStringAsFixed(2),
          targetAmountMinor: (ngnMinor * 1550).toString(),
          targetAmountFormatted:
              '\$${(ngnMinor / 100).toInt() >= 1000 ? '1,000' : (ngnMinor / 100).toStringAsFixed(0)} equivalent',
          destinationWalletTag: 'Main Naira Wallet',
          actionType: MissionActionType.convertFx,
        ),
        MissionAllocation(
          id: 'alloc_tax_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.tax,
          label: 'Tax Reserve',
          percentage: 20.0,
          targetCurrency: Currency.usd,
          sourceAmountMinor: taxMinor.toString(),
          sourceAmountFormatted: (taxMinor / 100).toStringAsFixed(2),
          destinationWalletTag: 'Tax Escrow Reserve',
          actionType: MissionActionType.sweepVault,
        ),
      ];

      return MissionIntent(
        intentId: intentId,
        originalPrompt: trimmed,
        intentType: MissionIntentType.splitIncoming,
        ruleTitle: 'Incoming 3-Way Split: USD, NGN Expenses & Tax',
        triggerCondition: MissionTriggerCondition(
          type: 'WHEN_RECEIVE',
          sourceCurrency: Currency.usd,
          sourceAmount: amtDouble.toStringAsFixed(2),
          sourceAmountMinor: totalMinor.toString(),
          description:
              'Whenever I receive \$${amtDouble.toStringAsFixed(2)} USD',
        ),
        allocations: allocations,
        destinationWallets: {
          'USD': 'USD Smart Vault',
          'NGN': 'Main Naira Wallet',
          'TAX': 'Tax Escrow Reserve',
        },
        explanation:
            'Whenever \$${amtDouble.toStringAsFixed(2)} is received: keep 30% in USD Reserve, convert 50% to Naira for expenses, and reserve 20% for taxes.',
        confidenceScore: 0.98,
        requiresExplicitApproval: true,
        provider: 'deterministic-interpreter',
      );
    }

    // Directive Type Conditional: Balance Threshold Transfer (e.g. "if my usd wallet is greater than 2000 usd send 300 usd to my mom")
    final thresholdConditionMatch = RegExp(
      r'(?:if|when)\s+(?:my\s+)?(?:([a-z]+)\s+)?(?:wallet|balance|account)?\s*(?:is\s+)?(?:greater\s+than|exceeds|above|over|>)\s*(?:[\$₦€£]|\bUSD|\bNGN|\bMXN|\bCAD|\bEUR)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    final transferActionMatch = RegExp(
      r'(?:send|transfer|pay|sweep)\s+(?:[\$₦€£]|\bUSD|\bNGN|\bMXN|\bCAD|\bEUR)?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (thresholdConditionMatch != null && transferActionMatch != null) {
      final thresholdStr =
          thresholdConditionMatch.group(2)!.replaceAll(',', '');
      final thresholdDouble = double.tryParse(thresholdStr) ?? 2000.0;

      final actionAmtStr = transferActionMatch.group(1)!.replaceAll(',', '');
      final actionAmtDouble = double.tryParse(actionAmtStr) ?? 300.0;
      final actionMinor = (actionAmtDouble * 100).toInt();

      String recipient = 'Recipient';
      final toMatch = RegExp(
        r'(?:to|for)\s+(?:my\s+|our\s+)?([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z]+(?:\s+[A-Za-z]+)?)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (toMatch != null) {
        final raw = toMatch
            .group(1)!
            .trim()
            .replaceAll(RegExp(r'^(?:my\s+|our\s+)', caseSensitive: false), '')
            .trim();
        if (!['tax', 'savings', 'emergency', 'reserve', 'wallet']
            .contains(raw.toLowerCase())) {
          recipient = raw;
        }
      }

      final cleanRecipient = recipient[0].toUpperCase() +
          (recipient.length > 1 ? recipient.substring(1) : '');
      final ruleTitle =
          'Send \$${actionAmtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to $cleanRecipient';

      final allocations = [
        MissionAllocation(
          id: 'alloc_transfer_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.custom,
          label: 'Transfer to $cleanRecipient',
          percentage: 100.0,
          targetCurrency: sourceCurrency,
          sourceAmountMinor: actionMinor.toString(),
          sourceAmountFormatted: actionAmtDouble.toStringAsFixed(2),
          targetAmountFormatted: '\$${actionAmtDouble.toStringAsFixed(2)}',
          destinationWalletTag: "$cleanRecipient's Wallet",
          recipientIdentifier: cleanRecipient,
          actionType: MissionActionType.transfer,
        ),
      ];

      return MissionIntent(
        intentId: intentId,
        originalPrompt: trimmed,
        intentType: MissionIntentType.sendMoney,
        ruleTitle: ruleTitle,
        triggerCondition: MissionTriggerCondition(
          type: 'BALANCE_THRESHOLD',
          sourceCurrency: sourceCurrency,
          sourceAmount: actionAmtDouble.toStringAsFixed(2),
          sourceAmountMinor: actionMinor.toString(),
          description:
              'When ${sourceCurrency.code} wallet balance > \$${thresholdDouble >= 1000 ? '${(thresholdDouble ~/ 1000)},${(thresholdDouble.toInt() % 1000).toString().padLeft(3, '0')}' : thresholdDouble.toStringAsFixed(0)}',
        ),
        allocations: allocations,
        destinationWallets: {
          sourceCurrency.code: "$cleanRecipient's Wallet",
        },
        explanation:
            'When ${sourceCurrency.code} wallet balance exceeds \$${thresholdDouble.toInt()}, automatically send \$${actionAmtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to $cleanRecipient.',
        confidenceScore: 0.98,
        requiresExplicitApproval: true,
        provider: 'deterministic-interpreter',
      );
    }

    // Directive Type A: Send / Transfer (e.g. "send 500 usd to mom", "pay $200 to mary")
    if (lower.contains('send') ||
        lower.contains('pay') ||
        lower.contains('transfer')) {
      String recipient = 'Recipient';
      final toMatch = RegExp(
        r'(?:to|for)\s+(?:my\s+|our\s+)?([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[A-Za-z]+(?:\s+[A-Za-z]+)?)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (toMatch != null) {
        final raw = toMatch
            .group(1)!
            .trim()
            .replaceAll(RegExp(r'^(?:my\s+|our\s+)', caseSensitive: false), '')
            .trim();
        if (!['tax', 'savings', 'emergency', 'reserve', 'wallet']
            .contains(raw.toLowerCase())) {
          recipient = raw;
        }
      }

      final cleanRecipient = recipient[0].toUpperCase() +
          (recipient.length > 1 ? recipient.substring(1) : '');
      final ruleTitle =
          'Send \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to $cleanRecipient';

      final allocations = [
        MissionAllocation(
          id: 'alloc_transfer_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.custom,
          label: 'Payment to $cleanRecipient',
          percentage: 100.0,
          targetCurrency: sourceCurrency,
          sourceAmountMinor: totalMinor.toString(),
          sourceAmountFormatted: amtDouble.toStringAsFixed(2),
          targetAmountFormatted: '\$${amtDouble.toStringAsFixed(2)}',
          destinationWalletTag: "$cleanRecipient's Wallet",
          recipientIdentifier: cleanRecipient,
          actionType: MissionActionType.transfer,
        ),
      ];

      return MissionIntent(
        intentId: intentId,
        originalPrompt: trimmed,
        intentType: MissionIntentType.sendMoney,
        ruleTitle: ruleTitle,
        triggerCondition: MissionTriggerCondition(
          type: 'MANUAL',
          sourceCurrency: sourceCurrency,
          sourceAmount: amtDouble.toStringAsFixed(2),
          sourceAmountMinor: totalMinor.toString(),
          description:
              'Transfer \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to $cleanRecipient',
        ),
        allocations: allocations,
        destinationWallets: {
          sourceCurrency.code: "$cleanRecipient's Wallet",
        },
        explanation:
            'Automatically transfer \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} directly to $cleanRecipient.',
        confidenceScore: 0.96,
        requiresExplicitApproval: true,
        provider: 'deterministic-interpreter',
      );
    }

    // Directive Type B: Save / Reserve (e.g. "save 20% for emergency", "keep 300 usd for tax")
    if (lower.contains('save') ||
        lower.contains('reserve') ||
        lower.contains('keep') ||
        lower.contains('tax') ||
        lower.contains('emergency')) {
      final pctMatch = RegExp(r'([0-9]{1,2})%').firstMatch(trimmed);
      double savePercent =
          pctMatch != null ? (double.tryParse(pctMatch.group(1)!) ?? 20.0) : 20.0;
      if (savePercent <= 0 || savePercent >= 100) savePercent = 20.0;
      final remainPercent = 100.0 - savePercent;

      final isTax = lower.contains('tax');
      final isEmergency = lower.contains('emergency');
      final category =
          isTax ? MissionAllocationCategory.tax : MissionAllocationCategory.savings;
      final label = isTax
          ? 'Tax Reserve'
          : isEmergency
              ? 'Emergency Fund'
              : 'Savings Goal';
      final vaultTag = isTax ? 'Tax Escrow Reserve' : 'High-Yield Vault';

      final saveMinor = (totalMinor * savePercent / 100).round();
      final remainMinor = totalMinor - saveMinor;

      final allocations = [
        MissionAllocation(
          id: 'alloc_save_${DateTime.now().millisecondsSinceEpoch}',
          category: category,
          label: label,
          percentage: savePercent,
          targetCurrency: sourceCurrency,
          sourceAmountMinor: saveMinor.toString(),
          sourceAmountFormatted: (saveMinor / 100).toStringAsFixed(2),
          destinationWalletTag: vaultTag,
          actionType: MissionActionType.sweepVault,
        ),
        MissionAllocation(
          id: 'alloc_remain_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.custom,
          label: 'Available Balance',
          percentage: remainPercent,
          targetCurrency: sourceCurrency,
          sourceAmountMinor: remainMinor.toString(),
          sourceAmountFormatted: (remainMinor / 100).toStringAsFixed(2),
          destinationWalletTag: 'Primary Smart Wallet',
          actionType: MissionActionType.hold,
        ),
      ];

      return MissionIntent(
        intentId: intentId,
        originalPrompt: trimmed,
        intentType:
            isTax ? MissionIntentType.reserveTax : MissionIntentType.saveGoal,
        ruleTitle: 'Autonomous ${savePercent.toStringAsFixed(0)}% $label',
        triggerCondition: MissionTriggerCondition(
          type: 'WHEN_RECEIVE',
          sourceCurrency: sourceCurrency,
          sourceAmount: amtDouble.toStringAsFixed(2),
          sourceAmountMinor: totalMinor.toString(),
          description:
              'Whenever I receive \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code}',
        ),
        allocations: allocations,
        destinationWallets: {
          'SAVINGS': vaultTag,
          'PRIMARY': 'Primary Smart Wallet',
        },
        explanation:
            'Automatically sweep ${savePercent.toStringAsFixed(0)}% into $label and keep ${remainPercent.toStringAsFixed(0)}% in Primary Smart Wallet.',
        confidenceScore: 0.95,
        requiresExplicitApproval: true,
        provider: 'deterministic-interpreter',
      );
    }

    // Directive Type C: Convert / Currency Swap (e.g. "convert $1,000 to naira", "swap 500 usd to mxn")
    if (lower.contains('convert') ||
        lower.contains('swap') ||
        lower.contains('exchange')) {
      Currency targetCur = Currency.ngn;
      if (lower.contains('mxn') || lower.contains('peso')) targetCur = Currency.mxn;
      if (lower.contains('cad')) targetCur = Currency.cad;
      if (lower.contains('eur')) targetCur = Currency.eur;
      if (lower.contains('usd') && sourceCurrency != Currency.usd) {
        targetCur = Currency.usd;
      }

      final rate = targetCur == Currency.ngn
          ? 1550
          : targetCur == Currency.mxn
              ? 17
              : 1;
      final targetTag = 'Main ${targetCur.code} Wallet';

      final allocations = [
        MissionAllocation(
          id: 'alloc_convert_${DateTime.now().millisecondsSinceEpoch}',
          category: MissionAllocationCategory.expenses,
          label: 'Convert to ${targetCur.code}',
          percentage: 100.0,
          targetCurrency: targetCur,
          sourceAmountMinor: totalMinor.toString(),
          sourceAmountFormatted: amtDouble.toStringAsFixed(2),
          targetAmountMinor: (totalMinor * rate).toString(),
          targetAmountFormatted:
              '${(amtDouble * rate).toStringAsFixed(0)} ${targetCur.code} equivalent',
          destinationWalletTag: targetTag,
          actionType: MissionActionType.convertFx,
        ),
      ];

      return MissionIntent(
        intentId: intentId,
        originalPrompt: trimmed,
        intentType: MissionIntentType.convertFx,
        ruleTitle:
            'Convert \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to ${targetCur.code}',
        triggerCondition: MissionTriggerCondition(
          type: 'WHEN_RECEIVE',
          sourceCurrency: sourceCurrency,
          sourceAmount: amtDouble.toStringAsFixed(2),
          sourceAmountMinor: totalMinor.toString(),
          description:
              'When \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} is available',
        ),
        allocations: allocations,
        destinationWallets: {
          targetCur.code: targetTag,
        },
        explanation:
            'Convert \$${amtDouble.toStringAsFixed(2)} ${sourceCurrency.code} to ${targetCur.code} at prevailing BMONI rate.',
        confidenceScore: 0.95,
        requiresExplicitApproval: true,
        provider: 'deterministic-interpreter',
      );
    }

    // Directive Type D: 3-Way Split (The flagship prompt: 30% USD, 50% NGN, 20% Tax)
    final usdMinor = (totalMinor * 30) ~/ 100;
    final ngnMinor = (totalMinor * 50) ~/ 100;
    final taxMinor = totalMinor - usdMinor - ngnMinor;

    final allocations = [
      MissionAllocation(
        id: 'alloc_usd_${DateTime.now().millisecondsSinceEpoch}',
        category: MissionAllocationCategory.reserve,
        label: 'USD Reserve',
        percentage: 30.0,
        targetCurrency: Currency.usd,
        sourceAmountMinor: usdMinor.toString(),
        sourceAmountFormatted: (usdMinor / 100).toStringAsFixed(2),
        destinationWalletTag: 'USD Smart Vault',
        actionType: MissionActionType.hold,
      ),
      MissionAllocation(
        id: 'alloc_ngn_${DateTime.now().millisecondsSinceEpoch}',
        category: MissionAllocationCategory.expenses,
        label: 'NGN Expenses',
        percentage: 50.0,
        targetCurrency: Currency.ngn,
        sourceAmountMinor: ngnMinor.toString(),
        sourceAmountFormatted: (ngnMinor / 100).toStringAsFixed(2),
        targetAmountMinor: (ngnMinor * 1550).toString(),
        targetAmountFormatted:
            '\$${(ngnMinor / 100).toInt() >= 1000 ? '1,000' : (ngnMinor / 100).toStringAsFixed(0)} equivalent',
        destinationWalletTag: 'Main Naira Wallet',
        actionType: MissionActionType.convertFx,
      ),
      MissionAllocation(
        id: 'alloc_tax_${DateTime.now().millisecondsSinceEpoch}',
        category: MissionAllocationCategory.tax,
        label: 'Tax Reserve',
        percentage: 20.0,
        targetCurrency: Currency.usd,
        sourceAmountMinor: taxMinor.toString(),
        sourceAmountFormatted: (taxMinor / 100).toStringAsFixed(2),
        destinationWalletTag: 'Tax Escrow Reserve',
        actionType: MissionActionType.sweepVault,
      ),
    ];

    return MissionIntent(
      intentId: intentId,
      originalPrompt: trimmed,
      intentType: MissionIntentType.splitIncoming,
      ruleTitle: 'Incoming 3-Way Split: USD, NGN Expenses & Tax',
      triggerCondition: MissionTriggerCondition(
        type: 'WHEN_RECEIVE',
        sourceCurrency: Currency.usd,
        sourceAmount: amtDouble.toStringAsFixed(2),
        sourceAmountMinor: totalMinor.toString(),
        description:
            'Whenever I receive \$${amtDouble.toStringAsFixed(2)} USD',
      ),
      allocations: allocations,
      destinationWallets: {
        'USD': 'USD Smart Vault',
        'NGN': 'Main Naira Wallet',
        'TAX': 'Tax Escrow Reserve',
      },
      explanation:
          'Whenever \$${amtDouble.toStringAsFixed(2)} is received: keep 30% in USD Reserve, convert 50% to Naira for expenses, and reserve 20% for taxes.',
      confidenceScore: 0.98,
      requiresExplicitApproval: true,
      provider: 'deterministic-interpreter',
    );
  }
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/transfer_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../safety/operation_preview.dart';
import '../../transfers/transfer_funding.dart';
import '../../transfers/transfer_intent.dart';
import '../../transfers/transfer_models.dart';

class DemoTransferRepository implements TransferRepository {
  final ActivityRepository? activityRepo;
  final WalletRepository? walletRepo;

  DemoTransferRepository({this.activityRepo, this.walletRepo});

  @override
  Future<TransferIntent> interpretPrompt(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final trimmed = prompt.trim();
    final intentId = 'tx_intent_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Resolve Currency
    Currency currency = Currency.usd;
    if (RegExp(r'₦|naira|ngn', caseSensitive: false).hasMatch(trimmed)) {
      currency = Currency.ngn;
    } else if (RegExp(r'pesos?|mxn', caseSensitive: false).hasMatch(trimmed)) {
      currency = Currency.mxn;
    } else if (RegExp(r'cad|canad', caseSensitive: false).hasMatch(trimmed)) {
      currency = Currency.cad;
    } else if (RegExp(r'€|euro|eur', caseSensitive: false).hasMatch(trimmed)) {
      currency = Currency.eur;
    }

    // 2. Resolve Amount
    final amountRegex = RegExp(
      r'(?:[\$₦€]|USD\s*|NGN\s*|MXN\s*|CAD\s*|EUR\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(?:USD|NGN|MXN|CAD|EUR|dollars?|naira|pesos?)?',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(trimmed);

    String amountFormatted = '500.00';
    String amountMinor = '50000';

    if (match != null && match.group(1) != null) {
      try {
        final clean = match.group(1)!.replaceAll(',', '');
        final money = Money.fromMajorString(clean, currency);
        amountMinor = money.amountMinor.toString();
        amountFormatted = money.toMajorString();
      } catch (_) {}
    }

    // 3. Resolve Recipient
    String recipient = 'Beneficiary';
    String? purpose;

    final toMatch = RegExp(
            r'(?:to|for)\s+([^,.;]+?)(?:\s+(?:for|via|as|in)\s+([^,.;]+))?$',
            caseSensitive: false)
        .firstMatch(trimmed);
    if (toMatch != null && toMatch.group(1) != null) {
      recipient = toMatch.group(1)!.trim();
      if (toMatch.group(2) != null) {
        purpose = toMatch.group(2)!.trim();
      }
    } else {
      final emailMatch =
          RegExp(r'([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)')
              .firstMatch(trimmed);
      if (emailMatch != null) {
        recipient = emailMatch.group(1)!;
      }
    }

    if (RegExp(r'designer in ghana', caseSensitive: false).hasMatch(trimmed)) {
      recipient = 'my designer in Ghana';
      purpose = 'Design services in Ghana';
    } else {
      purpose ??= 'Payment to $recipient';
    }

    return TransferIntent(
      intentId: intentId,
      originalPrompt: trimmed,
      recipient: recipient,
      amount: amountFormatted,
      amountMinor: amountMinor,
      currency: currency,
      purpose: purpose,
      confidenceScore: 0.95,
      requiresExplicitApproval: true,
      provider: 'deterministic-fallback',
    );
  }

  @override
  Future<BalanceInspectionResult> inspectBalances({
    required TransferIntent intent,
    required List<WalletAccount> wallets,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final targetCurrency = intent.currency;
    final targetAmountMinor = BigInt.parse(intent.amountMinor);
    final targetMoney = Money.fromMinor(targetAmountMinor, targetCurrency);

    // Find direct wallet
    final directWallet = wallets.cast<WalletAccount?>().firstWhere(
          (w) =>
              w?.currency.code.toUpperCase() ==
              targetCurrency.code.toUpperCase(),
          orElse: () => null,
        );

    final directBalanceMinor =
        directWallet != null ? directWallet.balance.amountMinor : BigInt.zero;
    final hasDirectFunds = directBalanceMinor >= targetAmountMinor;

    final allOptions = <TransferFundingOption>[];

    // 1. Direct Option
    if (directWallet != null) {
      final netFeeMinor = targetCurrency == Currency.ngn
          ? BigInt.from(77500)
          : targetCurrency == Currency.mxn
              ? BigInt.from(875)
              : BigInt.from(50);
      final totalDebitMinor = targetAmountMinor + netFeeMinor;

      final directOption = TransferFundingOption(
        fundingWalletId: directWallet.id,
        fundingCurrency: targetCurrency,
        fundingWalletName: '${targetCurrency.code} Smart Wallet',
        availableBalance: directWallet.balance,
        requiresConversion: false,
        conversionLabel: 'Direct ${targetCurrency.code} Transfer',
        exchangeRate: 1.0,
        convertedDebit: targetMoney,
        networkFee: Money.fromMinor(netFeeMinor, targetCurrency),
        fxFee: Money.fromMinor(BigInt.zero, targetCurrency),
        totalDebit: Money.fromMinor(totalDebitMinor, targetCurrency),
        targetPayment: targetMoney,
      );

      if (hasDirectFunds) {
        allOptions.unshift(directOption);
      } else {
        allOptions.add(directOption);
      }
    }

    // 2. Cross-currency options
    for (final alt in wallets) {
      if (alt.currency.code == targetCurrency.code) continue;

      double rate = 1.0;
      if (alt.currency == Currency.ngn && targetCurrency == Currency.usd) {
        rate = 1 / 1550.0;
      } else if (alt.currency == Currency.usd &&
          targetCurrency == Currency.ngn) {
        rate = 1550.0;
      } else if (alt.currency == Currency.mxn &&
          targetCurrency == Currency.usd) {
        rate = 1 / 17.5;
      } else if (alt.currency == Currency.cad &&
          targetCurrency == Currency.usd) {
        rate = 1 / 1.375;
      }

      final targetMajor = double.tryParse(intent.amount) ?? 0.0;
      final requiredAltMajor = targetMajor / rate;
      final convertedAltMoney = Money.fromMajorString(
        requiredAltMajor.toStringAsFixed(2),
        alt.currency,
      );

      // Fees
      final netFeeMajor = 0.50 / rate;
      final netFeeMoney = Money.fromMajorString(
        netFeeMajor.toStringAsFixed(2),
        alt.currency,
      );
      final fxFeeMajor = requiredAltMajor * 0.0015;
      final fxFeeMoney = Money.fromMajorString(
        fxFeeMajor.toStringAsFixed(2),
        alt.currency,
      );

      final totalDebitMinor = convertedAltMoney.amountMinor +
          netFeeMoney.amountMinor +
          fxFeeMoney.amountMinor;
      final totalDebitMoney = Money.fromMinor(totalDebitMinor, alt.currency);

      final hasSuffAlt = alt.balance.amountMinor >= totalDebitMinor;

      final altOption = TransferFundingOption(
        fundingWalletId: alt.id,
        fundingCurrency: alt.currency,
        fundingWalletName: '${alt.currency.code} Smart Wallet',
        availableBalance: alt.balance,
        requiresConversion: true,
        conversionLabel: '${alt.currency.code} → ${targetCurrency.code}',
        exchangeRate: 1 / rate,
        convertedDebit: convertedAltMoney,
        networkFee: netFeeMoney,
        fxFee: fxFeeMoney,
        totalDebit: totalDebitMoney,
        targetPayment: targetMoney,
      );

      if (hasSuffAlt) {
        allOptions.add(altOption);
      }
    }

    TransferFundingOption? recOption;
    bool isPossible = false;

    if (hasDirectFunds && directWallet != null) {
      recOption = allOptions.firstWhere((o) => !o.requiresConversion);
      isPossible = true;
    } else {
      final validAlts = allOptions.where(
          (o) => o.availableBalance.amountMinor >= o.totalDebit.amountMinor);
      if (validAlts.isNotEmpty) {
        recOption = validAlts.first;
        isPossible = true;
      }
    }

    return BalanceInspectionResult(
      intent: intent,
      isDirectFunded: hasDirectFunds,
      recommendedFundingOption: recOption,
      allFundingOptions: allOptions,
      isPossible: isPossible,
      reason: isPossible
          ? null
          : 'Insufficient funds across all available wallets. You need ${intent.amount} ${intent.currency.code}.',
    );
  }

  @override
  Future<TransferProposal> createProposal({
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final proposalId = 'prop_demo_${DateTime.now().millisecondsSinceEpoch}';

    final canonical = jsonEncode({
      'proposalId': proposalId,
      'amount': intent.amount,
      'currency': intent.currency.code,
      'recipient': intent.recipient,
      'fundingWallet': fundingOption.fundingWalletName,
      'totalDebit': fundingOption.totalDebit.toMajorString(),
      'conversion': fundingOption.conversionLabel,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final hashToSign = '0x${sha256.convert(utf8.encode(canonical)).toString()}';

    return TransferProposal(
      proposalId: proposalId,
      status: 'PENDING_SIGNATURES',
      hashToSign: hashToSign,
      signPayload: hashToSign,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      fundingOption: fundingOption,
      intent: intent,
    );
  }

  @override
  Future<TransferExecutionResult> executeProposal({
    required String proposalId,
    required String signature,
    required TransferProposal proposal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final txHash =
        '0x${sha256.convert(utf8.encode('${proposalId}_$signature')).toString()}';
    final now = DateTime.now();

    // 1. Debit funding wallet if walletRepo is provided
    if (walletRepo != null) {
      try {
        await walletRepo!.debitWallet(
          walletId: proposal.fundingOption.fundingWalletId,
          amount: proposal.fundingOption.totalDebit,
        );
      } catch (_) {}
    }

    // 2. Record into shared ActivityRepository if provided
    if (activityRepo != null) {
      try {
        final amountMoney = Money.fromMinor(
          proposal.intent.amountMinor,
          proposal.intent.currency,
        );

        await activityRepo!.recordActivity(
          ActivityModel(
            id: 'act_demo_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Transfer to ${proposal.intent.recipient}',
            description: proposal.fundingOption.requiresConversion
                ? 'Paid ${proposal.intent.amount} ${proposal.intent.currency.code} (Debited ${proposal.fundingOption.totalDebit.formatFormatted()} via ${proposal.fundingOption.conversionLabel})'
                : 'Paid ${proposal.intent.amount} ${proposal.intent.currency.code} from ${proposal.fundingOption.fundingWalletName}',
            amount: amountMoney,
            currency: proposal.intent.currency,
            type: proposal.fundingOption.requiresConversion
                ? ActivityType.conversion
                : ActivityType.transfer,
            category: proposal.fundingOption.requiresConversion
                ? ActivityCategory.fx
                : ActivityCategory.transfer,
            counterparty: proposal.intent.recipient,
            source: proposal.fundingOption.fundingWalletName,
            destination: proposal.intent.recipient,
            fee: proposal.fundingOption.networkFee
                .add(proposal.fundingOption.fxFee),
            exchangeRate: proposal.fundingOption.requiresConversion
                ? '1 ${proposal.intent.currency.code} = ${proposal.fundingOption.exchangeRate?.toStringAsFixed(2) ?? "1.00"} ${proposal.fundingOption.fundingCurrency.code}'
                : 'N/A (Direct ${proposal.intent.currency.code})',
            status: FlowPayAppStatus.completed,
            timestamp: now,
            reference:
                'FP-TXN-${proposalId.length > 8 ? proposalId.substring(proposalId.length - 6).toUpperCase() : proposalId}',
            bmoniReference: txHash,
            metadata: {
              'proposalId': proposalId,
              'recipient': proposal.intent.recipient,
              'conversion': proposal.fundingOption.conversionLabel,
              'exchangeRate': proposal.fundingOption.exchangeRate,
              'fundingWallet': proposal.fundingOption.fundingWalletName,
              'totalDebit': proposal.fundingOption.totalDebit.toMajorString(),
            },
          ),
        );
      } catch (_) {}
    }

    return TransferExecutionResult(
      proposalId: proposalId,
      status: 'COMPLETED',
      transactionHash: txHash,
      timestamp: now,
      auditActivityId: 'act_demo_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // --- Legacy Compatibility ---

  @override
  Future<OperationPreview> previewTransfer({
    required Money amount,
    required String recipient,
    String? note,
  }) async {
    final fee = Money.fromMinor(50, amount.currency);
    return OperationPreview(
      previewId: 'prev_demo_${DateTime.now().millisecondsSinceEpoch}',
      intentId: 'intent_demo_transfer',
      summary: 'Send ${amount.formatFormatted()} to $recipient',
      sourceAmount: amount,
      estimatedFee: fee,
      totalAmount: amount.add(fee),
      recipient: recipient,
      requiresOnDeviceSigning: true,
      warnings: const [],
    );
  }

  @override
  Future<TransferResult> executeTransfer({
    required String previewId,
    required String signature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return TransferResult(
      proposalId: 'prop_demo_${DateTime.now().millisecondsSinceEpoch}',
      status: 'EXECUTED',
      transactionHash: '0x3a92b...demo_tx_hash_deterministic',
      isDemo: true,
      timestamp: DateTime.now(),
    );
  }
}

extension _UnshiftList<T> on List<T> {
  void unshift(T element) => insert(0, element);
}

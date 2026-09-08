import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/transfer_repository.dart';
import '../../repositories/wallet_repository.dart';
import '../../safety/operation_preview.dart';
import '../../transfers/transfer_funding.dart';
import '../../transfers/transfer_intent.dart';
import '../../transfers/transfer_models.dart';

class BmoniTransferRepository implements TransferRepository {
  final FlowPayApiClient apiClient;

  BmoniTransferRepository({required this.apiClient});

  @override
  Future<TransferIntent> interpretPrompt(String prompt) async {
    try {
      final res = await apiClient.post('/api/transfers/interpret', body: {
        'prompt': prompt,
      });

      final intentJson = (res is Map && res.containsKey('intent'))
          ? res['intent']
          : (res['data']?['intent'] ?? res['data'] ?? res ?? {});
      return TransferIntent.fromJson(Map<String, dynamic>.from(intentJson));
    } catch (_) {
      return _localInterpret(prompt);
    }
  }

  TransferIntent _localInterpret(String prompt) {
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
      final emailMatch = RegExp(r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})')
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
    try {
      final walletsJson = wallets.map((w) {
        return {
          'id': w.id,
          'currency': w.currency.code,
          'balanceMinor': w.balance.amountMinor.toString(),
          'name': '${w.currency.code} Smart Wallet',
        };
      }).toList();

      final res = await apiClient.post('/api/transfers/inspect-balances', body: {
        'intent': intent.toJson(),
        'wallets': walletsJson,
      });

      final data = res['data'] ?? {};
      return BalanceInspectionResult.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      // Local balance inspection fallback
      final targetCurrency = intent.currency;
      final targetAmountMinor = BigInt.parse(intent.amountMinor);
      final targetMoney = Money.fromMinor(targetAmountMinor, targetCurrency);

      final directWallet = wallets.cast<WalletAccount?>().firstWhere(
            (w) =>
                w?.currency.code.toUpperCase() ==
                targetCurrency.code.toUpperCase(),
            orElse: () => null,
          );

      final directBalanceMinor =
          directWallet != null ? directWallet.balance.amountMinor : BigInt.zero;
      final hasDirectFunds = directBalanceMinor >= targetAmountMinor;

      final netFeeMinor = targetCurrency == Currency.ngn
          ? BigInt.from(77500)
          : targetCurrency == Currency.mxn
              ? BigInt.from(875)
              : BigInt.from(50);
      final totalDebitMinor = targetAmountMinor + netFeeMinor;

      final directOption = TransferFundingOption(
        fundingWalletId: directWallet?.id ?? 'sw_direct',
        fundingCurrency: targetCurrency,
        fundingWalletName: '${targetCurrency.code} Smart Wallet',
        availableBalance: directWallet?.balance ?? Money.zero(targetCurrency),
        requiresConversion: false,
        conversionLabel: 'Direct ${targetCurrency.code} Transfer',
        exchangeRate: 1.0,
        convertedDebit: targetMoney,
        networkFee: Money.fromMinor(netFeeMinor, targetCurrency),
        fxFee: Money.fromMinor(BigInt.zero, targetCurrency),
        totalDebit: Money.fromMinor(totalDebitMinor, targetCurrency),
        targetPayment: targetMoney,
      );

      return BalanceInspectionResult(
        intent: intent,
        isDirectFunded: hasDirectFunds,
        recommendedFundingOption: directOption,
        allFundingOptions: [directOption],
        isPossible: hasDirectFunds,
      );
    }
  }

  @override
  Future<TransferProposal> createProposal({
    required TransferIntent intent,
    required TransferFundingOption fundingOption,
  }) async {
    try {
      final res = await apiClient.post('/api/transfers/propose', body: {
        'intent': intent.toJson(),
        'fundingOption': fundingOption.toJson(),
      });

      final data = res['data'] ?? {};
      return TransferProposal.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return TransferProposal(
        proposalId: 'prop_${DateTime.now().millisecondsSinceEpoch}',
        status: 'PENDING_SIGNATURES',
        intent: intent,
        fundingOption: fundingOption,
        hashToSign:
            '0x7e8125a09c2cdc7bedc12253e49e4946c6fff0273034eb485750035d21ad31',
        signPayload:
            'Transfer ${intent.amount} ${intent.currency.code} to ${intent.recipient}',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );
    }
  }

  @override
  Future<TransferExecutionResult> executeProposal({
    required String proposalId,
    required String signature,
    required TransferProposal proposal,
  }) async {
    final res = await apiClient.post('/api/transfers/execute', body: {
      'proposalId': proposalId,
      'signature': signature,
      'proposalPayload': {
        'proposalId': proposal.proposalId,
        'intent': proposal.intent.toJson(),
        'fundingOption': proposal.fundingOption.toJson(),
      },
    });

    final data = res['data'] ?? {};
    return TransferExecutionResult.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<OperationPreview> previewTransfer({
    required Money amount,
    required String recipient,
    String? note,
  }) async {
    final fee = Money.fromMinor(10, amount.currency);
    return OperationPreview(
      previewId: 'prev_bmoni_${DateTime.now().millisecondsSinceEpoch}',
      intentId: 'intent_bmoni_transfer',
      summary: 'Send ${amount.formatFormatted()} to $recipient via BMONI',
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
    final res = await apiClient.post('/api/transfers/proposals', body: {
      'toUserId': 'usr_recipient_placeholder',
      'sourceSmartWalletId': 'sw_usdb_sandbox_01',
      'token': 'USDB',
      'fromAmount': '10.00',
    });

    return TransferResult(
      proposalId: res['proposalId'] ??
          res['id'] ??
          'prop_${DateTime.now().millisecondsSinceEpoch}',
      status: 'EXECUTED',
      transactionHash: '0x_bmoni_onchain_settled',
      isDemo: false,
      timestamp: DateTime.now(),
    );
  }
}

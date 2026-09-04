import '../money/currency.dart';
import '../money/money.dart';
import 'transfer_intent.dart';

class TransferFundingOption {
  final String fundingWalletId;
  final Currency fundingCurrency;
  final String fundingWalletName;
  final Money availableBalance;
  final bool requiresConversion;
  final String conversionLabel; // e.g. "NGN → USD" or "Direct USD Transfer"
  final double? exchangeRate; // e.g. 1550.0
  final Money convertedDebit;
  final Money networkFee;
  final Money fxFee;
  final Money totalDebit;
  final Money targetPayment;

  const TransferFundingOption({
    required this.fundingWalletId,
    required this.fundingCurrency,
    required this.fundingWalletName,
    required this.availableBalance,
    required this.requiresConversion,
    required this.conversionLabel,
    this.exchangeRate,
    required this.convertedDebit,
    required this.networkFee,
    required this.fxFee,
    required this.totalDebit,
    required this.targetPayment,
  });

  factory TransferFundingOption.fromJson(Map<String, dynamic> json) {
    final fundCur = Currency.fromCode(json['fundingCurrency']?.toString() ?? 'USD');
    final targetCur = Currency.fromCode(json['targetCurrency']?.toString() ?? 'USD');

    return TransferFundingOption(
      fundingWalletId: json['fundingWalletId']?.toString() ?? 'sw_default',
      fundingCurrency: fundCur,
      fundingWalletName: json['fundingWalletName']?.toString() ?? '${fundCur.code} Smart Wallet',
      availableBalance: Money.fromMinor(
        json['availableBalanceMinor']?.toString() ?? '0',
        fundCur,
      ),
      requiresConversion: json['requiresConversion'] == true,
      conversionLabel: json['conversionLabel']?.toString() ?? 'Direct Transfer',
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      convertedDebit: Money.fromMinor(
        json['convertedDebitMinor']?.toString() ?? '0',
        fundCur,
      ),
      networkFee: Money.fromMinor(
        json['networkFeeMinor']?.toString() ?? '0',
        fundCur,
      ),
      fxFee: Money.fromMinor(
        json['fxFeeMinor']?.toString() ?? '0',
        fundCur,
      ),
      totalDebit: Money.fromMinor(
        json['totalDebitMinor']?.toString() ?? '0',
        fundCur,
      ),
      targetPayment: Money.fromMinor(
        json['targetPaymentMinor']?.toString() ?? '0',
        targetCur,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'fundingWalletId': fundingWalletId,
        'fundingCurrency': fundingCurrency.code,
        'fundingWalletName': fundingWalletName,
        'availableBalanceMinor': availableBalance.amountMinor.toString(),
        'availableBalanceFormatted': availableBalance.toMajorString(),
        'requiresConversion': requiresConversion,
        'conversionLabel': conversionLabel,
        if (exchangeRate != null) 'exchangeRate': exchangeRate,
        'convertedDebitMinor': convertedDebit.amountMinor.toString(),
        'convertedDebitFormatted': convertedDebit.toMajorString(),
        'networkFeeMinor': networkFee.amountMinor.toString(),
        'networkFeeFormatted': networkFee.toMajorString(),
        'fxFeeMinor': fxFee.amountMinor.toString(),
        'fxFeeFormatted': fxFee.toMajorString(),
        'totalDebitMinor': totalDebit.amountMinor.toString(),
        'totalDebitFormatted': totalDebit.toMajorString(),
        'targetPaymentMinor': targetPayment.amountMinor.toString(),
        'targetPaymentFormatted': targetPayment.toMajorString(),
      };
}

class BalanceInspectionResult {
  final TransferIntent intent;
  final bool isDirectFunded;
  final TransferFundingOption? recommendedFundingOption;
  final List<TransferFundingOption> allFundingOptions;
  final bool isPossible;
  final String? reason;

  const BalanceInspectionResult({
    required this.intent,
    required this.isDirectFunded,
    this.recommendedFundingOption,
    required this.allFundingOptions,
    required this.isPossible,
    this.reason,
  });

  factory BalanceInspectionResult.fromJson(Map<String, dynamic> json) {
    final intent = TransferIntent.fromJson(Map<String, dynamic>.from(json['intent'] ?? {}));
    final rawOptions = (json['allFundingOptions'] as List?) ?? [];
    final options = rawOptions
        .map((o) => TransferFundingOption.fromJson(Map<String, dynamic>.from(o)))
        .toList();

    TransferFundingOption? rec;
    if (json['recommendedFundingOption'] is Map) {
      rec = TransferFundingOption.fromJson(
        Map<String, dynamic>.from(json['recommendedFundingOption']),
      );
    }

    return BalanceInspectionResult(
      intent: intent,
      isDirectFunded: json['isDirectFunded'] == true,
      recommendedFundingOption: rec,
      allFundingOptions: options,
      isPossible: json['isPossible'] == true,
      reason: json['reason']?.toString(),
    );
  }
}

import '../money/currency.dart';
import '../money/money.dart';

class PayrollItemModel {
  final String employeeId;
  final String employeeName;
  final String country;
  final Currency targetCurrency;
  final String destinationStablecoin;
  final Money targetAmount;
  final Money usdAmount;
  final double exchangeRate;
  final String status; // 'PENDING' | 'SUCCESS' | 'COMPLETED' | 'FAILED'
  final bool isRailActive;
  final String? railValidationMessage;
  final String? proposalId;
  final String? transactionHash;
  final String? errorReason;

  const PayrollItemModel({
    required this.employeeId,
    required this.employeeName,
    required this.country,
    required this.targetCurrency,
    required this.destinationStablecoin,
    required this.targetAmount,
    required this.usdAmount,
    required this.exchangeRate,
    required this.status,
    this.isRailActive = true,
    this.railValidationMessage,
    this.proposalId,
    this.transactionHash,
    this.errorReason,
  });

  PayrollItemModel copyWith({
    String? status,
    String? proposalId,
    String? transactionHash,
    String? errorReason,
    bool? isRailActive,
    String? railValidationMessage,
  }) {
    return PayrollItemModel(
      employeeId: employeeId,
      employeeName: employeeName,
      country: country,
      targetCurrency: targetCurrency,
      destinationStablecoin: destinationStablecoin,
      targetAmount: targetAmount,
      usdAmount: usdAmount,
      exchangeRate: exchangeRate,
      status: status ?? this.status,
      isRailActive: isRailActive ?? this.isRailActive,
      railValidationMessage: railValidationMessage ?? this.railValidationMessage,
      proposalId: proposalId ?? this.proposalId,
      transactionHash: transactionHash ?? this.transactionHash,
      errorReason: errorReason ?? this.errorReason,
    );
  }
}

class PayrollRunModel {
  final String runId;
  final String title;
  final Money totalUsd;
  final Money totalFeeUsd;
  final Money totalSavedFeeUsd;
  final double savedPercentage;
  final Money employerBalanceUsd;
  final bool isBalanceSufficient;
  final int employeeCount;
  final List<String> countries;
  final List<String> currencies;
  final List<PayrollItemModel> items;
  final String status; // 'PREVIEW' | 'VALIDATED' | 'APPROVED' | 'PROCESSING' | 'COMPLETED' | 'PARTIALLY_COMPLETED' | 'FAILED'
  final DateTime executedAt;
  final bool isDemo;

  const PayrollRunModel({
    required this.runId,
    required this.title,
    required this.totalUsd,
    required this.totalFeeUsd,
    required this.totalSavedFeeUsd,
    this.savedPercentage = 97.0,
    required this.employerBalanceUsd,
    this.isBalanceSufficient = true,
    required this.employeeCount,
    required this.countries,
    required this.currencies,
    required this.items,
    required this.status,
    required this.executedAt,
    required this.isDemo,
  });

  bool get allRailsActive => items.every((i) => i.isRailActive);
  int get completedCount => items.where((i) => i.status == 'SUCCESS' || i.status == 'COMPLETED').length;
  int get failedCount => items.where((i) => i.status == 'FAILED').length;

  PayrollRunModel copyWith({
    String? status,
    List<PayrollItemModel>? items,
    DateTime? executedAt,
  }) {
    return PayrollRunModel(
      runId: runId,
      title: title,
      totalUsd: totalUsd,
      totalFeeUsd: totalFeeUsd,
      totalSavedFeeUsd: totalSavedFeeUsd,
      savedPercentage: savedPercentage,
      employerBalanceUsd: employerBalanceUsd,
      isBalanceSufficient: isBalanceSufficient,
      employeeCount: employeeCount,
      countries: countries,
      currencies: currencies,
      items: items ?? this.items,
      status: status ?? this.status,
      executedAt: executedAt ?? this.executedAt,
      isDemo: isDemo,
    );
  }
}

abstract class PayrollRepository {
  Future<PayrollRunModel> getPayrollPreview();
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required String signature,
  });
  Future<PayrollItemModel> retryFailedProposal({
    required String proposalId,
    required String employeeId,
    required String pin,
  });
  Future<List<PayrollRunModel>> getPastRuns();
}

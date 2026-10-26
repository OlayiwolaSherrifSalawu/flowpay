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

  /// Block-explorer link for [transactionHash] (live Stellar runs).
  final String? explorerUrl;

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
    this.explorerUrl,
  });

  /// Server JSON → item. A missing status is UNKNOWN, never success.
  factory PayrollItemModel.fromJson(Map<String, dynamic> i) {
    final cur = Currency.fromCode(i['targetCurrency']?.toString() ?? 'USD');
    return PayrollItemModel(
      employeeId: i['employeeId']?.toString() ?? '',
      employeeName: i['name']?.toString() ?? i['employeeName']?.toString() ?? '',
      country: i['country']?.toString() ?? '',
      targetCurrency: cur,
      destinationStablecoin: cur.code,
      targetAmount: Money.fromMajorString(i['targetAmountFormatted']?.toString() ?? '0.00', cur),
      usdAmount: Money.fromMajorString(i['usdAmountFormatted']?.toString() ?? '0.00', Currency.usd),
      exchangeRate: (i['exchangeRate'] as num?)?.toDouble() ?? 0,
      status: i['status']?.toString() ?? 'UNKNOWN',
      isRailActive: i['isRailActive'] == true,
      railValidationMessage: i['railValidationMessage']?.toString(),
      proposalId: i['proposalId']?.toString(),
      transactionHash: i['transactionHash']?.toString(),
      errorReason: i['error']?.toString(),
      explorerUrl: i['explorerUrl']?.toString(),
    );
  }

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
      explorerUrl: explorerUrl,
    );
  }
}

/// One atomic Stellar transaction paying up to 100 employees.
class PayrollBatchModel {
  final String proposalId;

  /// Unsigned transaction to sign (preview only).
  final String? signPayload;
  final List<String> employeeIds;
  final String status;
  final String? transactionHash;
  final String? explorerUrl;
  final String? error;

  const PayrollBatchModel({
    required this.proposalId,
    this.signPayload,
    this.employeeIds = const [],
    required this.status,
    this.transactionHash,
    this.explorerUrl,
    this.error,
  });

  factory PayrollBatchModel.fromJson(Map<String, dynamic> j) => PayrollBatchModel(
        proposalId: j['proposalId'].toString(),
        signPayload: j['signPayload']?.toString(),
        employeeIds: [for (final e in (j['employeeIds'] as List? ?? const [])) e.toString()],
        status: j['status']?.toString() ?? 'UNKNOWN',
        transactionHash: j['transactionHash']?.toString(),
        explorerUrl: j['explorerUrl']?.toString(),
        error: j['error']?.toString(),
      );
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

  /// Live: the atomic transactions to sign (preview) or their outcomes (after).
  final List<PayrollBatchModel> batches;

  /// Worst-case USD spend signed into the transactions (quotes + 1% cap).
  final Money? maxUsd;

  /// Stellar network fee for the run, in XLM.
  final String? networkFeeXlm;

  const PayrollRunModel({
    required this.runId,
    required this.title,
    required this.totalUsd,
    required this.totalFeeUsd,
    required this.totalSavedFeeUsd,
    this.savedPercentage = 0,
    required this.employerBalanceUsd,
    this.isBalanceSufficient = true,
    required this.employeeCount,
    required this.countries,
    required this.currencies,
    required this.items,
    required this.status,
    required this.executedAt,
    required this.isDemo,
    this.batches = const [],
    this.maxUsd,
    this.networkFeeXlm,
  });

  /// Server JSON → run. Missing numbers are zero, never invented.
  factory PayrollRunModel.fromJson(Map<String, dynamic> d) {
    final items = [for (final i in (d['items'] as List? ?? const [])) PayrollItemModel.fromJson(Map<String, dynamic>.from(i as Map))];
    return PayrollRunModel(
      runId: d['runId'].toString(),
      title: d['title']?.toString() ?? 'Payroll',
      totalUsd: Money.fromMajorString(d['totalUsdFormatted']?.toString() ?? '0.00', Currency.usd),
      totalFeeUsd: Money.zero(Currency.usd),
      totalSavedFeeUsd: Money.zero(Currency.usd),
      employerBalanceUsd: Money.fromMajorString(d['employerBalanceUsdFormatted']?.toString() ?? '0.00', Currency.usd),
      isBalanceSufficient: d['isBalanceSufficient'] == true,
      employeeCount: (d['employeeCount'] as num?)?.toInt() ?? items.length,
      countries: [for (final c in (d['countries'] as List? ?? const [])) c.toString()],
      currencies: [for (final c in (d['currencies'] as List? ?? const [])) c.toString()],
      items: items,
      status: d['status']?.toString() ?? 'UNKNOWN',
      executedAt: DateTime.tryParse(d['executedAt']?.toString() ?? d['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isDemo: false,
      batches: [for (final b in (d['batches'] as List? ?? const [])) PayrollBatchModel.fromJson(Map<String, dynamic>.from(b as Map))],
      maxUsd: d['maxUsdFormatted'] != null ? Money.fromMajorString(d['maxUsdFormatted'].toString(), Currency.usd) : null,
      networkFeeXlm: d['networkFeeXlm']?.toString(),
    );
  }

  bool get hasSavings => totalSavedFeeUsd.minorUnits > 0;

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
      batches: batches,
      maxUsd: maxUsd,
      networkFeeXlm: networkFeeXlm,
    );
  }
}

abstract class PayrollRepository {
  /// Live: quotes + the unsigned transactions to approve ([PayrollRunModel.batches]).
  Future<PayrollRunModel> getPayrollPreview();

  /// Submits every signed batch: `{proposalId: signedPayload}`.
  Future<PayrollRunModel> executePayrollRun({
    required String runId,
    required Map<String, String> signedBatches,
  });

  Future<List<PayrollRunModel>> getPastRuns();
}

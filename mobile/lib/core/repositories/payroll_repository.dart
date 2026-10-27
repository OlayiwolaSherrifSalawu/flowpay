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

// ── Payday guarantee (Soroban PayrollVault) ─────────────────────────────────

/// One employee's reserved salary inside a guarantee.
class GuaranteeEntryModel {
  final String employeeId;
  final String name;
  final String account;
  final String amountUsd;
  /// What the reserved USD covered at quote time, e.g. "150,000.00 NGN".
  final String coversFormatted;
  final bool paid;

  const GuaranteeEntryModel({
    required this.employeeId,
    required this.name,
    required this.account,
    required this.amountUsd,
    required this.coversFormatted,
    this.paid = false,
  });

  factory GuaranteeEntryModel.fromJson(Map<String, dynamic> j) => GuaranteeEntryModel(
        employeeId: j['employeeId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        account: j['account']?.toString() ?? '',
        amountUsd: j['amountUsd']?.toString() ?? '0.00',
        coversFormatted: j['coversFormatted']?.toString() ?? '',
        paid: j['paid'] == true,
      );
}

/// An unsigned `fund` transaction for the employer to review and sign.
class PayrollGuaranteeProposal {
  final String proposalId;
  /// Null in demo mode (nothing to sign on-chain).
  final String? signPayload;
  final DateTime unlockAt;
  final String totalUsd;
  final List<GuaranteeEntryModel> entries;
  final List<String> skipped;
  final bool isDemo;

  const PayrollGuaranteeProposal({
    required this.proposalId,
    required this.signPayload,
    required this.unlockAt,
    required this.totalUsd,
    required this.entries,
    this.skipped = const [],
    this.isDemo = false,
  });

  factory PayrollGuaranteeProposal.fromJson(Map<String, dynamic> j) => PayrollGuaranteeProposal(
        proposalId: j['proposalId'].toString(),
        signPayload: j['signPayload'] as String?,
        unlockAt: DateTime.parse(j['unlockAt'].toString()),
        totalUsd: j['totalUsd']?.toString() ?? '0.00',
        entries: [for (final e in (j['entries'] as List? ?? const [])) GuaranteeEntryModel.fromJson(Map<String, dynamic>.from(e as Map))],
        skipped: [for (final s in (j['skipped'] as List? ?? const [])) '${(s as Map)['name']}: ${s['reason']}'],
      );
}

/// A funded guarantee and its on-chain state.
class PayrollGuaranteeModel {
  final int payrollId;
  final DateTime unlockAt;
  final String totalUsd;
  final String remainingUsd;
  final bool isUnlocked;
  final List<GuaranteeEntryModel> entries;
  final String? explorerUrl;
  final bool isDemo;

  const PayrollGuaranteeModel({
    required this.payrollId,
    required this.unlockAt,
    required this.totalUsd,
    required this.remainingUsd,
    required this.isUnlocked,
    required this.entries,
    this.explorerUrl,
    this.isDemo = false,
  });

  bool get isFullyPaid => entries.isNotEmpty && entries.every((e) => e.paid);

  factory PayrollGuaranteeModel.fromJson(Map<String, dynamic> j) {
    final unlockAt = DateTime.parse(j['unlockAt'].toString());
    return PayrollGuaranteeModel(
      payrollId: (j['payrollId'] as num).toInt(),
      unlockAt: unlockAt,
      totalUsd: j['totalUsd']?.toString() ?? '0.00',
      // Missing on-chain state is unknown, never "all paid".
      remainingUsd: j['remainingUsd']?.toString() ?? j['totalUsd']?.toString() ?? '0.00',
      isUnlocked: j['isUnlocked'] == true || (j['isUnlocked'] == null && DateTime.now().isAfter(unlockAt)),
      entries: [for (final e in (j['entries'] as List? ?? const [])) GuaranteeEntryModel.fromJson(Map<String, dynamic>.from(e as Map))],
      explorerUrl: j['explorerUrl'] as String?,
    );
  }
}

/// Pay reserved for the signed-in employee.
class GuaranteedPayModel {
  final int payrollId;
  final DateTime unlockAt;
  final String amountUsd;
  final String coversFormatted;
  final bool paid;
  final bool isUnlocked;
  final String? explorerUrl;

  const GuaranteedPayModel({
    required this.payrollId,
    required this.unlockAt,
    required this.amountUsd,
    required this.coversFormatted,
    required this.paid,
    required this.isUnlocked,
    this.explorerUrl,
  });

  factory GuaranteedPayModel.fromJson(Map<String, dynamic> j) => GuaranteedPayModel(
        payrollId: (j['payrollId'] as num).toInt(),
        unlockAt: DateTime.parse(j['unlockAt'].toString()),
        amountUsd: j['amountUsd']?.toString() ?? '0.00',
        coversFormatted: j['coversFormatted']?.toString() ?? '',
        paid: j['paid'] == true,
        isUnlocked: j['isUnlocked'] == true,
        explorerUrl: j['explorerUrl'] as String?,
      );
}

/// Outcome of claiming or releasing a guaranteed salary.
class GuaranteePayoutResult {
  final String name;
  /// COMPLETED, ALREADY_PAID, PENDING or FAILED.
  final String status;
  final String? amountUsd;
  final String? explorerUrl;
  final String? error;

  const GuaranteePayoutResult({required this.name, required this.status, this.amountUsd, this.explorerUrl, this.error});

  factory GuaranteePayoutResult.fromJson(Map<String, dynamic> j) => GuaranteePayoutResult(
        name: j['name']?.toString() ?? '',
        status: j['status']?.toString() ?? 'FAILED',
        amountUsd: j['amountUsd']?.toString(),
        explorerUrl: j['explorerUrl']?.toString(),
        error: j['error']?.toString(),
      );
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

  // ── Payday guarantee ──
  /// Builds the guarantee from the live payroll for a payday at [unlockAt].
  Future<PayrollGuaranteeProposal> proposeGuarantee(DateTime unlockAt);

  /// Submits the employer-signed `fund` transaction ([signedPayload] is null in demo).
  Future<PayrollGuaranteeModel> executeGuarantee({required String proposalId, String? signedPayload});

  /// The employer's guarantees with on-chain status.
  Future<List<PayrollGuaranteeModel>> getGuarantees();

  /// Pays every unlocked, unpaid salary of a guarantee.
  Future<List<GuaranteePayoutResult>> releaseGuarantee(int payrollId);

  /// Employee side: pay reserved for me.
  Future<List<GuaranteedPayModel>> getMyGuaranteedPay();

  /// Employee side: unsigned `claim` → (proposalId, signPayload).
  Future<({String proposalId, String? signPayload})> proposeGuaranteeClaim(int payrollId);

  Future<GuaranteePayoutResult> executeGuaranteeClaim({required String proposalId, String? signedPayload});
}

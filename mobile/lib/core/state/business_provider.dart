import 'package:flutter/material.dart';
import '../wallet/wallet_signer.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../models/shared_transaction.dart';
import '../repositories/business_audit_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/payroll_repository.dart';
import '../repositories/wallet_repository.dart';

/// BusinessProvider
/// Central domain state coordinator for FlowPay Business.
/// Adheres strictly to the architectural directive:
/// "Use deterministic data through BusinessProvider. Do not put fake Stellar calls inside widgets."
class BusinessProvider extends ChangeNotifier {
  final EmployeeRepository employeeRepo;
  final PayrollRepository payrollRepo;
  final WalletRepository walletRepo;
  final BusinessAuditRepository? auditRepo;

  BusinessProvider({
    required this.employeeRepo,
    required this.payrollRepo,
    required this.walletRepo,
    this.auditRepo,
  });

  bool _isLoading = false;
  String? _errorMessage;

  List<EmployeeModel> _employees = [];
  String? _payrollPreviewError;

  /// Why the payroll preview couldn't be built (e.g. business wallet not activated).
  String? get payrollPreviewError => _payrollPreviewError;
  PayrollRunModel? _pendingPayroll;
  PayrollRunModel? _lastExecutedPayroll;
  List<WalletAccount> _wallets = [];

  // Audit State
  List<SharedTransactionModel> _auditActivities = [];
  List<PayrollRunModel> _payrollRuns = [];
  AuditFilterCategory _selectedAuditFilter = AuditFilterCategory.all;
  bool _isAuditLoading = false;
  String? _auditErrorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<EmployeeModel> get employees => List.unmodifiable(_employees);
  PayrollRunModel? get pendingPayroll => _pendingPayroll;
  PayrollRunModel? get lastExecutedPayroll => _lastExecutedPayroll;
  List<WalletAccount> get wallets => List.unmodifiable(_wallets);

  // Audit Getters
  List<SharedTransactionModel> get auditActivities => List.unmodifiable(_auditActivities);
  List<PayrollRunModel> get payrollRuns => List.unmodifiable(_payrollRuns);
  AuditFilterCategory get selectedAuditFilter => _selectedAuditFilter;
  bool get isAuditLoading => _isAuditLoading;
  String? get auditErrorMessage => _auditErrorMessage;
  int get failureCount => _auditActivities.where((a) => a.status == TransactionStatus.failed).length;

  // Computed Core Dashboard Metrics
  int get employeeCount => _employees.length;

  /// Employees who have joined (live: lifecycle READY; demo: ONBOARDED/ACTIVE).
  int get onboardedEmployeeCount => _employees
      .where((e) =>
          e.status.toUpperCase() == EmployeeLifecycleStages.ready ||
          const {'ONBOARDED', 'ACTIVE', 'READY'}
              .contains(e.onboardingStatus.toUpperCase()))
      .length;

  List<String> get uniqueCountryCodes =>
      _employees.map((e) => e.country.toUpperCase()).toSet().toList();

  List<String> get uniqueCountryNames =>
      _employees.map((e) => e.resolvedCountryName).toSet().toList();

  List<Currency> get uniqueCurrencies =>
      _employees.map((e) => e.targetCurrency).toSet().toList();

  /// Total monthly payroll in aggregate USD
  Money get totalPayrollUsd {
    if (_pendingPayroll != null) {
      return _pendingPayroll!.totalUsd;
    }
    int totalMinor = 0;
    for (final emp in _employees) {
      if (emp.usdPayrollAmount != null) {
        totalMinor += emp.usdPayrollAmount!.minorUnits;
      }
    }
    return Money.fromMinor(totalMinor, Currency.usd);
  }

  /// Amount pending disbursement for the current payroll cycle
  Money get pendingPayrollUsd {
    return _pendingPayroll?.totalUsd ?? totalPayrollUsd;
  }

  /// Total number of provisioned smart wallets
  /// Employees with their own wallet linked. (Not the employer's wallets —
  /// those are [wallets].)
  int get walletsProvisionedCount => _employees
      .where((e) =>
          (e.walletAddress?.isNotEmpty ?? false) ||
          e.walletStatus == 'PROVISIONED' ||
          e.walletStatus == 'ACTIVE')
      .length;

  /// Saved cross-border fees compared to traditional SWIFT/wire rails
  /// Savings vs. a reference wire fee — only demo runs report one. Live runs
  /// report their real cost instead ([PayrollRunModel.networkFeeXlm]).
  Money get savedFeeUsd => _pendingPayroll?.totalSavedFeeUsd ?? Money.zero(Currency.usd);

  double get savedPercentage => _pendingPayroll?.savedPercentage ?? 0;

  /// True while the first payroll preview is still being built — totals are
  /// unknown then, not zero.
  bool get isPayrollCalculating => _isLoading && _pendingPayroll == null;

  /// Display text for a payroll total: '—' while it is still being calculated.
  String payrollAmountText(Money amount) =>
      isPayrollCalculating ? '—' : amount.formatFormatted();

  /// Human-readable cost line for the current payroll preview.
  String get payrollCostLabel {
    final run = _pendingPayroll;
    if (run == null) {
      return isPayrollCalculating ? 'Quoting live rates on Stellar…' : 'No payroll to run yet';
    }
    if (run.networkFeeXlm != null) return 'Stellar network fee: ${run.networkFeeXlm} XLM';
    return 'Transfer fee: ${run.totalFeeUsd.formatFormatted()}';
  }

  /// Initial load of all business data
  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Each section loads independently: a payroll preview problem (e.g. the
      // business wallet isn't activated yet) must not hide the team or balances.
      _employees = await employeeRepo.getEmployees();
      try {
        _wallets = await walletRepo.getWallets();
      } catch (e) {
        _wallets = [];
        _errorMessage = 'Could not load balances: $e';
      }
      try {
        _pendingPayroll = await payrollRepo.getPayrollPreview();
        _payrollPreviewError = null;
      } catch (e) {
        _pendingPayroll = null;
        _payrollPreviewError = e.toString();
      }

    } catch (e) {
      _errorMessage = 'Failed to load business data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load audit activities with optional category filter
  Future<void> loadAuditActivities({AuditFilterCategory? filter}) async {
    if (filter != null) {
      _selectedAuditFilter = filter;
    }
    _isAuditLoading = true;
    _auditErrorMessage = null;
    notifyListeners();

    try {
      if (auditRepo != null) {
        _auditActivities = await auditRepo!.getAllActivities(filter: _selectedAuditFilter);
        _payrollRuns = await auditRepo!.getPayrollRuns();
      } else {
        final runs = await payrollRepo.getPastRuns();
        _payrollRuns = runs;
        _auditActivities = runs.map((r) => SharedTransactionModel.fromPayrollRun(r)).toList();
      }
    } catch (e) {
      _auditErrorMessage = 'Failed to load corporate audit: $e';
    } finally {
      _isAuditLoading = false;
      notifyListeners();
    }
  }

  /// Update active audit filter tab
  void setAuditFilter(AuditFilterCategory filter) {
    _selectedAuditFilter = filter;
    loadAuditActivities(filter: filter);
  }

  /// Fetch detail of a single payroll run
  Future<PayrollRunModel?> getPayrollRunDetail(String runId) async {
    if (auditRepo != null) {
      return await auditRepo!.getPayrollRunDetail(runId);
    }
    final match = _payrollRuns.where((r) => r.runId == runId);
    if (match.isNotEmpty) return match.first;
    return null;
  }

  /// Refresh business data
  Future<void> refresh() async {
    await loadDashboard();
  }

  /// Secondary Action: Add Employee with deterministic onboarding and instant dashboard refresh
  Future<String> addEmployee({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
    required String country,
    String? countryName,
    required Currency targetCurrency,
    Money? payrollAmount,
    Money? usdPayrollAmount,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final inviteUrl = await employeeRepo.createEmployee(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        country: country,
        countryName: countryName,
        targetCurrency: targetCurrency,
        payrollAmount:
            payrollAmount ?? Money.fromMajorString('2000.00', targetCurrency),
        usdPayrollAmount: usdPayrollAmount,
      );

      // Re-sync employees list
      _employees = await employeeRepo.getEmployees();
      return inviteUrl;
    } catch (e) {
      _errorMessage = 'Failed to add employee: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs every atomic batch of a previewed run exactly as shown (live), or
  /// verifies the PIN against a simulated payload (demo). Returns
  /// `{proposalId: signedPayload}`.
  static Future<Map<String, String>> signPayrollBatches(PayrollRunModel run, String pin) async {
    const signer = StellarWalletSigner();
    final signed = <String, String>{};
    if (run.isDemo) {
      await signer.signMessage('demo-payroll:${run.runId}', pin: pin);
      return signed;
    }
    if (!run.isBalanceSufficient) throw StateError('Your USD balance does not cover this payroll.');
    if (run.batches.isEmpty) throw StateError('Nobody is ready to be paid yet.');
    for (final batch in run.batches) {
      final payload = batch.signPayload;
      if (payload == null) throw StateError('Payroll preview is missing a transaction. Refresh and try again.');
      signed[batch.proposalId] = await signer.signTransactionXdr(payload, pin: pin);
    }
    return signed;
  }

  Future<PayrollRunModel> runPayroll({required String pin}) async {
    if (_pendingPayroll == null) {
      throw Exception('No pending payroll run available to execute.');
    }
    if (_pendingPayroll!.items.isEmpty) {
      throw StateError('Cannot execute payroll with zero proposal items.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final run = _pendingPayroll!;
      final signed = await signPayrollBatches(run, pin);
      final completed = await payrollRepo.executePayrollRun(runId: run.runId, signedBatches: signed);
      _lastExecutedPayroll = completed;
      return completed;
    } catch (e) {
      _errorMessage = 'Payroll execution failed: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}

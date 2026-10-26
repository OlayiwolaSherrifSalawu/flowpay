import '../../models/shared_transaction.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/business_audit_repository.dart';
import '../../repositories/payroll_repository.dart';
import '../../repositories/wallet_repository.dart';

/// Demo Implementation of BusinessAuditRepository
/// Composes DemoPayrollRepository, DemoWalletRepository, and DemoActivityRepository.
/// Zero direct Stellar calls — strictly aggregates existing repository contracts.
class DemoBusinessAuditRepository implements BusinessAuditRepository {
  final PayrollRepository payrollRepo;
  final WalletRepository walletRepo;
  final ActivityRepository activityRepo;

  DemoBusinessAuditRepository({
    required this.payrollRepo,
    required this.walletRepo,
    required this.activityRepo,
  });

  @override
  Future<List<PayrollRunModel>> getPayrollRuns() async {
    return await payrollRepo.getPastRuns();
  }

  @override
  Future<PayrollRunModel?> getPayrollRunDetail(String runId) async {
    final runs = await payrollRepo.getPastRuns();
    final match = runs.where((r) => r.runId == runId);
    if (match.isNotEmpty) return match.first;
    return null;
  }

  @override
  Future<List<SharedTransactionModel>> getEmployeePayments({String? runId}) async {
    final runs = await payrollRepo.getPastRuns();
    final List<SharedTransactionModel> payments = [];

    final targetRuns = runId != null ? runs.where((r) => r.runId == runId) : runs;
    for (final run in targetRuns) {
      for (final item in run.items) {
        payments.add(
          SharedTransactionModel.fromPayrollItem(
            item,
            runId: run.runId,
            date: run.executedAt,
          ),
        );
      }
    }
    payments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return payments;
  }


  @override
  Future<List<SharedTransactionModel>> getWalletOperations() async {
    final List<SharedTransactionModel> ops = [];

    // Compose from general activity repository
    final activities = await activityRepo.getRecentActivities(limit: 100);
    for (final act in activities) {
      if (act.category == ActivityCategory.transfer ||
          act.category == ActivityCategory.fx ||
          act.category == ActivityCategory.mission ||
          act.category == ActivityCategory.system) {
        ops.add(SharedTransactionModel.fromActivity(act));
      }
    }

    // Seed realistic wallet operations if empty
    if (ops.isEmpty) {
      ops.addAll([
        SharedTransactionModel(
          id: 'wop_sweep_01',
          type: TransactionType.walletOperation,
          title: 'Treasury Auto-Sweep to NGN',
          description: 'Automated FX sweep: \$5,000 USD converted to ₦7,750,000 NGN @ 1550',
          amount: Money.fromMajorString('5000.00', Currency.usd),
          secondaryAmount: Money.fromMajorString('7750000.00', Currency.ngn),
          secondaryCurrency: 'NGN',
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          flowpayReference: 'FP-SWP-7721',
          networkReference: 'SW-TX-9901',
          counterparty: 'Treasury Wallet (USD -> NGN)',
          country: 'NG',
        ),
        SharedTransactionModel(
          id: 'wop_fund_02',
          type: TransactionType.walletOperation,
          title: 'Employer Inbound Wire Settlement',
          description: 'Received \$50,000 USD corporate treasury top-up via Circle wire',
          amount: Money.fromMajorString('50000.00', Currency.usd),
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          flowpayReference: 'FP-FND-5501',
          networkReference: 'WIRE-SETTLE-8812',
          counterparty: 'FlowPay Treasury',
          country: 'US',
        ),
      ]);
    }

    ops.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ops;
  }

  @override
  Future<List<SharedTransactionModel>> getFailures() async {
    final all = await getAllActivities(filter: AuditFilterCategory.all);
    return all.where((item) => item.status == TransactionStatus.failed).toList();
  }

  @override
  Future<List<SharedTransactionModel>> getAllActivities({
    AuditFilterCategory filter = AuditFilterCategory.all,
    int limit = 100,
  }) async {
    final List<SharedTransactionModel> combined = [];

    if (filter == AuditFilterCategory.payrollRuns) {
      final runs = await getPayrollRuns();
      return runs.map((r) => SharedTransactionModel.fromPayrollRun(r)).toList();
    }

    if (filter == AuditFilterCategory.employeePayments) {
      return await getEmployeePayments();
    }

    if (filter == AuditFilterCategory.walletOperations) {
      return await getWalletOperations();
    }

    // Default: Aggregate everything across categories
    final runs = await getPayrollRuns();
    for (final run in runs) {
      combined.add(SharedTransactionModel.fromPayrollRun(run));
      for (final item in run.items) {
        combined.add(
          SharedTransactionModel.fromPayrollItem(
            item,
            runId: run.runId,
            date: run.executedAt,
          ),
        );
      }
    }

    final walletOps = await getWalletOperations();
    combined.addAll(walletOps);

    // Filter duplicates by ID
    final seenIds = <String>{};
    final unique = combined.where((tx) => seenIds.add(tx.id)).toList();

    // Sort chronologically descending
    unique.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filter == AuditFilterCategory.failures) {
      return unique.where((tx) => tx.status == TransactionStatus.failed).toList();
    }

    return unique.take(limit).toList();
  }
}

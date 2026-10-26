import '../../models/shared_transaction.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/business_audit_repository.dart';
import '../../repositories/payroll_repository.dart';
import '../../repositories/wallet_repository.dart';

/// Stellar Live Implementation of BusinessAuditRepository
/// Composes StellarPayrollRepository, StellarWalletRepository, and LiveActivityRepository.
/// Reuses existing repository contracts without calling Stellar directly for anything new.
class LiveBusinessAuditRepository implements BusinessAuditRepository {
  final PayrollRepository payrollRepo;
  final WalletRepository walletRepo;
  final ActivityRepository activityRepo;

  LiveBusinessAuditRepository({
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
    // A failed read propagates: an empty audit trail must mean "no activity",
    // never "we couldn't load it".
    final activities = await activityRepo.getRecentActivities(limit: 50);
    for (final act in activities) {
      if (act.category == ActivityCategory.transfer ||
          act.category == ActivityCategory.fx ||
          act.category == ActivityCategory.mission ||
          act.category == ActivityCategory.system) {
        ops.add(SharedTransactionModel.fromActivity(act));
      }
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
    int limit = 50,
  }) async {
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

    final List<SharedTransactionModel> combined = [];

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

    final seenIds = <String>{};
    final unique = combined.where((tx) => seenIds.add(tx.id)).toList();
    unique.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filter == AuditFilterCategory.failures) {
      return unique.where((tx) => tx.status == TransactionStatus.failed).toList();
    }

    return unique.take(limit).toList();
  }
}

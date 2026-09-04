import '../models/shared_transaction.dart';
import 'payroll_repository.dart';

/// Filter categories for Corporate Audit view
enum AuditFilterCategory {
  all,
  payrollRuns,
  employeePayments,
  cardTransactions,
  walletOperations,
  failures,
}

extension AuditFilterCategoryX on AuditFilterCategory {
  String get label {
    switch (this) {
      case AuditFilterCategory.all:
        return 'All Activity';
      case AuditFilterCategory.payrollRuns:
        return 'Payroll Runs';
      case AuditFilterCategory.employeePayments:
        return 'Employee Payments';
      case AuditFilterCategory.cardTransactions:
        return 'Card Transactions';
      case AuditFilterCategory.walletOperations:
        return 'Wallet Operations';
      case AuditFilterCategory.failures:
        return 'Failures';
    }
  }
}

/// Business Audit Repository Contract
/// This is a read/aggregation layer over data already fetched by Prompts 10-13 repositories:
/// - PayrollRepository (Prompts 10 & 13)
/// - CardRepository (Prompt 12)
/// - WalletRepository / EmbeddedWalletReadDataSource (Prompt 11)
/// - ActivityRepository (Audit trail)
///
/// It strictly composes existing data paths and DOES NOT invoke any new BMONI endpoints.
abstract class BusinessAuditRepository {
  /// Fetch all historical and current payroll runs
  Future<List<PayrollRunModel>> getPayrollRuns();

  /// Fetch detail of a specific payroll run with employee payment items
  Future<PayrollRunModel?> getPayrollRunDetail(String runId);

  /// Fetch individual employee payments (optionally filtered by payroll run)
  Future<List<SharedTransactionModel>> getEmployeePayments({String? runId});

  /// Fetch virtual spend card transactions
  Future<List<SharedTransactionModel>> getCardTransactions();

  /// Fetch smart wallet operations (transfers, funding, sweeps)
  Future<List<SharedTransactionModel>> getWalletOperations();

  /// Fetch all failures across payroll proposals, card spends, and wallet operations
  Future<List<SharedTransactionModel>> getFailures();

  /// Fetch all aggregated activities with optional filter category
  Future<List<SharedTransactionModel>> getAllActivities({
    AuditFilterCategory filter = AuditFilterCategory.all,
    int limit = 50,
  });
}

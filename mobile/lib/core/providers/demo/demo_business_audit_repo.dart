import '../../models/shared_transaction.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/business_audit_repository.dart';
import '../../repositories/card_repository.dart';
import '../../repositories/payroll_repository.dart';
import '../../repositories/wallet_repository.dart';

/// Demo Implementation of BusinessAuditRepository
/// Composes DemoPayrollRepository, DemoCardRepository, DemoWalletRepository, and DemoActivityRepository.
/// Zero direct BMONI calls — strictly aggregates existing repository contracts.
class DemoBusinessAuditRepository implements BusinessAuditRepository {
  final PayrollRepository payrollRepo;
  final CardRepository cardRepo;
  final WalletRepository walletRepo;
  final ActivityRepository activityRepo;

  DemoBusinessAuditRepository({
    required this.payrollRepo,
    required this.cardRepo,
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
  Future<List<SharedTransactionModel>> getCardTransactions() async {
    final List<SharedTransactionModel> cardTxs = [];
    final cards = await cardRepo.getCards();

    for (final card in cards) {
      final txs = await cardRepo.getCardTransactions(card.id);
      for (final tx in txs) {
        cardTxs.add(
          SharedTransactionModel.fromCardTransaction(
            tx,
            cardName: card.cardName,
            last4: card.last4,
          ),
        );
      }
    }

    // Include seeded demo corporate card transactions if repository is empty
    if (cardTxs.isEmpty) {
      cardTxs.addAll([
        SharedTransactionModel(
          id: 'ctx_aws_01',
          type: TransactionType.cardTransaction,
          title: 'AWS Cloud Services',
          description: 'Card •••• 8814 (Bunch Dillon) · Cloud Infrastructure',
          amount: Money.fromMajorString('245.80', Currency.usd),
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          flowpayReference: 'FP-CRD-AWS01',
          bmoniReference: 'TX-BMONI-CRD-901',
          counterparty: 'Amazon Web Services EMEA',
          country: 'US',
        ),
        SharedTransactionModel(
          id: 'ctx_figma_02',
          type: TransactionType.cardTransaction,
          title: 'Figma Enterprise',
          description: 'Card •••• 4289 (Samson Jabo) · Software & SaaS',
          amount: Money.fromMajorString('45.00', Currency.usd),
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          flowpayReference: 'FP-CRD-FIG02',
          bmoniReference: 'TX-BMONI-CRD-902',
          counterparty: 'Figma Inc',
          country: 'US',
        ),
        SharedTransactionModel(
          id: 'ctx_uber_03',
          type: TransactionType.failure,
          title: 'Uber for Business',
          description: 'Card •••• 8814 · Local Travel Cap Exceeded',
          amount: Money.fromMajorString('78.50', Currency.usd),
          status: TransactionStatus.failed,
          timestamp: DateTime.now().subtract(const Duration(days: 4)),
          flowpayReference: 'FP-CRD-UBR03',
          bmoniReference: 'TX-BMONI-CRD-903',
          counterparty: 'Uber BV',
          country: 'NG',
          errorReason: 'Card monthly spend ceiling enforced (\$500 limit reached)',
          failedStage: 'CARD_AUTHORIZATION',
        ),
      ]);
    }

    cardTxs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return cardTxs;
  }

  @override
  Future<List<SharedTransactionModel>> getWalletOperations() async {
    final List<SharedTransactionModel> ops = [];

    // Compose from general activity repository
    final activities = await activityRepo.getRecentActivities(limit: 40);
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
          title: 'Treasury Auto-Sweep to CNGN',
          description: 'Automated FX sweep: \$5,000 USDB converted to ₦7,750,000 CNGN @ 1550',
          amount: Money.fromMajorString('5000.00', Currency.usd),
          secondaryAmount: Money.fromMajorString('7750000.00', Currency.ngn),
          secondaryCurrency: 'CNGN',
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          flowpayReference: 'FP-SWP-7721',
          bmoniReference: 'SW-TX-9901',
          counterparty: 'Treasury Wallet (USDB -> CNGN)',
          country: 'NG',
        ),
        SharedTransactionModel(
          id: 'wop_fund_02',
          type: TransactionType.walletOperation,
          title: 'Employer Inbound Wire Settlement',
          description: 'Received \$50,000 USDB corporate treasury top-up via Circle wire',
          amount: Money.fromMajorString('50000.00', Currency.usd),
          status: TransactionStatus.completed,
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          flowpayReference: 'FP-FND-5501',
          bmoniReference: 'WIRE-SETTLE-8812',
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
    int limit = 50,
  }) async {
    final List<SharedTransactionModel> combined = [];

    if (filter == AuditFilterCategory.payrollRuns) {
      final runs = await getPayrollRuns();
      return runs.map((r) => SharedTransactionModel.fromPayrollRun(r)).toList();
    }

    if (filter == AuditFilterCategory.employeePayments) {
      return await getEmployeePayments();
    }

    if (filter == AuditFilterCategory.cardTransactions) {
      return await getCardTransactions();
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

    final cardTxs = await getCardTransactions();
    combined.addAll(cardTxs);

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

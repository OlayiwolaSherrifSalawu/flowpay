import '../money/currency.dart';
import '../money/money.dart';
import '../repositories/activity_repository.dart';
import '../repositories/card_repository.dart';
import '../repositories/payroll_repository.dart';
import '../wallets_cards/models/embedded_wallet.dart';

/// Categories of transactions supported across FlowPay Business
enum TransactionType {
  payrollRun,
  employeePayment,
  cardTransaction,
  walletOperation,
  failure,
}

/// Canonical transaction statuses across all FlowPay operations
/// Consistent with Prompt 13 per-employee model:
/// Draft, Pending Approval, Processing, Completed, Partially Completed, Failed.
enum TransactionStatus {
  draft,
  pendingApproval,
  processing,
  completed,
  partiallyCompleted,
  failed,
}

extension TransactionStatusX on TransactionStatus {
  String get displayName {
    switch (this) {
      case TransactionStatus.draft:
        return 'Draft';
      case TransactionStatus.pendingApproval:
        return 'Pending Approval';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.partiallyCompleted:
        return 'Partially Completed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  static TransactionStatus fromString(String? value) {
    if (value == null) return TransactionStatus.completed;
    final norm = value.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (norm) {
      case 'DRAFT':
        return TransactionStatus.draft;
      case 'PENDING':
      case 'PENDING_APPROVAL':
      case 'AWAITING_APPROVAL':
      case 'VALIDATED':
      case 'APPROVED':
        return TransactionStatus.pendingApproval;
      case 'PROCESSING':
      case 'EXECUTING':
        return TransactionStatus.processing;
      case 'COMPLETED':
      case 'SUCCESS':
      case 'PAID':
      case 'ACTIVE':
        return TransactionStatus.completed;
      case 'PARTIALLY_COMPLETED':
      case 'PARTIAL':
        return TransactionStatus.partiallyCompleted;
      case 'FAILED':
      case 'ERROR':
      case 'DECLINED':
      case 'REJECTED':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.completed;
    }
  }
}

/// Canonical Shared Transaction and Activity Model
/// Shared across Payroll Runs, Employee Payments, Card Transactions, and Wallet Operations.
/// Eliminates model duplication while supporting rich metadata and strict secret sanitization.
class SharedTransactionModel {
  final String id;
  final TransactionType type;
  final String title;
  final String description;
  final Money amount;
  final Money? secondaryAmount;
  final String? secondaryCurrency; // Stablecoin code: CNGN, MEXe, CADC, USDB
  final TransactionStatus status;
  final DateTime timestamp;
  final String? flowpayReference;
  final String? bmoniReference; // Sanitized public reference (proposalId, txHash) - NEVER secret keys!
  final String? counterparty;
  final String? country;
  final String? errorReason;
  final String? failedStage;
  final Map<String, dynamic>? metadata;

  const SharedTransactionModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.amount,
    this.secondaryAmount,
    this.secondaryCurrency,
    required this.status,
    required this.timestamp,
    this.flowpayReference,
    this.bmoniReference,
    this.counterparty,
    this.country,
    this.errorReason,
    this.failedStage,
    this.metadata,
  });

  bool get isFailure => status == TransactionStatus.failed;

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }

  /// Adapter from a PayrollRunModel
  factory SharedTransactionModel.fromPayrollRun(PayrollRunModel run) {
    final status = TransactionStatusX.fromString(run.status);
    return SharedTransactionModel(
      id: run.runId,
      type: status == TransactionStatus.failed ? TransactionType.failure : TransactionType.payrollRun,
      title: run.title,
      description: 'Disbursed ${run.totalUsd.formatted} to ${run.employeeCount} employees across ${run.countries.join(', ')}',
      amount: run.totalUsd,
      secondaryAmount: run.totalFeeUsd,
      secondaryCurrency: 'USDB',
      status: status,
      timestamp: run.executedAt,
      flowpayReference: 'FP-PAY-${run.runId.length > 8 ? run.runId.substring(run.runId.length - 8) : run.runId}',
      bmoniReference: run.items.isNotEmpty ? run.items.first.proposalId : null,
      counterparty: '${run.employeeCount} Employees',
      country: run.countries.join('/'),
      errorReason: run.failedCount > 0 ? '${run.failedCount} employee payouts failed' : null,
      metadata: {
        'runId': run.runId,
        'employeeCount': run.employeeCount,
        'countries': run.countries,
        'totalSavedFeeUsd': run.totalSavedFeeUsd.formatted,
        'savedPercentage': run.savedPercentage,
        'completedCount': run.completedCount,
        'failedCount': run.failedCount,
      },
    );
  }

  /// Adapter from a PayrollItemModel
  factory SharedTransactionModel.fromPayrollItem(
    PayrollItemModel item, {
    required String runId,
    required DateTime date,
  }) {
    final isFailed = item.status.toUpperCase() == 'FAILED';
    final status = isFailed ? TransactionStatus.failed : TransactionStatusX.fromString(item.status);

    return SharedTransactionModel(
      id: 'pay_item_${item.employeeId}_${item.proposalId ?? date.millisecondsSinceEpoch}',
      type: isFailed ? TransactionType.failure : TransactionType.employeePayment,
      title: 'Salary: ${item.employeeName}',
      description: '${item.targetAmount.formatted} ${item.destinationStablecoin} via ${item.country} rail',
      amount: item.usdAmount,
      secondaryAmount: item.targetAmount,
      secondaryCurrency: item.destinationStablecoin,
      status: status,
      timestamp: date,
      flowpayReference: 'FP-EMP-${item.employeeId}',
      bmoniReference: item.proposalId ?? item.transactionHash,
      counterparty: item.employeeName,
      country: item.country,
      errorReason: item.errorReason,
      failedStage: isFailed ? 'PROPOSAL_EXECUTION' : null,
      metadata: {
        'employeeId': item.employeeId,
        'employeeName': item.employeeName,
        'destinationStablecoin': item.destinationStablecoin,
        'exchangeRate': item.exchangeRate,
        'proposalId': item.proposalId,
        'transactionHash': item.transactionHash,
        'railValidationMessage': item.railValidationMessage,
        'runId': runId,
      },
    );
  }

  /// Adapter from CardTransactionModel
  factory SharedTransactionModel.fromCardTransaction(
    CardTransactionModel tx, {
    String? cardName,
    String? last4,
  }) {
    final isFailed = tx.status.toUpperCase() == 'DECLINED' || tx.status.toUpperCase() == 'FAILED';
    final status = isFailed ? TransactionStatus.failed : TransactionStatusX.fromString(tx.status);

    return SharedTransactionModel(
      id: tx.id,
      type: isFailed ? TransactionType.failure : TransactionType.cardTransaction,
      title: tx.merchantName,
      description: 'Card •••• ${last4 ?? '••••'} · ${tx.category}',
      amount: tx.amount,
      status: status,
      timestamp: tx.timestamp,
      flowpayReference: 'FP-CRD-${tx.id.length > 6 ? tx.id.substring(tx.id.length - 6) : tx.id}',
      bmoniReference: 'TX-${tx.id}',
      counterparty: tx.merchantName,
      country: 'US',
      errorReason: isFailed ? 'Card spend declined (merchant rule or spend ceiling)' : null,
      metadata: {
        'cardId': tx.cardId,
        'category': tx.category,
        'merchantName': tx.merchantName,
      },
    );
  }

  /// Adapter from EmbeddedWalletTransaction
  factory SharedTransactionModel.fromWalletTransaction(EmbeddedWalletTransaction tx) {
    final isFailed = tx.status == EmbeddedWalletTransactionStatus.failed;
    final status = isFailed
        ? TransactionStatus.failed
        : (tx.status == EmbeddedWalletTransactionStatus.pending
            ? TransactionStatus.processing
            : TransactionStatus.completed);

    final currency = Currency.fromCode(tx.currency);
    final amountMoney = Money.fromMajorString(tx.amount.toStringAsFixed(2), currency);

    return SharedTransactionModel(
      id: tx.id,
      type: isFailed ? TransactionType.failure : TransactionType.walletOperation,
      title: tx.title.isNotEmpty ? tx.title : 'Wallet Transfer',
      description: tx.description ?? (tx.isIncoming ? 'Incoming funds on-chain' : 'Disbursement from wallet'),
      amount: amountMoney,
      status: status,
      timestamp: tx.createdAt,
      flowpayReference: tx.reference ?? 'FP-WLT-${tx.id.length > 6 ? tx.id.substring(tx.id.length - 6) : tx.id}',
      bmoniReference: tx.id,
      counterparty: tx.counterpartyName ?? 'Smart Wallet',
      country: currency == Currency.ngn ? 'NG' : (currency == Currency.mxn ? 'MX' : 'US'),
      errorReason: isFailed ? 'Smart wallet transfer reverted or failed threshold' : null,
      metadata: tx.metadata ?? {'walletId': tx.walletId, 'direction': tx.direction.name},
    );
  }

  /// Adapter from ActivityModel
  factory SharedTransactionModel.fromActivity(ActivityModel act) {
    final status = TransactionStatusX.fromString(act.status.name);
    TransactionType type;
    switch (act.category) {
      case ActivityCategory.payroll:
        type = TransactionType.payrollRun;
        break;
      case ActivityCategory.card:
        type = TransactionType.cardTransaction;
        break;
      case ActivityCategory.transfer:
      case ActivityCategory.fx:
        type = TransactionType.walletOperation;
        break;
      default:
        type = TransactionType.walletOperation;
    }

    return SharedTransactionModel(
      id: act.id,
      type: status == TransactionStatus.failed ? TransactionType.failure : type,
      title: act.title,
      description: act.description,
      amount: act.amount ?? Money.fromMajorString('0.00', Currency.usd),
      status: status,
      timestamp: act.timestamp,
      flowpayReference: act.reference ?? 'FP-ACT-${act.id}',
      bmoniReference: act.reference,
      counterparty: act.metadata?['recipient'] ?? act.metadata?['merchant'],
      country: act.metadata?['rail'] == 'CNGN' ? 'NG' : (act.metadata?['rail'] == 'MEXe' ? 'MX' : 'US'),
      metadata: act.metadata,
    );
  }
}

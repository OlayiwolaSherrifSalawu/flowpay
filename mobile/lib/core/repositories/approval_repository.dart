import '../money/currency.dart';
import '../money/money.dart';

enum ApprovalType {
  missionExecution,
  transfer,
  fxConversion,
  payroll,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

class PendingApprovalModel {
  final String id;
  final ApprovalType type;
  final String title;
  final String description;
  final Money amount;
  final Currency? targetCurrency;
  final Money? targetAmount;
  final double? exchangeRate;
  final String? recipient;
  final String? ruleId;
  final DateTime createdAt;
  final ApprovalStatus status;
  final Map<String, dynamic>? metadata;

  const PendingApprovalModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.amount,
    this.targetCurrency,
    this.targetAmount,
    this.exchangeRate,
    this.recipient,
    this.ruleId,
    required this.createdAt,
    this.status = ApprovalStatus.pending,
    this.metadata,
  });

  PendingApprovalModel copyWith({
    String? id,
    ApprovalType? type,
    String? title,
    String? description,
    Money? amount,
    Currency? targetCurrency,
    Money? targetAmount,
    double? exchangeRate,
    String? recipient,
    String? ruleId,
    DateTime? createdAt,
    ApprovalStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return PendingApprovalModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      targetAmount: targetAmount ?? this.targetAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      recipient: recipient ?? this.recipient,
      ruleId: ruleId ?? this.ruleId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

abstract class ApprovalRepository {
  Future<List<PendingApprovalModel>> getPendingApprovals();
  Future<bool> approveAction(String approvalId, {String? pin});
  Future<bool> rejectAction(String approvalId, {String? reason});
}

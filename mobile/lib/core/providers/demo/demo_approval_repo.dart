import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/approval_repository.dart';

class DemoApprovalRepository implements ApprovalRepository {
  final List<PendingApprovalModel> _approvals = [
    PendingApprovalModel(
      id: 'appr_01',
      type: ApprovalType.missionExecution,
      title: 'Money Mission: 20% Auto-Sweep',
      description: 'Auto-sweep \$400.00 USD → ₦620,000 NGN into Lagos Savings Wallet',
      amount: Money.fromMajorString('400.00', Currency.usd),
      targetCurrency: Currency.ngn,
      targetAmount: Money.fromMajorString('620000.00', Currency.ngn),
      exchangeRate: 1550.0,
      ruleId: 'm1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      status: ApprovalStatus.pending,
      metadata: {'ruleName': '20% Emergency Fund Auto-Sweep', 'trigger': 'Incoming Client Wire \$2,000.00'},
    ),
    PendingApprovalModel(
      id: 'appr_02',
      type: ApprovalType.transfer,
      title: 'Transfer Proposal: Samson Jabo',
      description: 'Outbound BMONI settlement \$500.00 USD → \$8,750 MXN (Mexico City)',
      amount: Money.fromMajorString('500.00', Currency.usd),
      targetCurrency: Currency.mxn,
      targetAmount: Money.fromMajorString('8750.00', Currency.mxn),
      exchangeRate: 17.5,
      recipient: 'samson.jabo@example.mx',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      status: ApprovalStatus.pending,
      metadata: {'network': 'BMONI Rail', 'gasFee': '\$0.02 USDB'},
    ),
    PendingApprovalModel(
      id: 'appr_03',
      type: ApprovalType.fxConversion,
      title: 'FX Dip Conversion: USD to NGN',
      description: 'Target exchange rate reached (1550.00). Convert \$1,000 USD to ₦1,550,000 NGN',
      amount: Money.fromMajorString('1000.00', Currency.usd),
      targetCurrency: Currency.ngn,
      targetAmount: Money.fromMajorString('1550000.00', Currency.ngn),
      exchangeRate: 1550.0,
      ruleId: 'm3',
      createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 20)),
      status: ApprovalStatus.pending,
      metadata: {'orderType': 'Limit Order Triggered', 'targetVault': 'CNGN Vault'},
    ),
  ];

  @override
  Future<List<PendingApprovalModel>> getPendingApprovals() async {
    return _approvals.where((a) => a.status == ApprovalStatus.pending).toList();
  }

  @override
  Future<bool> approveAction(String approvalId, {String? pin}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _approvals.indexWhere((a) => a.id == approvalId);
    if (idx != -1) {
      _approvals[idx] = _approvals[idx].copyWith(status: ApprovalStatus.approved);
      return true;
    }
    return false;
  }

  @override
  Future<bool> rejectAction(String approvalId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _approvals.indexWhere((a) => a.id == approvalId);
    if (idx != -1) {
      _approvals[idx] = _approvals[idx].copyWith(status: ApprovalStatus.rejected);
      return true;
    }
    return false;
  }
}

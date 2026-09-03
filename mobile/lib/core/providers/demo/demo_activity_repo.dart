import '../../design_system/states.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/activity_repository.dart';

class DemoActivityRepository implements ActivityRepository {
  final List<ActivityModel> _activities = [
    ActivityModel(
      id: 'act_demo_01',
      title: 'Emergency Fund Auto-Sweep',
      description: 'Mission executed: \$240.00 swept to high-yield NGN savings',
      amount: Money.fromMajorString('240.00', Currency.usd),
      category: ActivityCategory.mission,
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(minutes: 42)),
      reference: 'SWEEP-NGN-9812',
      metadata: {'rule': '20% Emergency Fund Auto-Sweep', 'rail': 'CNGN'},
    ),
    ActivityModel(
      id: 'act_demo_02',
      title: 'Transfer to Bunch Dillon',
      description: 'Sent \$150.00 USD (settled via B-Key on-device signing)',
      amount: Money.fromMajorString('150.00', Currency.usd),
      category: ActivityCategory.transfer,
      status: FlowPayAppStatus.success,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      reference: 'TXN-BMONI-0428',
      metadata: {'recipient': 'bunch.dillon@example.ng', 'rail': 'USDB'},
    ),
    ActivityModel(
      id: 'act_demo_03',
      title: 'Virtual Card: AWS Cloud Services',
      description: 'Card •••• 5510 authorized \$24.50 recurring subscription',
      amount: Money.fromMajorString('24.50', Currency.usd),
      category: ActivityCategory.card,
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      reference: 'CRD-AUTH-8812',
      metadata: {'merchant': 'AWS EMEA', 'category': 'Cloud Infrastructure'},
    ),
    ActivityModel(
      id: 'act_demo_04',
      title: 'FX Target Sweep (MXN)',
      description: 'Triggered auto-conversion: \$500 USD → \$8,750 MXN @ 17.50',
      amount: Money.fromMajorString('500.00', Currency.usd),
      category: ActivityCategory.fx,
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      reference: 'FX-AUTO-3319',
      metadata: {'rate': 17.50, 'source': 'USDB', 'target': 'MEXe'},
    ),
    ActivityModel(
      id: 'act_demo_05',
      title: 'Contractor Card Cap Enforced',
      description: 'Protected \$500.00 ceiling on monthly contractor card spend',
      amount: null,
      category: ActivityCategory.mission,
      status: FlowPayAppStatus.completed,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      reference: 'CAP-RULE-001',
      metadata: {'ceiling': '\$500.00', 'status': 'Enforced'},
    ),
  ];

  @override
  Future<List<ActivityModel>> getRecentActivities({
    int limit = 20,
    ActivityCategory? category,
  }) async {
    var list = _activities;
    if (category != null) {
      list = list.where((a) => a.category == category).toList();
    }
    return list.take(limit).toList();
  }

  @override
  Future<ActivityModel> recordActivity(ActivityModel activity) async {
    _activities.insert(0, activity);
    return activity;
  }
}

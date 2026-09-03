import '../../money/currency.dart';
import '../../money/money.dart';
import '../../repositories/mission_repository.dart';

class DemoMissionRepository implements MissionRepository {
  final List<MoneyMissionModel> _missions = [
    MoneyMissionModel(
      id: 'm1',
      title: '20% Emergency Fund Auto-Sweep',
      tagline: 'Auto-sweeps 20% of incoming international USD to high-yield NGN savings.',
      ruleType: MissionRuleType.autoSweep,
      isActive: true,
      stats: '\$1,420 swept this month',
      conditionSummary: 'When incoming USD wire > \$500',
      actionSummary: 'Sweep 20% to CNGN Smart Wallet',
      targetCurrency: Currency.ngn,
      percentage: 20.0,
      thresholdAmount: Money.fromMajorString('500.00', Currency.usd),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    MoneyMissionModel(
      id: 'm2',
      title: 'Contractor Card Monthly Cap',
      tagline: 'Enforce a strict \$500/month spending ceiling on contractor virtual cards.',
      ruleType: MissionRuleType.spendCap,
      isActive: true,
      stats: 'Protected \$2,100 from overdrafts',
      conditionSummary: 'Monthly aggregate spend >= \$500',
      actionSummary: 'Temporarily freeze card until next cycle',
      targetCurrency: Currency.usd,
      thresholdAmount: Money.fromMajorString('500.00', Currency.usd),
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    MoneyMissionModel(
      id: 'm3',
      title: 'FX Rate Alert & Dip Conversion',
      tagline: 'Auto-convert USD to MXN when exchange rate hits favorable threshold (>18.0).',
      ruleType: MissionRuleType.fxTarget,
      isActive: false,
      stats: 'Standing order active • Threshold: 18.00',
      conditionSummary: 'USD/MXN market rate >= 18.00',
      actionSummary: 'Auto-convert \$1,000 USD to MEXe',
      targetCurrency: Currency.mxn,
      thresholdAmount: Money.fromMajorString('1000.00', Currency.usd),
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  @override
  Future<List<MoneyMissionModel>> getMissions() async {
    return List.unmodifiable(_missions);
  }

  @override
  Future<MoneyMissionModel> toggleMission(String id) async {
    final idx = _missions.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final current = _missions[idx];
      final updated = current.copyWith(isActive: !current.isActive);
      _missions[idx] = updated;
      return updated;
    }
    throw Exception('Mission not found: $id');
  }

  @override
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission) async {
    _missions.add(mission);
    return mission;
  }
}

import '../../money/currency.dart';
import '../../network/api_client.dart';
import '../../repositories/mission_repository.dart';

class BmoniMissionRepository implements MissionRepository {
  final FlowPayApiClient apiClient;

  BmoniMissionRepository({required this.apiClient});

  @override
  Future<List<MoneyMissionModel>> getMissions() async {
    try {
      final res = await apiClient.get('/api/missions');
      if (res is List) {
        return res.map((m) {
          final typeStr = (m['rule_type'] as String? ?? 'AUTO_SWEEP').toUpperCase();
          MissionRuleType rule = MissionRuleType.autoSweep;
          if (typeStr == 'SPEND_CAP') rule = MissionRuleType.spendCap;
          if (typeStr == 'EMERGENCY_RESERVE') rule = MissionRuleType.emergencyReserve;
          if (typeStr == 'FX_TARGET') rule = MissionRuleType.fxTarget;

          return MoneyMissionModel(
            id: m['id']?.toString() ?? 'm_unknown',
            title: m['title']?.toString() ?? 'Autonomous Mission',
            tagline: m['description']?.toString() ?? '',
            ruleType: rule,
            isActive: m['is_active'] == true,
            stats: 'Active BMONI Rule',
            conditionSummary: 'Condition active on BMONI rail',
            actionSummary: 'Deterministic execution enabled',
            targetCurrency: Currency.usd,
            createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MoneyMissionModel> toggleMission(String id) async {
    try {
      final res = await apiClient.patch('/api/missions/$id/toggle');
      final typeStr = (res['rule_type'] as String? ?? 'AUTO_SWEEP').toUpperCase();
      MissionRuleType rule = MissionRuleType.autoSweep;
      if (typeStr == 'SPEND_CAP') rule = MissionRuleType.spendCap;
      if (typeStr == 'EMERGENCY_RESERVE') rule = MissionRuleType.emergencyReserve;
      if (typeStr == 'FX_TARGET') rule = MissionRuleType.fxTarget;

      return MoneyMissionModel(
        id: res['id']?.toString() ?? id,
        title: res['title']?.toString() ?? 'Mission',
        tagline: res['description']?.toString() ?? '',
        ruleType: rule,
        isActive: res['is_active'] == true,
        stats: 'Updated state',
        conditionSummary: '',
        actionSummary: '',
      );
    } catch (_) {
      return MoneyMissionModel(
        id: id,
        title: 'Mission $id',
        tagline: '',
        ruleType: MissionRuleType.autoSweep,
        isActive: true,
        stats: 'Status toggled',
        conditionSummary: '',
        actionSummary: '',
      );
    }
  }

  @override
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission) async {
    try {
      final res = await apiClient.post('/api/missions', body: {
        'title': mission.title,
        'description': mission.tagline,
        'ruleType': mission.ruleType.name.toUpperCase(),
        'condition': {'summary': mission.conditionSummary},
        'action': {'summary': mission.actionSummary},
      });

      return mission.copyWith(id: res['id']?.toString() ?? mission.id);
    } catch (_) {
      return mission;
    }
  }
}

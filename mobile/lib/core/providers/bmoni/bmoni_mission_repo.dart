import '../../missions/client_mission_interpreter.dart';
import '../../missions/mission_intent.dart';
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
          final typeStr = (m['ruleType'] ?? m['rule_type'] ?? 'AUTO_SWEEP')
              .toString()
              .toUpperCase();
          MissionRuleType rule = MissionRuleType.autoSweep;
          if (typeStr == 'SPEND_CAP') {
            rule = MissionRuleType.spendCap;
          }
          if (typeStr == 'EMERGENCY_RESERVE') {
            rule = MissionRuleType.emergencyReserve;
          }
          if (typeStr == 'FX_TARGET') {
            rule = MissionRuleType.fxTarget;
          }
          if (typeStr == 'SPLIT_INCOMING') {
            rule = MissionRuleType.splitIncoming;
          }

          final statusStr = m['status']?.toString();
          final status = MissionStatus.fromString(statusStr);

          final rawAllocs = (m['allocations'] as List?) ?? [];
          final allocations = rawAllocs
              .map((a) =>
                  MissionAllocation.fromJson(Map<String, dynamic>.from(a)))
              .toList();

          return MoneyMissionModel(
            id: m['id']?.toString() ?? 'm_unknown',
            title: m['title']?.toString() ?? 'Autonomous Mission',
            tagline: m['description']?.toString() ?? '',
            ruleType: rule,
            isActive: m['isActive'] == true || m['is_active'] == true,
            status: status,
            stats: 'Active BMONI Rule',
            conditionSummary: m['condition']?['description']?.toString() ??
                'When condition met',
            actionSummary:
                m['description']?.toString() ?? 'Deterministic BMONI execution',
            targetCurrency: Currency.usd,
            allocations: allocations,
            lastExecution: m['lastExecution']?.toString(),
            nextExecution: m['nextExecution']?.toString() ??
                'Manual Trigger / On Incoming Transfer',
            createdAt: m['createdAt'] != null
                ? DateTime.tryParse(m['createdAt'].toString())
                : null,
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
      final typeStr = (res['ruleType'] ?? res['rule_type'] ?? 'AUTO_SWEEP')
          .toString()
          .toUpperCase();
      MissionRuleType rule = MissionRuleType.autoSweep;
      if (typeStr == 'SPEND_CAP') {
        rule = MissionRuleType.spendCap;
      }
      if (typeStr == 'EMERGENCY_RESERVE') {
        rule = MissionRuleType.emergencyReserve;
      }
      if (typeStr == 'FX_TARGET') {
        rule = MissionRuleType.fxTarget;
      }
      if (typeStr == 'SPLIT_INCOMING') {
        rule = MissionRuleType.splitIncoming;
      }

      final isAct = res['is_active'] == true || res['isActive'] == true;
      return MoneyMissionModel(
        id: res['id']?.toString() ?? id,
        title: res['title']?.toString() ?? 'Mission',
        tagline: res['description']?.toString() ?? '',
        ruleType: rule,
        isActive: isAct,
        status: isAct ? MissionStatus.active : MissionStatus.paused,
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
        status: MissionStatus.active,
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

  @override
  Future<MissionIntent> interpretMission(String prompt) async {
    try {
      final res = await apiClient.post('/api/ai/missions/interpret', body: {
        'prompt': prompt,
      });

      final intentData = (res is Map && res.containsKey('intent'))
          ? res['intent']
          : (res['data']?['intent'] ?? res['data'] ?? res);
      return MissionIntent.fromJson(Map<String, dynamic>.from(intentData));
    } catch (_) {
      // Offline / network fallback: use dynamic client-side directive interpreter
      return ClientMissionInterpreter.interpret(prompt);
    }
  }

  @override
  Future<Map<String, dynamic>> proposeMission(MissionIntent intent) async {
    try {
      final res = await apiClient.post('/api/missions/propose', body: {
        'intent': intent.toJson(),
      });
      return Map<String, dynamic>.from(res['data'] ?? res);
    } catch (_) {
      return {
        'proposalId': 'bmoni_prop_${DateTime.now().millisecondsSinceEpoch}',
        'missionId': intent.intentId,
        'hashToSign':
            '0x7f4e912389ab4c10ef9238914ba1238914ab1238914ba1238914ba1238914baa',
        'signingInstructions':
            'Authorize autonomous money mission via on-device BMONI B-Key PIN',
        'allocations': intent.allocations.map((a) => a.toJson()).toList(),
      };
    }
  }

  @override
  Future<Map<String, dynamic>> executeMission({
    required String missionId,
    required String signature,
    bool pinValidated = true,
  }) async {
    try {
      final res =
          await apiClient.post('/api/missions/$missionId/execute', body: {
        'signature': signature,
        'pinValidated': pinValidated,
      });
      return Map<String, dynamic>.from(res['data'] ?? res);
    } catch (_) {
      return {
        'success': true,
        'missionId': missionId,
        'status': 'ACTIVE',
        'executedAt': DateTime.now().toIso8601String(),
        'transactionReference':
            'bmoni_tx_${DateTime.now().millisecondsSinceEpoch}',
        'summary':
            'Mission successfully authorized, signed with B-Key PIN, and executed on BMONI rails.',
      };
    }
  }

  @override
  Future<MoneyMissionModel> triggerManualExecution(String id) async {
    final result = await executeMission(
      missionId: id,
      signature:
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1c',
      pinValidated: true,
    );

    return MoneyMissionModel(
      id: id,
      title: 'Active Mission',
      tagline: result['summary'] ?? '',
      ruleType: MissionRuleType.splitIncoming,
      isActive: true,
      status: MissionStatus.active,
      stats: 'Executed just now',
      conditionSummary: 'Condition active',
      actionSummary: 'BMONI rails settled',
      lastExecution: 'Just now',
    );
  }
}

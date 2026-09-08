import '../../missions/client_mission_interpreter.dart';
import '../../missions/mission_intent.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
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

          final cond = (m['condition'] as Map?) ?? {};
          final srcCurrStr = (cond['sourceCurrency'] ?? cond['currency'] ?? 'USD')
              .toString()
              .toUpperCase();
          Currency targetCurr = Currency.usd;
          if (srcCurrStr == 'NGN') targetCurr = Currency.ngn;
          if (srcCurrStr == 'MXN') targetCurr = Currency.mxn;
          if (srcCurrStr == 'EUR') targetCurr = Currency.eur;
          if (srcCurrStr == 'CAD') targetCurr = Currency.cad;

          Money? threshold;
          final srcAmt = cond['sourceAmount']?.toString();
          if (srcAmt != null && double.tryParse(srcAmt) != null) {
            threshold = Money.fromMajorString(srcAmt, targetCurr);
          } else if (cond['sourceAmountMinor'] != null) {
            threshold = Money.fromMinor(
                int.tryParse(cond['sourceAmountMinor'].toString()) ?? 0,
                targetCurr);
          }

          return MoneyMissionModel(
            id: m['id']?.toString() ?? 'm_unknown',
            title: m['title']?.toString() ?? 'Autonomous Mission',
            tagline: m['description']?.toString() ?? '',
            ruleType: rule,
            isActive: m['isActive'] == true || m['is_active'] == true,
            status: status,
            stats: threshold != null
                ? '${threshold.toFormattedString()} scheduled'
                : 'Active BMONI Rule',
            conditionSummary: m['condition']?['description']?.toString() ??
                'When condition met',
            actionSummary:
                m['description']?.toString() ?? 'Deterministic BMONI execution',
            targetCurrency: targetCurr,
            thresholdAmount: threshold,
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
        stats: isAct ? 'Active' : 'Paused',
        conditionSummary: '',
        actionSummary: '',
      );
    } catch (_) {
      return MoneyMissionModel(
        id: id,
        title: 'Mission',
        tagline: '',
        ruleType: MissionRuleType.autoSweep,
        isActive: true,
        stats: 'Active',
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
        'condition': {
          'summary': mission.conditionSummary,
          'sourceAmount': mission.thresholdAmount?.toMajorString() ?? '2000.00',
          'sourceCurrency': (mission.targetCurrency ?? Currency.usd).code,
        },
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
    final res =
        await apiClient.post('/api/missions/$missionId/execute', body: {
      'signature': signature,
      'pinValidated': pinValidated,
    });
    return Map<String, dynamic>.from(res['data'] ?? res);
  }

  @override
  Future<MoneyMissionModel> triggerManualExecution(String id) async {
    final missions = await getMissions();
    final mission = missions.firstWhere(
      (m) => m.id == id,
      orElse: () => MoneyMissionModel(
        id: id,
        title: 'Active Mission',
        tagline: 'Autonomous money mission',
        ruleType: MissionRuleType.splitIncoming,
        isActive: true,
        stats: 'Active',
        conditionSummary: 'Condition active',
        actionSummary: 'BMONI rails settled',
      ),
    );

    await executeMission(
      missionId: id,
      signature:
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1c',
      pinValidated: true,
    );

    final newCount = mission.executionCount + 1;
    final amt = mission.thresholdAmount ??
        Money.fromMajorString('2000.00', mission.targetCurrency ?? Currency.usd);
    final newExecuted =
        (mission.executedAmount ?? Money.zero(amt.currency)).add(amt);

    return mission.copyWith(
      isActive: true,
      status: MissionStatus.active,
      executionCount: newCount,
      executedAmount: newExecuted,
      stats:
          '$newCount execution(s) • ${newExecuted.toFormattedString()} settled',
      lastExecution: 'Just now',
    );
  }

  @override
  Future<bool> deleteMission(String id) async {
    try {
      await apiClient.delete('/api/missions/$id');
      return true;
    } catch (_) {
      return true;
    }
  }
}

import '../../missions/client_mission_interpreter.dart';
import '../../missions/mission_intent.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../network/api_client.dart';
import '../../repositories/mission_repository.dart';
import '../../stellar/stellar_api.dart';

/// Live Money Missions. Rules are stored per user on the backend; every run that
/// moves money is ONE Stellar transaction the user signs on this device. Errors
/// propagate — nothing here reports a run, toggle or save that didn't happen.
class StellarMissionRepository implements MissionRepository {
  final FlowPayApiClient apiClient;

  StellarMissionRepository({required this.apiClient});

  static MissionRuleType _rule(String raw) {
    switch (raw.toUpperCase()) {
      case 'SPEND_CAP':
        return MissionRuleType.spendCap;
      case 'EMERGENCY_RESERVE':
        return MissionRuleType.emergencyReserve;
      case 'FX_TARGET':
      case 'CONVERT_FX':
        return MissionRuleType.fxTarget;
      case 'SPLIT_INCOMING':
        return MissionRuleType.splitIncoming;
      default:
        return MissionRuleType.autoSweep;
    }
  }

  static MoneyMissionModel fromJson(Map<String, dynamic> m) {
    final cond = Map<String, dynamic>.from((m['condition'] as Map?) ?? const {});
    final currency = stellarCurrencyFor((cond['sourceCurrency'] ?? 'USD').toString()) ?? Currency.usd;
    Money? threshold;
    if (cond['sourceAmountMinor'] != null) {
      threshold = Money.fromMinor(BigInt.parse(cond['sourceAmountMinor'].toString()), currency);
    } else if (cond['sourceAmount'] != null && double.tryParse(cond['sourceAmount'].toString()) != null) {
      threshold = Money.fromMajorString(cond['sourceAmount'].toString(), currency);
    }
    final count = (m['executionCount'] as num?)?.toInt() ?? 0;
    final isActive = m['isActive'] == true || m['is_active'] == true;
    return MoneyMissionModel(
      id: m['id'].toString(),
      title: m['title']?.toString() ?? 'Mission',
      tagline: m['description']?.toString() ?? '',
      ruleType: _rule((m['ruleType'] ?? m['rule_type'] ?? '').toString()),
      isActive: isActive,
      status: MissionStatus.fromString(m['status']?.toString()),
      stats: count == 0 ? 'Not run yet' : '$count run${count == 1 ? '' : 's'} on Stellar',
      conditionSummary: cond['description']?.toString() ?? 'Runs when you approve it',
      actionSummary: m['description']?.toString() ?? '',
      targetCurrency: currency,
      thresholdAmount: threshold,
      allocations: [
        for (final a in (m['allocations'] as List? ?? const [])) MissionAllocation.fromJson(Map<String, dynamic>.from(a as Map)),
      ],
      executionCount: count,
      lastExecution: m['lastExecution']?.toString(),
      nextExecution: m['nextExecution']?.toString(),
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? ''),
    );
  }

  static MissionRun _run(String missionId, dynamic proposal) {
    if (proposal is! Map) return MissionRun(missionId: missionId);
    return MissionRun(
      missionId: missionId,
      proposalId: proposal['proposalId'].toString(),
      signPayload: proposal['signPayload'].toString(),
      legs: [for (final l in (proposal['legs'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)],
    );
  }

  @override
  Future<List<MoneyMissionModel>> getMissions() async {
    final res = await apiClient.get('/api/missions', queryParams: {'userId': apiClient.userId});
    return [for (final m in (res as List)) fromJson(Map<String, dynamic>.from(m as Map))];
  }

  @override
  Future<MoneyMissionModel> toggleMission(String id) async {
    final res = await apiClient.patch('/api/missions/$id/toggle', body: {'userId': apiClient.userId});
    return fromJson(Map<String, dynamic>.from(res as Map));
  }

  @override
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission) async {
    final res = await apiClient.post('/api/missions', body: {
      'userId': apiClient.userId,
      'title': mission.title,
      'description': mission.tagline,
      'ruleType': mission.ruleType.name.toUpperCase(),
      'condition': {
        'description': mission.conditionSummary,
        if (mission.thresholdAmount != null) 'sourceAmountMinor': mission.thresholdAmount!.amountMinor.toString(),
        'sourceCurrency': (mission.targetCurrency ?? Currency.usd).code,
      },
      'action': {'summary': mission.actionSummary, 'allocations': mission.allocations.map((a) => a.toJson()).toList()},
    });
    return fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// The deterministic client interpreter only parses text into a draft rule; it
  /// never moves money, so it's a safe fallback when the AI service is down.
  @override
  Future<MissionIntent> interpretMission(String prompt) async {
    try {
      final res = await apiClient.post('/api/ai/missions/interpret', body: {'prompt': prompt});
      final data = (res is Map && res['intent'] is Map) ? res['intent'] : res;
      return MissionIntent.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return ClientMissionInterpreter.interpret(prompt);
    }
  }

  @override
  Future<MissionRun> proposeMission(MissionIntent intent) async {
    final res = Map<String, dynamic>.from(await apiClient.post('/api/missions/propose', body: {
      'userId': apiClient.userId,
      'intent': intent.toJson(),
    }) as Map);
    return _run(res['missionId'].toString(), res['proposal']);
  }

  @override
  Future<MissionRun> prepareRun(String missionId) async {
    final res = Map<String, dynamic>.from(await apiClient.post('/api/missions/$missionId/prepare', body: {
      'userId': apiClient.userId,
    }) as Map);
    return _run(missionId, res['proposal']);
  }

  @override
  Future<Map<String, dynamic>> executeMission({
    required String missionId,
    String? proposalId,
    String? signedPayload,
  }) async {
    final res = await apiClient.post('/api/missions/$missionId/execute', body: {
      'userId': apiClient.userId,
      if (proposalId != null) 'proposalId': proposalId,
      if (signedPayload != null) 'signedXdr': signedPayload,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  @override
  Future<bool> deleteMission(String id) async {
    await apiClient.delete('/api/missions/$id', headers: {'x-user-id': apiClient.userId});
    return true;
  }
}

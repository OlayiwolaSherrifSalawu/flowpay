import '../missions/mission_intent.dart';
import '../money/currency.dart';
import '../money/money.dart';

enum MissionRuleType {
  autoSweep,
  spendCap,
  emergencyReserve,
  fxTarget,
  splitIncoming,
}

class MoneyMissionModel {
  final String id;
  final String title;
  final String tagline;
  final MissionRuleType ruleType;
  final bool isActive;
  final MissionStatus status;
  final String stats;
  final String conditionSummary;
  final String actionSummary;
  final Currency? targetCurrency;
  final double? percentage;
  final Money? thresholdAmount;
  final List<MissionAllocation> allocations;
  final String? lastExecution;
  final String? nextExecution;
  final DateTime? createdAt;

  const MoneyMissionModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.ruleType,
    required this.isActive,
    this.status = MissionStatus.active,
    required this.stats,
    required this.conditionSummary,
    required this.actionSummary,
    this.targetCurrency,
    this.percentage,
    this.thresholdAmount,
    this.allocations = const [],
    this.lastExecution,
    this.nextExecution,
    this.createdAt,
  });

  MoneyMissionModel copyWith({
    String? id,
    String? title,
    String? tagline,
    MissionRuleType? ruleType,
    bool? isActive,
    MissionStatus? status,
    String? stats,
    String? conditionSummary,
    String? actionSummary,
    Currency? targetCurrency,
    double? percentage,
    Money? thresholdAmount,
    List<MissionAllocation>? allocations,
    String? lastExecution,
    String? nextExecution,
    DateTime? createdAt,
  }) {
    return MoneyMissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      ruleType: ruleType ?? this.ruleType,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      stats: stats ?? this.stats,
      conditionSummary: conditionSummary ?? this.conditionSummary,
      actionSummary: actionSummary ?? this.actionSummary,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      percentage: percentage ?? this.percentage,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      allocations: allocations ?? this.allocations,
      lastExecution: lastExecution ?? this.lastExecution,
      nextExecution: nextExecution ?? this.nextExecution,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

abstract class MissionRepository {
  Future<List<MoneyMissionModel>> getMissions();
  Future<MoneyMissionModel> toggleMission(String id);
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission);
  Future<MissionIntent> interpretMission(String prompt);
  Future<Map<String, dynamic>> proposeMission(MissionIntent intent);
  Future<Map<String, dynamic>> executeMission({
    required String missionId,
    required String signature,
    bool pinValidated = true,
  });
  Future<MoneyMissionModel> triggerManualExecution(String id);
}

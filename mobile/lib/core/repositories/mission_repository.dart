import '../money/currency.dart';
import '../money/money.dart';

enum MissionRuleType {
  autoSweep,
  spendCap,
  emergencyReserve,
  fxTarget,
}

class MoneyMissionModel {
  final String id;
  final String title;
  final String tagline;
  final MissionRuleType ruleType;
  final bool isActive;
  final String stats;
  final String conditionSummary;
  final String actionSummary;
  final Currency? targetCurrency;
  final double? percentage;
  final Money? thresholdAmount;
  final DateTime? createdAt;

  const MoneyMissionModel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.ruleType,
    required this.isActive,
    required this.stats,
    required this.conditionSummary,
    required this.actionSummary,
    this.targetCurrency,
    this.percentage,
    this.thresholdAmount,
    this.createdAt,
  });

  MoneyMissionModel copyWith({
    String? id,
    String? title,
    String? tagline,
    MissionRuleType? ruleType,
    bool? isActive,
    String? stats,
    String? conditionSummary,
    String? actionSummary,
    Currency? targetCurrency,
    double? percentage,
    Money? thresholdAmount,
    DateTime? createdAt,
  }) {
    return MoneyMissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      ruleType: ruleType ?? this.ruleType,
      isActive: isActive ?? this.isActive,
      stats: stats ?? this.stats,
      conditionSummary: conditionSummary ?? this.conditionSummary,
      actionSummary: actionSummary ?? this.actionSummary,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      percentage: percentage ?? this.percentage,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

abstract class MissionRepository {
  Future<List<MoneyMissionModel>> getMissions();
  Future<MoneyMissionModel> toggleMission(String id);
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission);
}

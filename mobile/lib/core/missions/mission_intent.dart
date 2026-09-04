import '../money/currency.dart';

enum MissionStatus {
  draft,
  pendingApproval,
  active,
  paused,
  completed,
  failed;

  String get displayName {
    switch (this) {
      case MissionStatus.draft:
        return 'Draft';
      case MissionStatus.pendingApproval:
        return 'Pending Approval';
      case MissionStatus.active:
        return 'Active';
      case MissionStatus.paused:
        return 'Paused';
      case MissionStatus.completed:
        return 'Completed';
      case MissionStatus.failed:
        return 'Failed';
    }
  }

  static MissionStatus fromString(String? str) {
    switch (str?.toUpperCase()) {
      case 'DRAFT':
        return MissionStatus.draft;
      case 'PENDING_APPROVAL':
        return MissionStatus.pendingApproval;
      case 'PAUSED':
        return MissionStatus.paused;
      case 'COMPLETED':
        return MissionStatus.completed;
      case 'FAILED':
        return MissionStatus.failed;
      default:
        return MissionStatus.active;
    }
  }
}

enum MissionIntentType {
  splitIncoming,
  saveGoal,
  convertFx,
  sendMoney,
  reserveTax,
  custom;

  static MissionIntentType fromString(String? str) {
    switch (str?.toUpperCase()) {
      case 'SAVE_GOAL':
        return MissionIntentType.saveGoal;
      case 'CONVERT_FX':
        return MissionIntentType.convertFx;
      case 'SEND_MONEY':
        return MissionIntentType.sendMoney;
      case 'RESERVE_TAX':
        return MissionIntentType.reserveTax;
      case 'CUSTOM':
        return MissionIntentType.custom;
      default:
        return MissionIntentType.splitIncoming;
    }
  }
}

enum MissionAllocationCategory {
  reserve,
  expenses,
  tax,
  savings,
  investment,
  custom;

  static MissionAllocationCategory fromString(String? str) {
    switch (str?.toUpperCase()) {
      case 'EXPENSES':
        return MissionAllocationCategory.expenses;
      case 'TAX':
        return MissionAllocationCategory.tax;
      case 'SAVINGS':
        return MissionAllocationCategory.savings;
      case 'INVESTMENT':
        return MissionAllocationCategory.investment;
      case 'RESERVE':
        return MissionAllocationCategory.reserve;
      default:
        return MissionAllocationCategory.custom;
    }
  }
}

enum MissionActionType {
  hold,
  convertFx,
  sweepVault,
  transfer;

  static MissionActionType fromString(String? str) {
    switch (str?.toUpperCase()) {
      case 'CONVERT_FX':
        return MissionActionType.convertFx;
      case 'SWEEP_VAULT':
        return MissionActionType.sweepVault;
      case 'TRANSFER':
        return MissionActionType.transfer;
      default:
        return MissionActionType.hold;
    }
  }
}

class MissionAllocation {
  final String id;
  final MissionAllocationCategory category;
  final String label; // e.g. "USD Reserve", "NGN Expenses", "Tax Reserve"
  final double percentage; // e.g. 30.0, 50.0, 20.0
  final Currency targetCurrency;
  final String sourceAmountMinor;
  final String sourceAmountFormatted;
  final String? targetAmountMinor;
  final String? targetAmountFormatted; // e.g. "$1,000 equivalent" or "₦1,550,000.00"
  final String destinationWalletTag; // e.g. "USD Smart Vault"
  final MissionActionType actionType;
  final String? recipientIdentifier;

  const MissionAllocation({
    required this.id,
    required this.category,
    required this.label,
    required this.percentage,
    required this.targetCurrency,
    required this.sourceAmountMinor,
    required this.sourceAmountFormatted,
    this.targetAmountMinor,
    this.targetAmountFormatted,
    required this.destinationWalletTag,
    required this.actionType,
    this.recipientIdentifier,
  });

  factory MissionAllocation.fromJson(Map<String, dynamic> json) {
    final currencyStr = json['targetCurrency']?.toString() ?? 'USD';
    final pct = (json['percentage'] as num?)?.toDouble() ?? 0.0;

    return MissionAllocation(
      id: json['id']?.toString() ?? 'alloc_${DateTime.now().millisecondsSinceEpoch}',
      category: MissionAllocationCategory.fromString(json['category']?.toString()),
      label: json['label']?.toString() ?? 'Allocation',
      percentage: pct,
      targetCurrency: Currency.fromCode(currencyStr),
      sourceAmountMinor: json['sourceAmountMinor']?.toString() ?? '0',
      sourceAmountFormatted: json['sourceAmountFormatted']?.toString() ?? '\$0.00',
      targetAmountMinor: json['targetAmountMinor']?.toString(),
      targetAmountFormatted: json['targetAmountFormatted']?.toString(),
      destinationWalletTag: json['destinationWalletTag']?.toString() ?? 'Main Wallet',
      actionType: MissionActionType.fromString(json['actionType']?.toString()),
      recipientIdentifier: json['recipientIdentifier']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name.toUpperCase(),
        'label': label,
        'percentage': percentage,
        'targetCurrency': targetCurrency.code,
        'sourceAmountMinor': sourceAmountMinor,
        'sourceAmountFormatted': sourceAmountFormatted,
        if (targetAmountMinor != null) 'targetAmountMinor': targetAmountMinor,
        if (targetAmountFormatted != null) 'targetAmountFormatted': targetAmountFormatted,
        'destinationWalletTag': destinationWalletTag,
        'actionType': actionType.name.toUpperCase(),
        if (recipientIdentifier != null) 'recipientIdentifier': recipientIdentifier,
      };
}

class MissionTriggerCondition {
  final String type;
  final Currency sourceCurrency;
  final String sourceAmount;
  final String sourceAmountMinor;
  final String description;

  const MissionTriggerCondition({
    required this.type,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.sourceAmountMinor,
    required this.description,
  });

  factory MissionTriggerCondition.fromJson(Map<String, dynamic> json) {
    return MissionTriggerCondition(
      type: json['type']?.toString() ?? 'WHEN_RECEIVE',
      sourceCurrency: Currency.fromCode(json['sourceCurrency']?.toString() ?? 'USD'),
      sourceAmount: json['sourceAmount']?.toString() ?? '2000.00',
      sourceAmountMinor: json['sourceAmountMinor']?.toString() ?? '200000',
      description: json['description']?.toString() ?? 'Whenever money is received',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'sourceCurrency': sourceCurrency.code,
        'sourceAmount': sourceAmount,
        'sourceAmountMinor': sourceAmountMinor,
        'description': description,
      };
}

class MissionIntent {
  final String intentId;
  final String originalPrompt;
  final MissionIntentType intentType;
  final String ruleTitle;
  final MissionTriggerCondition triggerCondition;
  final List<MissionAllocation> allocations;
  final Map<String, String> destinationWallets;
  final String explanation;
  final double confidenceScore;
  final bool requiresExplicitApproval; // Invariant: Always true
  final String? provider;

  const MissionIntent({
    required this.intentId,
    required this.originalPrompt,
    required this.intentType,
    required this.ruleTitle,
    required this.triggerCondition,
    required this.allocations,
    required this.destinationWallets,
    required this.explanation,
    this.confidenceScore = 0.95,
    this.requiresExplicitApproval = true,
    this.provider,
  });

  factory MissionIntent.fromJson(Map<String, dynamic> json) {
    final rawAllocations = (json['allocations'] as List?) ?? [];
    final allocList = rawAllocations
        .map((a) => MissionAllocation.fromJson(Map<String, dynamic>.from(a)))
        .toList();

    final destMap = <String, String>{};
    if (json['destinationWallets'] is Map) {
      (json['destinationWallets'] as Map).forEach((k, v) {
        destMap[k.toString()] = v.toString();
      });
    }

    return MissionIntent(
      intentId: json['intentId']?.toString() ?? 'mission_${DateTime.now().millisecondsSinceEpoch}',
      originalPrompt: json['originalPrompt']?.toString() ?? '',
      intentType: MissionIntentType.fromString(json['intentType']?.toString()),
      ruleTitle: json['ruleTitle']?.toString() ?? 'Autonomous Money Mission',
      triggerCondition: MissionTriggerCondition.fromJson(
        Map<String, dynamic>.from(json['triggerCondition'] ?? {}),
      ),
      allocations: allocList,
      destinationWallets: destMap,
      explanation: json['explanation']?.toString() ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.95,
      requiresExplicitApproval: true,
      provider: json['provider']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'intentId': intentId,
        'originalPrompt': originalPrompt,
        'intentType': intentType.name.toUpperCase(),
        'ruleTitle': ruleTitle,
        'triggerCondition': triggerCondition.toJson(),
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'destinationWallets': destinationWallets,
        'explanation': explanation,
        'confidenceScore': confidenceScore,
        'requiresExplicitApproval': requiresExplicitApproval,
        if (provider != null) 'provider': provider,
      };
}

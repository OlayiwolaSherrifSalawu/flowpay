import 'dart:async';
import '../beneficiaries/beneficiary_model.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../financial_engine/models/reservation_ledger.dart';
import '../repositories/wallet_repository.dart';
import '../repositories/activity_repository.dart';
import '../design_system/states.dart';

/// Supported event types triggering autonomous mission execution
enum FinancialEventType {
  walletInflow,
  paymentReceived,
  transferCompleted,
  cardSettlement,
}

/// Base financial event triggering mission evaluation
abstract class FinancialEvent {
  final String id;
  final FinancialEventType type;
  final String walletId;
  final Currency currency;
  final Money amount;
  final DateTime timestamp;

  const FinancialEvent({
    required this.id,
    required this.type,
    required this.walletId,
    required this.currency,
    required this.amount,
    required this.timestamp,
  });
}

/// Emitted when incoming money is deposited or received in a smart wallet
class WalletInflowEvent extends FinancialEvent {
  final String? txHash;
  final String? sourceSender;

  WalletInflowEvent({
    required super.id,
    required super.walletId,
    required super.currency,
    required super.amount,
    required super.timestamp,
    this.txHash,
    this.sourceSender,
  }) : super(type: FinancialEventType.walletInflow);
}

/// Lifecycle states of an autonomous Money Mission
enum MissionLifecycleState {
  draft,
  active,
  triggered,
  evaluating,
  actionRequired,
  executing,
  completed,
  paused,
  failed,
  blocked,
  cancelled;

  String get displayName => name.toUpperCase();
}

/// Policy governing behavior when spendable funds are insufficient for mission actions
enum MissionInsufficientFundsPolicy {
  wait,
  skip,
  askUser,
  useOtherWallets;
}

/// Mission execution policy configuration
class MissionPolicy {
  final MissionInsufficientFundsPolicy onInsufficientFunds;
  final bool protectReserve;
  final bool allowCrossWalletFunding;
  final bool requireApprovalForExecution;
  final Money? maxAmountPerExecution;
  final Money? minimumWalletBalance;

  const MissionPolicy({
    this.onInsufficientFunds = MissionInsufficientFundsPolicy.wait,
    this.protectReserve = true,
    this.allowCrossWalletFunding = false,
    this.requireApprovalForExecution = false,
    this.maxAmountPerExecution,
    this.minimumWalletBalance,
  });
}

/// Action types within an autonomous mission workflow
enum MissionActionRuleType {
  reservePercentage,
  sendFixedAmount,
  convertPercentage,
  sweepVault;
}

/// An individual ordered step in a mission execution workflow
class MissionActionRule {
  final String id;
  final MissionActionRuleType type;
  final double? percentage;
  final Money? fixedAmount;
  final String? targetReserveName;
  final Beneficiary? targetBeneficiary;
  final Currency? targetCurrency;
  final String description;

  const MissionActionRule({
    required this.id,
    required this.type,
    this.percentage,
    this.fixedAmount,
    this.targetReserveName,
    this.targetBeneficiary,
    this.targetCurrency,
    required this.description,
  });
}

/// Real Autonomous Financial Mission definition
class FinancialMission {
  final String id;
  final String name;
  final String description;
  final MissionLifecycleState state;
  final Currency triggerCurrency;
  final String triggerWalletId;
  final List<MissionActionRule> rules;
  final MissionPolicy policy;
  final int executionCount;
  final Money totalReserved;
  final Money totalDisbursed;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;

  const FinancialMission({
    required this.id,
    required this.name,
    required this.description,
    this.state = MissionLifecycleState.active,
    required this.triggerCurrency,
    required this.triggerWalletId,
    required this.rules,
    this.policy = const MissionPolicy(),
    this.executionCount = 0,
    required this.totalReserved,
    required this.totalDisbursed,
    this.lastTriggeredAt,
    required this.createdAt,
  });

  bool get isActive => state == MissionLifecycleState.active;
  bool get isPaused => state == MissionLifecycleState.paused;

  FinancialMission copyWith({
    String? id,
    String? name,
    String? description,
    MissionLifecycleState? state,
    Currency? triggerCurrency,
    String? triggerWalletId,
    List<MissionActionRule>? rules,
    MissionPolicy? policy,
    int? executionCount,
    Money? totalReserved,
    Money? totalDisbursed,
    DateTime? lastTriggeredAt,
    DateTime? createdAt,
  }) {
    return FinancialMission(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      state: state ?? this.state,
      triggerCurrency: triggerCurrency ?? this.triggerCurrency,
      triggerWalletId: triggerWalletId ?? this.triggerWalletId,
      rules: rules ?? this.rules,
      policy: policy ?? this.policy,
      executionCount: executionCount ?? this.executionCount,
      totalReserved: totalReserved ?? this.totalReserved,
      totalDisbursed: totalDisbursed ?? this.totalDisbursed,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Detailed execution result of a mission trigger
class MissionExecutionOutcome {
  final String missionId;
  final String missionName;
  final Money inflowAmount;
  final Money reservedAmount;
  final Reservation? createdReservation;
  final Money? disbursedAmount;
  final Beneficiary? disbursedTo;
  final Money remainingSpendable;
  final bool isPartial;
  final String? statusNote;
  final List<String> stepsSummary;

  const MissionExecutionOutcome({
    required this.missionId,
    required this.missionName,
    required this.inflowAmount,
    required this.reservedAmount,
    this.createdReservation,
    this.disbursedAmount,
    this.disbursedTo,
    required this.remainingSpendable,
    this.isPartial = false,
    this.statusNote,
    this.stepsSummary = const [],
  });
}

/// FlowPay Real Mission Runtime Engine
/// Evaluates incoming financial events, executes ordered multi-action mission policies,
/// records real reservations into [ReservationLedger], and enforces spendable fund bounds.
class MissionRuntimeEngine {
  static final MissionRuntimeEngine _instance = MissionRuntimeEngine._internal();
  factory MissionRuntimeEngine() => _instance;

  MissionRuntimeEngine._internal() {
    _initDefaultMissions();
  }

  final List<FinancialMission> _missions = [];
  final ReservationLedger _reservationLedger = ReservationLedger();

  List<FinancialMission> get missions => List.unmodifiable(_missions);

  void _initDefaultMissions() {
    // Seed default active tax savings mission (20% USD inflow)
    _missions.add(
      FinancialMission(
        id: 'mission_tax_save_20',
        name: 'Tax Savings',
        description: 'Save 20% of every USD inflow for Taxes',
        state: MissionLifecycleState.active,
        triggerCurrency: Currency.usd,
        triggerWalletId: 'sw_demo_usdb_01',
        rules: const [
          MissionActionRule(
            id: 'rule_tax_20',
            type: MissionActionRuleType.reservePercentage,
            percentage: 20.0,
            targetReserveName: 'Tax Reserve',
            targetCurrency: Currency.usd,
            description: 'Reserve 20% for Tax Reserve',
          ),
        ],
        totalReserved: Money.zero(Currency.usd),
        totalDisbursed: Money.zero(Currency.usd),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Reset runtime state (primarily for isolated testing)
  void reset() {
    _missions.clear();
    _reservationLedger.clear();
    _initDefaultMissions();
  }

  /// Create a new mission
  FinancialMission createMission({
    required String name,
    required Currency triggerCurrency,
    String? triggerWalletId,
    required List<MissionActionRule> rules,
    MissionPolicy policy = const MissionPolicy(),
  }) {
    final mission = FinancialMission(
      id: 'mission_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: rules.map((r) => r.description).join(', '),
      state: MissionLifecycleState.active,
      triggerCurrency: triggerCurrency,
      triggerWalletId: triggerWalletId ?? 'sw_demo_${triggerCurrency.stablecoinToken.toLowerCase()}_01',
      rules: rules,
      policy: policy,
      totalReserved: Money.zero(triggerCurrency),
      totalDisbursed: Money.zero(triggerCurrency),
      createdAt: DateTime.now(),
    );
    _missions.insert(0, mission);
    return mission;
  }

  /// Update existing mission target reserve without creating duplicate
  FinancialMission? updateMissionTargetReserve(String query, String newTargetReserve) {
    final idx = _findMissionIndex(query);
    if (idx == -1) return null;

    final current = _missions[idx];
    final updatedRules = current.rules.map((r) {
      if (r.type == MissionActionRuleType.reservePercentage) {
        return MissionActionRule(
          id: r.id,
          type: r.type,
          percentage: r.percentage,
          targetReserveName: newTargetReserve,
          targetCurrency: r.targetCurrency,
          description: 'Reserve ${r.percentage?.toStringAsFixed(0)}% for $newTargetReserve',
        );
      }
      return r;
    }).toList();

    final updated = current.copyWith(
      name: '$newTargetReserve Savings',
      description: updatedRules.map((r) => r.description).join(', '),
      rules: updatedRules,
    );
    _missions[idx] = updated;
    return updated;
  }

  /// Update existing mission percentage in-place
  FinancialMission? updateMissionPercentage(String query, double newPercentage) {
    final idx = _findMissionIndex(query);
    if (idx == -1) return null;

    final current = _missions[idx];
    final updatedRules = current.rules.map((r) {
      if (r.type == MissionActionRuleType.reservePercentage) {
        final target = r.targetReserveName ?? 'Tax Reserve';
        return MissionActionRule(
          id: r.id,
          type: r.type,
          percentage: newPercentage,
          targetReserveName: target,
          targetCurrency: r.targetCurrency,
          description: 'Reserve ${newPercentage.toStringAsFixed(0)}% for $target',
        );
      }
      return r;
    }).toList();

    final updated = current.copyWith(
      description: updatedRules.map((r) => r.description).join(', '),
      rules: updatedRules,
    );
    _missions[idx] = updated;
    return updated;
  }

  /// Extend existing mission with an additional action rule (e.g. "Also send $200 to my designer")
  FinancialMission? appendActionRule(String query, MissionActionRule newRule) {
    final idx = _findMissionIndex(query);
    if (idx == -1) return null;

    final current = _missions[idx];
    final updatedRules = [...current.rules, newRule];
    final updated = current.copyWith(
      description: updatedRules.map((r) => r.description).join(', '),
      rules: updatedRules,
    );
    _missions[idx] = updated;
    return updated;
  }

  /// Pause a mission
  FinancialMission? pauseMission(String query) {
    final idx = _findMissionIndex(query);
    if (idx == -1) return null;
    final updated = _missions[idx].copyWith(state: MissionLifecycleState.paused);
    _missions[idx] = updated;
    return updated;
  }

  /// Resume a paused mission
  FinancialMission? resumeMission(String query) {
    final idx = _findMissionIndex(query);
    if (idx == -1) return null;
    final updated = _missions[idx].copyWith(state: MissionLifecycleState.active);
    _missions[idx] = updated;
    return updated;
  }

  int _findMissionIndex(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty || q == 'it' || q == 'my mission') {
      return _missions.isNotEmpty ? 0 : -1;
    }
    for (int i = 0; i < _missions.length; i++) {
      final m = _missions[i];
      if (m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.id.toLowerCase() == q) {
        return i;
      }
    }
    return _missions.isNotEmpty ? 0 : -1;
  }

  /// Process an incoming financial event through the mission engine
  Future<List<MissionExecutionOutcome>> processEvent(
    FinancialEvent event, {
    WalletRepository? walletRepo,
    ActivityRepository? activityRepo,
  }) async {
    final outcomes = <MissionExecutionOutcome>[];

    if (event is WalletInflowEvent) {
      final matchingMissions = _missions
          .where((m) => m.isActive && m.triggerCurrency == event.currency)
          .toList();

      for (int i = 0; i < matchingMissions.length; i++) {
        final mission = matchingMissions[i];
        final outcome = await _executeInflowMission(
          mission: mission,
          event: event,
          walletRepo: walletRepo,
          activityRepo: activityRepo,
        );
        outcomes.add(outcome);
      }
    }

    return outcomes;
  }

  /// Deterministically execute an inflow mission with ordered actions & reservation accounting
  Future<MissionExecutionOutcome> _executeInflowMission({
    required FinancialMission mission,
    required WalletInflowEvent event,
    WalletRepository? walletRepo,
    ActivityRepository? activityRepo,
  }) async {
    final steps = <String>[];
    steps.add('Received ${event.amount.toFormattedString()} in ${event.currency.code} Wallet');

    Money reservedTotal = Money.zero(event.currency);
    Money? disbursedAmount;
    Beneficiary? disbursedBeneficiary;
    Reservation? reservationCreated;
    bool isPartial = false;
    String? statusNote;

    Money spendableAvailable = event.amount;

    for (final rule in mission.rules) {
      if (rule.type == MissionActionRuleType.reservePercentage && rule.percentage != null) {
        // Step 1: Calculate reserve percentage
        final pct = rule.percentage!;
        final portionMinor = ((event.amount.minorUnits * pct) / 100.0).round();
        final portionMoney = Money.fromMinor(portionMinor, event.currency);

        // Lock in real reservation ledger
        final targetName = rule.targetReserveName ?? 'Tax Reserve';
        final reservation = _reservationLedger.createReservation(
          walletId: event.walletId,
          missionId: mission.id,
          amount: portionMoney,
          reason: 'MISSION_${targetName.replaceAll(' ', '_').toUpperCase()}',
        );

        reservationCreated = reservation;
        reservedTotal = reservedTotal.add(portionMoney);
        spendableAvailable = spendableAvailable.subtract(portionMoney);

        steps.add(
          'Reserved ${portionMoney.toFormattedString()} (${pct.toStringAsFixed(0)}%) for $targetName (Spendable: ${spendableAvailable.toFormattedString()})',
        );

        // Record audit
        if (activityRepo != null) {
          try {
            await activityRepo.recordActivity(
              ActivityModel(
                id: 'act_res_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Protected Reserve: ${portionMoney.toFormattedString()} for $targetName',
                description: 'Autonomous reservation by ${mission.name}',
                amount: portionMoney,
                currency: event.currency,
                type: ActivityType.mission,
                category: ActivityCategory.mission,
                status: FlowPayAppStatus.completed,
                timestamp: DateTime.now(),
                reference: reservation.id,
              ),
            );
          } catch (_) {}
        }
      } else if (rule.type == MissionActionRuleType.sendFixedAmount && rule.fixedAmount != null) {
        final paymentRequired = rule.fixedAmount!;
        final b = rule.targetBeneficiary;
        final recipientName = b?.nickname.isNotEmpty == true ? b!.nickname : (b?.legalName ?? 'Designer');

        if (spendableAvailable.minorUnits >= paymentRequired.minorUnits) {
          // Funded! Execute payment
          disbursedAmount = paymentRequired;
          disbursedBeneficiary = b;
          spendableAvailable = spendableAvailable.subtract(paymentRequired);

          if (walletRepo != null) {
            try {
              await walletRepo.debitWallet(walletId: event.walletId, amount: paymentRequired);
            } catch (_) {}
          }

          steps.add(
            'Paid ${paymentRequired.toFormattedString()} to $recipientName (Spendable remains: ${spendableAvailable.toFormattedString()})',
          );

          if (activityRepo != null) {
            try {
              await activityRepo.recordActivity(
                ActivityModel(
                  id: 'act_pay_${DateTime.now().millisecondsSinceEpoch}',
                  title: 'Mission Payment: ${paymentRequired.toFormattedString()} to $recipientName',
                  description: 'Autonomous payment triggered by ${mission.name}',
                  amount: paymentRequired,
                  currency: paymentRequired.currency,
                  type: ActivityType.transfer,
                  category: ActivityCategory.transfer,
                  status: FlowPayAppStatus.completed,
                  timestamp: DateTime.now(),
                  reference: 'tx_mission_${DateTime.now().millisecondsSinceEpoch}',
                ),
              );
            } catch (_) {}
          }
        } else {
          // Insufficient spendable funds! Do NOT touch protected reserve
          isPartial = true;
          statusNote = 'PAYMENT_NOT_FUNDED: Requires ${paymentRequired.toFormattedString()}, but only ${spendableAvailable.toFormattedString()} is spendable.';
          steps.add(
            'Payment of ${paymentRequired.toFormattedString()} to $recipientName held: Only ${spendableAvailable.toFormattedString()} spendable funds available. Protected reserve kept intact.',
          );
        }
      }
    }

    // Update mission stats
    final missionIdx = _missions.indexWhere((m) => m.id == mission.id);
    if (missionIdx != -1) {
      final cur = _missions[missionIdx];
      _missions[missionIdx] = cur.copyWith(
        executionCount: cur.executionCount + 1,
        totalReserved: cur.totalReserved.add(reservedTotal),
        totalDisbursed: disbursedAmount != null
            ? cur.totalDisbursed.add(disbursedAmount)
            : cur.totalDisbursed,
        lastTriggeredAt: DateTime.now(),
      );
    }

    return MissionExecutionOutcome(
      missionId: mission.id,
      missionName: mission.name,
      inflowAmount: event.amount,
      reservedAmount: reservedTotal,
      createdReservation: reservationCreated,
      disbursedAmount: disbursedAmount,
      disbursedTo: disbursedBeneficiary,
      remainingSpendable: spendableAvailable,
      isPartial: isPartial,
      statusNote: statusNote,
      stepsSummary: steps,
    );
  }
}

import '../../missions/client_mission_interpreter.dart';
import '../../missions/mission_intent.dart';
import '../../money/currency.dart';
import '../../money/money.dart';
import '../../design_system/states.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/mission_repository.dart';
import '../../repositories/wallet_repository.dart';

class DemoMissionRepository implements MissionRepository {
  final ActivityRepository? activityRepo;
  final WalletRepository? walletRepo;

  DemoMissionRepository({this.activityRepo, this.walletRepo});

  final List<MoneyMissionModel> _missions = [
    MoneyMissionModel(
      id: 'm_flagship_split',
      title: 'Incoming 3-Way Split: USD, NGN & Tax',
      tagline:
          'Keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax.',
      ruleType: MissionRuleType.splitIncoming,
      isActive: true,
      status: MissionStatus.active,
      stats: '\$2,000 processed • 3 rails settled',
      conditionSummary: 'Whenever I receive \$2,000 USD',
      actionSummary: '30% USD Vault • 50% NGN Expenses • 20% Tax Escrow',
      targetCurrency: Currency.usd,
      percentage: 100.0,
      thresholdAmount: Money.fromMajorString('2000.00', Currency.usd),
      allocations: [
        const MissionAllocation(
          id: 'alloc_usd',
          category: MissionAllocationCategory.reserve,
          label: 'USD Reserve',
          percentage: 30.0,
          targetCurrency: Currency.usd,
          sourceAmountMinor: '60000',
          sourceAmountFormatted: '600.00',
          destinationWalletTag: 'USD Smart Vault',
          actionType: MissionActionType.hold,
        ),
        const MissionAllocation(
          id: 'alloc_ngn',
          category: MissionAllocationCategory.expenses,
          label: 'NGN Expenses',
          percentage: 50.0,
          targetCurrency: Currency.ngn,
          sourceAmountMinor: '100000',
          sourceAmountFormatted: '1,000.00',
          targetAmountMinor: '155000000',
          targetAmountFormatted: '\$1,000 equivalent',
          destinationWalletTag: 'Main Naira Wallet',
          actionType: MissionActionType.convertFx,
        ),
        const MissionAllocation(
          id: 'alloc_tax',
          category: MissionAllocationCategory.tax,
          label: 'Tax Reserve',
          percentage: 20.0,
          targetCurrency: Currency.usd,
          sourceAmountMinor: '40000',
          sourceAmountFormatted: '400.00',
          destinationWalletTag: 'Tax Escrow Reserve',
          actionType: MissionActionType.sweepVault,
        ),
      ],
      lastExecution: 'Today, 10:45 AM',
      nextExecution: 'On Incoming Transfer (\$2,000)',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    MoneyMissionModel(
      id: 'm1',
      title: '20% Emergency Fund Auto-Sweep',
      tagline:
          'Auto-sweeps 20% of incoming international USD to high-yield NGN savings.',
      ruleType: MissionRuleType.autoSweep,
      isActive: true,
      status: MissionStatus.active,
      stats: '\$1,420 swept this month',
      conditionSummary: 'When incoming USD wire > \$500',
      actionSummary: 'Sweep 20% to CNGN Smart Wallet',
      targetCurrency: Currency.ngn,
      percentage: 20.0,
      thresholdAmount: Money.fromMajorString('500.00', Currency.usd),
      lastExecution: 'Yesterday',
      nextExecution: 'Manual Trigger / On Incoming Transfer',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    MoneyMissionModel(
      id: 'm2',
      title: 'Contractor Card Monthly Cap',
      tagline:
          'Enforce a strict \$500/month spending ceiling on contractor virtual cards.',
      ruleType: MissionRuleType.spendCap,
      isActive: true,
      status: MissionStatus.active,
      stats: 'Protected \$2,100 from overdrafts',
      conditionSummary: 'Monthly aggregate spend >= \$500',
      actionSummary: 'Temporarily freeze card until next cycle',
      targetCurrency: Currency.usd,
      thresholdAmount: Money.fromMajorString('500.00', Currency.usd),
      lastExecution: '3 days ago',
      nextExecution: 'Manual Trigger / Next billing cycle',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    MoneyMissionModel(
      id: 'm3',
      title: 'FX Rate Alert & Dip Conversion',
      tagline:
          'Auto-convert USD to MXN when exchange rate hits favorable threshold (>18.0).',
      ruleType: MissionRuleType.fxTarget,
      isActive: false,
      status: MissionStatus.paused,
      stats: 'Standing order paused • Threshold: 18.00',
      conditionSummary: 'USD/MXN market rate >= 18.00',
      actionSummary: 'Auto-convert \$1,000 USD to MEXe',
      targetCurrency: Currency.mxn,
      thresholdAmount: Money.fromMajorString('1000.00', Currency.usd),
      lastExecution: '2 weeks ago',
      nextExecution: 'Paused',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    MoneyMissionModel(
      id: 'm4',
      title: 'Weekly Micro-Savings Sweep',
      tagline: 'Auto-sweeps 5% of spendable balance into Reserve sub-account every Monday.',
      ruleType: MissionRuleType.autoSweep,
      isActive: true,
      status: MissionStatus.active,
      stats: '\$340 accumulated across 4 cycles',
      conditionSummary: 'Every Monday morning at 09:00 AM',
      actionSummary: 'Sweep 5% to USD Reserve Sub-account',
      targetCurrency: Currency.usd,
      percentage: 5.0,
      thresholdAmount: Money.fromMajorString('100.00', Currency.usd),
      lastExecution: '3 days ago',
      nextExecution: 'Next Monday, 09:00 AM',
      createdAt: DateTime.now().subtract(const Duration(days: 28)),
    ),
    MoneyMissionModel(
      id: 'm5',
      title: 'Annual Equipment Upgrade Reserve',
      tagline: 'Sets aside 10% of every incoming client invoice into hardware savings.',
      ruleType: MissionRuleType.autoSweep,
      isActive: true,
      status: MissionStatus.active,
      stats: '\$890 saved towards MacBook Pro upgrade',
      conditionSummary: 'When incoming payment > \$1,000',
      actionSummary: 'Reserve 10% in Equipment Vault',
      targetCurrency: Currency.usd,
      percentage: 10.0,
      thresholdAmount: Money.fromMajorString('1000.00', Currency.usd),
      lastExecution: '5 days ago',
      nextExecution: 'On Incoming Transfer',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    MoneyMissionModel(
      id: 'm6',
      title: 'Client Retainer Split: CAD & USD',
      tagline: 'Splits Canadian client revenue 60% CADC expenses and 40% USDB reserve.',
      ruleType: MissionRuleType.splitIncoming,
      isActive: true,
      status: MissionStatus.active,
      stats: 'CA\$4,200 processed to date',
      conditionSummary: 'When incoming CAD retainer arrives',
      actionSummary: '60% CADC Operations • 40% USDB Reserve',
      targetCurrency: Currency.cad,
      percentage: 100.0,
      thresholdAmount: Money.fromMajorString('1500.00', Currency.cad),
      lastExecution: '1 week ago',
      nextExecution: 'On Incoming CAD Retainer',
      createdAt: DateTime.now().subtract(const Duration(days: 35)),
    ),
    MoneyMissionModel(
      id: 'm7',
      title: 'Emergency Buffer Replenishment',
      tagline: 'Ensures minimum spendable safety buffer of \$1,000 is always maintained.',
      ruleType: MissionRuleType.autoSweep,
      isActive: false,
      status: MissionStatus.paused,
      stats: 'Standing guard paused • Target: \$1,000',
      conditionSummary: 'When balance exceeds \$2,500',
      actionSummary: 'Keep safety floor in USDB',
      targetCurrency: Currency.usd,
      thresholdAmount: Money.fromMajorString('2500.00', Currency.usd),
      lastExecution: '3 weeks ago',
      nextExecution: 'Paused',
      createdAt: DateTime.now().subtract(const Duration(days: 70)),
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
      final nextActive = !current.isActive;
      final updated = current.copyWith(
        isActive: nextActive,
        status: nextActive ? MissionStatus.active : MissionStatus.paused,
      );
      _missions[idx] = updated;
      return updated;
    }
    throw Exception('Mission not found: $id');
  }

  @override
  Future<MoneyMissionModel> createMission(MoneyMissionModel mission) async {
    _missions.insert(0, mission);
    return mission;
  }

  @override
  Future<MissionIntent> interpretMission(String prompt) async {
    return ClientMissionInterpreter.interpret(prompt);
  }

  @override
  Future<Map<String, dynamic>> proposeMission(MissionIntent intent) async {
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

  @override
  Future<Map<String, dynamic>> executeMission({
    required String missionId,
    required String signature,
    bool pinValidated = true,
  }) async {
    // Simulate on-device B-Key signing and BMONI settlement
    final idx = _missions.indexWhere((m) => m.id == missionId);
    if (idx != -1) {
      _missions[idx] = _missions[idx].copyWith(
        isActive: true,
        status: MissionStatus.active,
        lastExecution: 'Just now',
      );
    }

    final txRef = 'bmoni_tx_${DateTime.now().millisecondsSinceEpoch}';

    // Record into shared ActivityRepository if provided
    if (activityRepo != null) {
      try {
        final mission = (idx != -1) ? _missions[idx] : _missions.first;
        final amt = mission.thresholdAmount ??
            Money.fromMajorString('2000.00', Currency.usd);
        await activityRepo!.recordActivity(
          ActivityModel(
            id: 'act_msn_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Mission Activated: ${mission.title}',
            description: mission.tagline.isNotEmpty
                ? mission.tagline
                : 'Autonomous financial mission activated',
            amount: amt,
            currency: amt.currency,
            type: ActivityType.mission,
            category: ActivityCategory.mission,
            counterparty: 'BMONI Autonomous Vaults',
            status: FlowPayAppStatus.completed,
            timestamp: DateTime.now(),
            reference:
                'FP-MSN-${missionId.length > 8 ? missionId.substring(missionId.length - 6).toUpperCase() : missionId}',
            source: 'Personal Smart Wallet (${amt.currency.code})',
            destination: 'BMONI Autonomous Vaults',
            fee: Money.zero(amt.currency),
            exchangeRate: 'N/A (Multi-Rail Sweep)',
            bmoniReference: txRef,
            metadata: {
              'missionId': missionId,
              'rule': mission.title,
              'allocations': mission.allocations.length,
            },
          ),
        );
      } catch (_) {}
    }

    return {
      'success': true,
      'missionId': missionId,
      'status': 'ACTIVE',
      'executedAt': DateTime.now().toIso8601String(),
      'transactionReference': txRef,
      'summary':
          'Mission successfully authorized, signed with B-Key PIN, and executed on BMONI rails.',
    };
  }

  @override
  Future<MoneyMissionModel> triggerManualExecution(String id) async {
    final idx = _missions.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final current = _missions[idx];
      Money amt = current.thresholdAmount ??
          Money.fromMajorString('2000.00', current.targetCurrency ?? Currency.usd);
      String? recipient;
      if (current.allocations.isNotEmpty) {
        final transferAlloc = current.allocations.firstWhere(
          (a) => a.actionType == MissionActionType.transfer,
          orElse: () => current.allocations.first,
        );
        final minor = int.tryParse(transferAlloc.sourceAmountMinor);
        if (minor != null && minor > 0) {
          amt = Money.fromMinor(minor, current.targetCurrency ?? Currency.usd);
        }
        recipient = transferAlloc.recipientIdentifier;
      }
      final newCount = current.executionCount + 1;
      final newExecuted =
          (current.executedAmount ?? Money.zero(amt.currency)).add(amt);

      final updated = current.copyWith(
        isActive: true,
        status: MissionStatus.active,
        executionCount: newCount,
        executedAmount: newExecuted,
        stats:
            '$newCount execution(s) • ${newExecuted.toFormattedString()} settled',
        lastExecution: 'Just now',
      );
      _missions[idx] = updated;

      // Update wallet balance so real money movement reflects in the user's balances
      if (walletRepo != null) {
        try {
          final wallets = await walletRepo!.getWallets();
          final matchingWallet = wallets.firstWhere(
            (w) => w.currency == amt.currency,
            orElse: () => wallets.first,
          );
          if (matchingWallet.balance.minorUnits >= amt.minorUnits) {
            await walletRepo!.debitWallet(walletId: matchingWallet.id, amount: amt);
          }
        } catch (_) {}
      }

      // Record into shared ActivityRepository if provided
      if (activityRepo != null) {
        try {
          await activityRepo!.recordActivity(
            ActivityModel(
              id: 'act_trig_${DateTime.now().millisecondsSinceEpoch}',
              title: recipient != null
                  ? 'Transfer to $recipient'
                  : '⚡ Mission Executed: ${updated.title}',
              description: updated.actionSummary.isNotEmpty
                  ? updated.actionSummary
                  : 'Triggered split: 30% USD Vault, 50% NGN Expenses, 20% Tax Escrow',
              amount: amt,
              currency: amt.currency,
              type: recipient != null ? ActivityType.transfer : ActivityType.mission,
              category: recipient != null ? ActivityCategory.transfer : ActivityCategory.mission,
              counterparty: recipient != null ? 'Mary Fashola ($recipient)' : 'BMONI Settlement Rails',
              status: FlowPayAppStatus.completed,
              timestamp: DateTime.now(),
              reference:
                  'FP-SWEEP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              source: 'Personal Smart Wallet (${amt.currency.code})',
              destination: 'USD Vault / CNGN / Tax Escrow',
              fee: Money.fromMinor(10, amt.currency),
              exchangeRate: '1 USD = 1,550.00 NGN',
              bmoniReference:
                  '0x88fbc921...${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
              metadata: {
                'missionId': id,
                'rule': updated.title,
                'manualTrigger': true,
              },
            ),
          );
        } catch (_) {}
      }

      return updated;
    }
    throw Exception('Mission not found: $id');
  }

  @override
  Future<bool> deleteMission(String id) async {
    _missions.removeWhere((m) => m.id == id);
    return true;
  }
}

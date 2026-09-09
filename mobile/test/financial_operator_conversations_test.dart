import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/beneficiaries/beneficiary_repository.dart';
import 'package:flowpay_mobile/core/financial_engine/models/reservation_ledger.dart';
import 'package:flowpay_mobile/core/financial_operator/financial_operator.dart';
import 'package:flowpay_mobile/core/financial_operator/models/financial_plan_models.dart';
import 'package:flowpay_mobile/core/financial_operator/models/operator_session_models.dart';
import 'package:flowpay_mobile/core/financial_operator/services/execution_provider.dart';
import 'package:flowpay_mobile/core/financial_operator/services/financial_context_service.dart';
import 'package:flowpay_mobile/core/missions/mission_runtime_engine.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_activity_repo.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_wallet_repo.dart';

void main() {
  group('FlowPay Financial Intelligence Engine — Conversations 1 to 7 Acceptance Tests', () {
    late DemoWalletRepository walletRepo;
    late DemoBeneficiaryRepository beneficiaryRepo;
    late DemoActivityRepository activityRepo;
    late FinancialContextService contextService;
    late DemoFinancialExecutionProvider executionProvider;
    late FinancialOperator operator;

    setUp(() {
      walletRepo = DemoWalletRepository();
      beneficiaryRepo = DemoBeneficiaryRepository();
      activityRepo = DemoActivityRepository();
      contextService = FinancialContextService(
        walletRepo: walletRepo,
        beneficiaryRepo: beneficiaryRepo,
        activityRepo: activityRepo,
      );
      executionProvider = DemoFinancialExecutionProvider(
        walletRepo: walletRepo,
        activityRepo: activityRepo,
      );
      operator = FinancialOperator(
        contextService: contextService,
        executionProvider: executionProvider,
      );
      MissionRuntimeEngine().reset();
      ReservationLedger().clear();
    });

    test('Conversation 1: First-class wallets — Internal wallet transfer & conversion', () async {
      // User: "Send 100,000 from my naira wallet to my usd wallet"
      await operator.processInput('Send 100,000 from my naira wallet to my usd wallet');

      // Invariant 1: Must NOT ask "Who is USD wallet?"
      expect(operator.status, equals(OperatorSessionStatus.readyForReview));
      expect(operator.pendingClarification, isNull);

      final plan = operator.activePlan;
      expect(plan, isNotNull);
      expect(plan!.actions.length, equals(1));

      final action = plan.actions.first;
      expect(action.type, equals(PlannedActionType.convert));
      expect(action.amount.currency, equals(Currency.ngn));
      expect(action.amount.minorUnits, equals(10000000)); // ₦100,000.00
      expect(action.destinationCurrency, equals(Currency.usd));
      expect(action.destinationName.toLowerCase(), contains('usd'));
      expect(action.sourceWalletName.toLowerCase(), anyOf(contains('naira'), contains('ngn')));
      expect(action.destinationAmount, isNotNull);
      expect(action.destinationAmount!.minorUnits, greaterThan(0));

      // Invariant 2: Explicit dual balance changes (source debit, destination credit)
      expect(plan.expectedBalanceChanges.length, equals(2));
      final debitImpact = plan.expectedBalanceChanges.firstWhere((b) => b.isDebit);
      final creditImpact = plan.expectedBalanceChanges.firstWhere((b) => b.isCredit);
      expect(debitImpact.currency, equals(Currency.ngn));
      expect(creditImpact.currency, equals(Currency.usd));

      // Invariant 3: Hardware Enclave / PIN Approval Boundary
      // Execute plan with PIN
      await operator.approveAndExecute(pin: '1234');
      expect(operator.status, equals(OperatorSessionStatus.completed));
    });

    test('Conversation 2: Conversational Mission Creation — "Whenever I get paid in USD, keep 20%"', () async {
      // Turn 1: User requests automated rule
      await operator.processInput('Whenever I get paid in USD, keep 20%');

      // Operator asks clarifying question for target reserve
      expect(operator.status, equals(OperatorSessionStatus.waitingForClarification));
      expect(operator.pendingClarification, isNotNull);
      expect(operator.pendingClarification?.field, equals('mission_destination'));
      expect(operator.pendingClarification?.question,
          contains("Whenever USD arrives, I'll reserve 20%. Where should the 20% go"));

      // Turn 2: User specifies policy destination
      await operator.processInput('Save it for taxes');

      // Operator configures and activates mission
      expect(operator.status, equals(OperatorSessionStatus.idle));
      final lastMsg = operator.messages.last.text;
      expect(lastMsg, contains("Tax Reserve Mission"));
      expect(lastMsg.toLowerCase(), contains("reserve 20%"));
      expect(lastMsg, contains("ACTIVE"));

      final activeMissions = MissionRuntimeEngine().missions;
      expect(activeMissions.isNotEmpty, isTrue);
      final taxMission = activeMissions.first;
      expect(taxMission.isActive, isTrue);
      expect(taxMission.rules.first.percentage, equals(20.0));
      expect(taxMission.rules.first.targetReserveName, equals('Tax Reserve'));
    });

    test('Conversation 3: In-place Mission Modification — "Actually make it 25%"', () async {
      // Setup initial mission
      await operator.processInput('Whenever I get paid in USD, keep 20%');
      await operator.processInput('Save it for taxes');

      final initialCount = MissionRuntimeEngine().missions.length;

      // User modifies mission percentage in place
      await operator.processInput('Actually make it 25%');

      expect(operator.status, equals(OperatorSessionStatus.idle));
      final lastMsg = operator.messages.last.text;
      expect(lastMsg, contains('reserve 25% for taxes'));
      expect(lastMsg, contains('ACTIVE'));

      // Invariant: Does NOT create duplicate mission
      expect(MissionRuntimeEngine().missions.length, equals(initialCount));
      final updatedMission = MissionRuntimeEngine().missions.first;
      expect(updatedMission.rules.first.percentage, equals(25.0));
    });

    test('Conversation 4: Multi-Action Mission with Spendable Balance Awareness', () async {
      // Setup 25% tax mission
      await operator.processInput('Whenever I get paid in USD, keep 20%');
      await operator.processInput('Save it for taxes');
      await operator.processInput('Actually make it 25%');

      // User appends second action to mission
      await operator.processInput("Also send 200 to my designer whenever there's enough");

      expect(operator.status, equals(OperatorSessionStatus.idle));
      final lastMsg = operator.messages.last.text;
      expect(lastMsg, contains('1. Reserve 25% for taxes happens first into your Tax Reserve'));
      expect(lastMsg, contains('2. Send \$200.00 to your designer happens second, strictly from remaining spendable balance'));
      expect(lastMsg, contains('Deterministic Safety Guarantee'));

      final mission = MissionRuntimeEngine().missions.first;
      expect(mission.rules.length, equals(2));
      expect(mission.rules[0].type, equals(MissionActionRuleType.reservePercentage));
      expect(mission.rules[1].type, equals(MissionActionRuleType.sendFixedAmount));
      expect(mission.rules[1].fixedAmount?.minorUnits, equals(20000)); // $200.00
    });

    test('Conversation 5: Real Inflow Trigger & Partial Funding Protection', () async {
      // Setup ordered multi-action mission (25% tax, $200 designer)
      await operator.processInput('Whenever I get paid in USD, keep 20%');
      await operator.processInput('Save it for taxes');
      await operator.processInput('Actually make it 25%');
      await operator.processInput("Also send 200 to my designer whenever there's enough");

      // Inflow arrives: $250.00 USD
      final inflow = WalletInflowEvent(
        id: 'inflow_evt_1',
        walletId: 'sw_demo_usdb_01',
        currency: Currency.usd,
        amount: Money.fromMajorString('250.00', Currency.usd),
        timestamp: DateTime.now(),
      );

      final outcomes = await MissionRuntimeEngine().processEvent(
        inflow,
        walletRepo: walletRepo,
        activityRepo: activityRepo,
      );

      expect(outcomes.isNotEmpty, isTrue);
      final outcome = outcomes.first;

      // Invariant: Tax reserve must be exactly 25% ($62.50)
      expect(outcome.reservedAmount.minorUnits, equals(6250)); // $62.50
      expect(outcome.createdReservation, isNotNull);
      expect(outcome.createdReservation!.isActive, isTrue);

      // Remaining spendable: $250.00 - $62.50 = $187.50
      expect(outcome.remainingSpendable.minorUnits, equals(18750));

      // Designer payment needed $200.00. Since $187.50 < $200.00, it must be skipped!
      expect(outcome.isPartial, isTrue);
      expect(outcome.disbursedAmount, isNull);
      expect(outcome.statusNote, contains('PAYMENT_NOT_FUNDED'));

      // Tax reserve in ledger remains strictly untouched ($62.50)
      final totalReserved = ReservationLedger().getTotalReserved('sw_demo_usdb_01', Currency.usd);
      expect(totalReserved.minorUnits, equals(6250));
    });

    test('Conversation 6: Reservation Ledger & Balance Transparency', () async {
      // Setup a $200 reservation for taxes in USD wallet
      ReservationLedger().createReservation(
        walletId: 'sw_demo_usdb_01',
        amount: Money.fromMajorString('200.00', Currency.usd),
        reason: 'taxes',
        missionId: 'tax_mission',
      );

      // User asks: "How much can I spend from my USD wallet?"
      await operator.processInput('How much can I spend from my USD wallet?');

      expect(operator.status, equals(OperatorSessionStatus.idle));
      final lastMsg = operator.messages.last.text;
      expect(lastMsg, contains('\$200.00 reserved for taxes'));
      expect(lastMsg, contains('spendable balance'));

      // User asks: "Why can't I spend this money?"
      await operator.processInput("Why can't I spend this money?");
      final whyMsg = operator.messages.last.text;
      expect(whyMsg, contains('\$200.00 is reserved for taxes'));
      expect(whyMsg, contains('guarantees that your tax obligations'));

      // User asks: "How much have I saved for taxes?"
      await operator.processInput('How much have I saved for taxes?');
      final taxMsg = operator.messages.last.text;
      expect(taxMsg, contains('You currently have \$200.00 reserved for taxes in your Tax Reserve'));
    });

    test('Conversation 7: Mission Lifecycle Control — Pause & Resume', () async {
      // Setup tax mission
      await operator.processInput('Whenever I get paid in USD, keep 20%');
      await operator.processInput('Save it for taxes');

      final mission = MissionRuntimeEngine().missions.first;
      expect(mission.isActive, isTrue);

      // User: "Pause my tax mission"
      await operator.processInput('Pause my tax mission');
      expect(operator.status, equals(OperatorSessionStatus.idle));
      expect(operator.messages.last.text, contains("I've paused your Tax Reserve Savings"));
      expect(MissionRuntimeEngine().missions.first.isPaused, isTrue);

      // User: "Resume it"
      await operator.processInput('Resume it');
      expect(operator.status, equals(OperatorSessionStatus.idle));
      expect(operator.messages.last.text, contains("I've resumed your Tax Reserve Savings"));
      expect(MissionRuntimeEngine().missions.first.isActive, isTrue);
    });
  });
}

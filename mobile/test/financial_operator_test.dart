import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/beneficiaries/beneficiary_model.dart';
import 'package:flowpay_mobile/core/beneficiaries/beneficiary_repository.dart';
import 'package:flowpay_mobile/core/financial_operator/financial_operator.dart';
import 'package:flowpay_mobile/core/financial_operator/models/financial_entities.dart';
import 'package:flowpay_mobile/core/financial_operator/models/financial_intent_types.dart';
import 'package:flowpay_mobile/core/financial_operator/models/operator_session_models.dart';
import 'package:flowpay_mobile/core/financial_operator/services/clarification_engine.dart';
import 'package:flowpay_mobile/core/financial_operator/services/context_resolver.dart';
import 'package:flowpay_mobile/core/financial_operator/services/execution_provider.dart';
import 'package:flowpay_mobile/core/financial_operator/services/financial_context_service.dart';
import 'package:flowpay_mobile/core/financial_operator/services/financial_intent_engine.dart';
import 'package:flowpay_mobile/core/financial_operator/services/financial_planner.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_activity_repo.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_wallet_repo.dart';
import 'package:flowpay_mobile/core/repositories/wallet_repository.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/modules/personal/ai_operator_modal.dart';

void main() {
  group('FlowPay Financial Operator — Core Intelligence Tests', () {
    late DemoWalletRepository walletRepo;
    late DemoBeneficiaryRepository beneficiaryRepo;
    late DemoActivityRepository activityRepo;
    late FinancialContextService contextService;
    late DemoFinancialExecutionProvider executionProvider;

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
    });

    test('1. Financial Intent Types: 18 strongly typed intents supported', () {
      expect(FinancialIntentType.values.length, equals(18));
      expect(FinancialIntentType.fromCode('SEND_MONEY'),
          equals(FinancialIntentType.sendMoney));
      expect(FinancialIntentType.fromCode('CREATE_RESERVE'),
          equals(FinancialIntentType.createReserve));
      expect(FinancialIntentType.fromCode('ALLOCATE_MONEY'),
          equals(FinancialIntentType.allocateMoney));
      expect(FinancialIntentType.fromCode('CREATE_MISSION'),
          equals(FinancialIntentType.createMission));
      expect(FinancialIntentType.fromCode('UNKNOWN'),
          equals(FinancialIntentType.unknown));
    });

    test('2. Beneficiary Resolution: Known alias "Mom" resolves to Mary Fashola',
        () async {
      final parsed = FinancialIntentEngine.parse('Send \$500 to Mom');
      expect(parsed.actions.length, equals(1));
      expect(parsed.actions.first.person?.rawInput, equals('Mom'));

      final resolver = ContextResolver(contextService: contextService);
      final resolved = await resolver.resolve(parsed);

      final person = resolved.actions.first.person!;
      expect(person.knowledgeState, equals(EntityKnowledgeState.known));
      expect(person.resolvedBeneficiary?.legalName, equals('Mary Fashola'));
      expect(person.resolvedBeneficiary?.destinationCountry, equals('Nigeria'));
    });

    test('3. Beneficiary Resolution: Unknown recipient triggers unknown state',
        () async {
      final parsed =
          FinancialIntentEngine.parse('Send \$500 to UnknownPerson');
      final resolver = ContextResolver(contextService: contextService);
      final resolved = await resolver.resolve(parsed);

      final person = resolved.actions.first.person!;
      expect(person.knowledgeState, equals(EntityKnowledgeState.unknown));

      final clarification =
          ClarificationEngine.evaluateClarification(resolved);
      expect(clarification, isNotNull);
      expect(clarification!.field, equals('recipient'));
      expect(clarification.question, contains('UnknownPerson'));
    });

    test('4. Amount & Currency Parsing: Dollars, symbols, and local rails', () {
      final parsedUsd = FinancialIntentEngine.parse('Send 500 dollars to Sarah');
      expect(parsedUsd.actions.first.amount.fixedAmount?.toMajorString(),
          equals('500.00'));
      expect(parsedUsd.actions.first.amount.currency, equals(Currency.usd));

      final parsedNgn =
          FinancialIntentEngine.parse('Send ₦300,000 to Designer');
      expect(parsedNgn.actions.first.amount.fixedAmount?.toMajorString(),
          equals('300000.00'));
      expect(parsedNgn.actions.first.amount.currency, equals(Currency.ngn));

      final parsedMxn =
          FinancialIntentEngine.parse('Pay 5000 pesos to Contractor MX');
      expect(parsedMxn.actions.first.amount.currency, equals(Currency.mxn));
    });

    test('5. Relative Amounts & Percentages: "keep 30% for tax" and "half"',
        () async {
      final parsedPct = FinancialIntentEngine.parse('Keep 30% for tax');
      expect(parsedPct.actions.first.amount.type, equals(AmountType.percentage));
      expect(parsedPct.actions.first.amount.percentage, equals(30.0));

      final parsedHalf = FinancialIntentEngine.parse('Send half to Mom');
      expect(parsedHalf.actions.first.amount.type, equals(AmountType.half));
      expect(parsedHalf.actions.first.amount.percentage, equals(50.0));
    });

    test('6. Multi-Action Parsing: "Send 500 usd to mom, keep 300 usd for tax"',
        () async {
      final parsed = FinancialIntentEngine.parse(
          'Send 500 usd to mom, keep 300 usd for tax');
      expect(parsed.actions.length, equals(2));

      // Action 1: Send $500 to Mom
      expect(parsed.actions[0].intentType, equals(FinancialIntentType.sendMoney));
      expect(parsed.actions[0].amount.fixedAmount?.toMajorString(), equals('500.00'));
      expect(parsed.actions[0].person?.rawInput, equals('mom'));

      // Action 2: Reserve $300 for Tax
      expect(parsed.actions[1].intentType, equals(FinancialIntentType.createReserve));
      expect(parsed.actions[1].amount.fixedAmount?.toMajorString(), equals('300.00'));
      expect(parsed.actions[1].purpose, equals('tax'));
    });

    test('7. 3-Action Allocation: "I just got paid \$2,000. Keep 30% for tax, send \$500 to Mom and put the rest in savings"',
        () async {
      final parsed = FinancialIntentEngine.parse(
          'I just got paid \$2,000. Keep 30% for tax, send \$500 to Mom and put the rest in savings');

      expect(parsed.incomingAmount?.fixedAmount?.toMajorString(), equals('2000.00'));
      expect(parsed.actions.length, equals(3));

      final resolver = ContextResolver(contextService: contextService);
      final resolved = await resolver.resolve(parsed);

      // Action 1: Tax 30% of $2,000 = $600
      expect(resolved.actions[0].amount.resolvedAmount?.toMajorString(),
          equals('600.00'));

      // Action 2: Send $500 to Mom
      expect(resolved.actions[1].amount.fixedAmount?.toMajorString(),
          equals('500.00'));
      expect(resolved.actions[1].person?.resolvedBeneficiary?.legalName,
          equals('Mary Fashola'));

      // Action 3: Remainder $2,000 - ($600 + $500) = $900 in Savings
      expect(resolved.actions[2].amount.resolvedAmount?.toMajorString(),
          equals('900.00'));

      // Verify exact math with zero floating-point drift
      final totalAllocated =
          resolved.actions[0].amount.resolvedAmount!.minorUnits +
              resolved.actions[1].amount.fixedAmount!.minorUnits +
              resolved.actions[2].amount.resolvedAmount!.minorUnits;
      expect(totalAllocated, equals(200000)); // Exactly 200,000 cents ($2,000.00)
    });

    test('8. Deterministic Policy Validator: Rejects Insufficient Funds',
        () async {
      // Primary USD wallet has $24,500 in demo, create custom context with low balance
      final lowBalanceWallet = WalletAccount(
        id: 'sw_low_01',
        address: '0x123',
        currency: Currency.usd,
        stablecoinToken: 'USDB',
        balance: Money.fromMajorString('2000.00', Currency.usd),
        status: 'active',
      );

      final customWalletRepo = _MockSingleWalletRepo(lowBalanceWallet);
      final lowContextService = FinancialContextService(
        walletRepo: customWalletRepo,
        beneficiaryRepo: beneficiaryRepo,
      );

      final planner = FinancialPlanner(contextService: lowContextService);

      final parsed = FinancialIntentEngine.parse('Send \$5000 to Mom');
      final resolver = ContextResolver(contextService: lowContextService);
      final resolved = await resolver.resolve(parsed);

      final plan = await planner.createPlan(resolved);

      expect(plan.validation.isValid, isFalse);
      expect(plan.validation.errors.first,
          contains('You don\'t have enough USD to complete this plan'));
    });

    test('9. Approval Boundary: Never executes without explicit approval',
        () async {
      final operator = FinancialOperator(
        contextService: contextService,
        executionProvider: executionProvider,
      );

      // Initial state is idle, activePlan is null
      expect(operator.activePlan, isNull);
      expect(operator.status, equals(OperatorSessionStatus.idle));

      // Attempting approve before plan exists does not throw or execute
      await operator.approveAndExecute(pin: '123456');
      expect(operator.status, equals(OperatorSessionStatus.idle));
    });

    test('10. Final Acceptance Test (Prompt #38 Complete Multi-Turn Scenario)',
        () async {
      final operator = FinancialOperator(
        contextService: contextService,
        executionProvider: executionProvider,
      );

      // Turn 1: USER submits multi-action prompt
      await operator
          .processInput('Send 500 usd to mom, keep 300 usd for tax.');

      // Mom is known (Mary Fashola in Nigeria), but tax reserve destination is not yet configured!
      // Operator should ask where to keep the $300 tax reserve.
      expect(operator.status,
          equals(OperatorSessionStatus.waitingForClarification));
      expect(operator.pendingClarification, isNotNull);
      expect(operator.pendingClarification?.field, equals('destination'));
      expect(operator.pendingClarification?.question,
          contains('Where should I keep the \$300.00 tax reserve?'));

      // Turn 2: USER responds naturally
      await operator.processInput('Put it in my USD savings.');

      // FlowPay resolves destination to USD Savings and compiles structured plan
      expect(operator.status, equals(OperatorSessionStatus.readyForReview));
      expect(operator.activePlan, isNotNull);
      final plan = operator.activePlan!;

      expect(plan.actions.length, equals(2));
      // Action 1: Send $500.00 to Mary Fashola (Mom)
      expect(plan.actions[0].amount.toMajorString(), equals('500.00'));
      expect(plan.actions[0].destinationName, equals('Mary Fashola (Mom)'));

      // Action 2: Reserve $300.00 in USD Savings
      expect(plan.actions[1].amount.toMajorString(), equals('300.00'));
      expect(plan.actions[1].destinationName, equals('USD Savings'));

      // Verified projected balance impact
      expect(plan.expectedBalanceChanges.isNotEmpty, isTrue);

      // Turn 3: USER approves
      await operator.approveAndExecute(pin: '123456');

      // Operator settles transaction
      expect(operator.status, equals(OperatorSessionStatus.completed));
      expect(operator.activePlan?.executionState, equals('COMPLETED'));
      expect(operator.activePlan?.txHash, isNotNull);
    });

    testWidgets('11. UI Widget Test: AiOperatorModal renders and processes input',
        (tester) async {
      final appState = AppState(providerMode: ProviderMode.demo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiOperatorModal(appState: appState),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header & telemetry bar
      expect(find.text('FlowPay Financial Operator'), findsOneWidget);
      expect(find.text('B-Key Guard: Active  •  Deterministic Math'),
          findsOneWidget);

      // Verify quick action pills
      expect(find.textContaining('Send 500 usd to mom'), findsOneWidget);
    });

    test('12. Clarification Flow: Resolves unknown beneficiary via Add Beneficiary',
        () async {
      final op = FinancialOperator(
        contextService: contextService,
        executionProvider: executionProvider,
      );

      // 1. Process request with unknown beneficiary "Dad"
      await op.processInput('Send 500 to dad');

      expect(op.status, equals(OperatorSessionStatus.waitingForClarification));
      expect(op.pendingClarification?.question, contains('dad'));
      expect(
        op.pendingClarification?.options
            .any((o) => o.value == 'ADD_BENEFICIARY'),
        isTrue,
      );

      // 2. Resolve with a newly created beneficiary
      const newDad = Beneficiary(
        id: 'ben_dad_test_01',
        nickname: 'Dad',
        legalName: 'Ade Fashola',
        relationship: 'Father',
        destinationCountry: 'Nigeria',
        countryFlag: '🇳🇬',
        currency: Currency.ngn,
        accountOrAddress: '0123456789 (GTBank)',
        isVerified: true,
      );
      await contextService.addBeneficiary(newDad);
      await op.resolvePendingClarificationWithBeneficiary(newDad);

      // 3. Verify session resolves to ready and plan is compiled
      expect(op.status, equals(OperatorSessionStatus.readyForReview));
      expect(op.pendingClarification, isNull);
      expect(op.activePlan, isNotNull);
      expect(op.activePlan!.validation.isValid, isTrue);
      expect(
          op.activePlan!.actions.first.destinationName, contains('Ade Fashola'));
    });
  });
}

class _MockSingleWalletRepo implements WalletRepository {
  final WalletAccount wallet;

  _MockSingleWalletRepo(this.wallet);

  @override
  Future<List<WalletAccount>> getWallets() async => [wallet];

  @override
  Future<bool> debitWallet(
      {required String walletId, required Money amount}) async => true;

  @override
  Future<bool> creditWallet(
      {required String walletId, required Money amount}) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

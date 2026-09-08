import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/beneficiaries/beneficiary_model.dart';
import 'package:flowpay_mobile/core/beneficiaries/beneficiary_repository.dart';
import 'package:flowpay_mobile/core/financial_engine/financial_engine.dart';
import 'package:flowpay_mobile/core/financial_operator/financial_operator.dart';
import 'package:flowpay_mobile/core/financial_operator/models/financial_plan_models.dart';
import 'package:flowpay_mobile/core/financial_operator/models/operator_session_models.dart';
import 'package:flowpay_mobile/core/financial_operator/services/execution_provider.dart';
import 'package:flowpay_mobile/core/financial_operator/services/financial_context_service.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_activity_repo.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_wallet_repo.dart';
import 'package:flowpay_mobile/core/repositories/wallet_repository.dart';

void main() {
  group('FLOWPAY — SMART PAYMENT ENGINE & OPERATOR SUITE', () {
    late DemoWalletRepository walletRepo;
    late DemoBeneficiaryRepository beneficiaryRepo;
    late DemoActivityRepository activityRepo;
    late FinancialContextService contextService;
    late DemoExecutionProvider executionProvider;
    late DemoFinancialExecutionProvider opExecutionProvider;
    late FundingPlanner fundingPlanner;
    late FinancialOperator operator;

    setUp(() {
      walletRepo = DemoWalletRepository();
      // Configure Hero balances: USD $1,200.00, EUR €2,000.00, NGN ₦800,000.00
      walletRepo.setWalletBalance(Currency.usd, Money.fromMajorString('1200.00', Currency.usd));
      walletRepo.setWalletBalance(Currency.ngn, Money.fromMajorString('800000.00', Currency.ngn));
      walletRepo.addWalletAccount(
        WalletAccount(
          id: 'sw_demo_eure_05',
          address: '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
          currency: Currency.eur,
          stablecoinToken: 'EURe',
          balance: Money.fromMajorString('2000.00', Currency.eur),
          status: 'active',
        ),
      );

      beneficiaryRepo = DemoBeneficiaryRepository();
      activityRepo = DemoActivityRepository();
      contextService = FinancialContextService(
        walletRepo: walletRepo,
        beneficiaryRepo: beneficiaryRepo,
        activityRepo: activityRepo,
      );
      executionProvider = DemoExecutionProvider(
        activityRepo: activityRepo,
        walletRepo: walletRepo,
        initialUsd: Money.fromMajorString('1200.00', Currency.usd),
        initialEur: Money.fromMajorString('2000.00', Currency.eur),
        initialNgn: Money.fromMajorString('800000.00', Currency.ngn),
      );
      fundingPlanner = FundingPlanner(executionProvider: executionProvider);
      opExecutionProvider = DemoFinancialExecutionProvider(
        walletRepo: walletRepo,
        activityRepo: activityRepo,
      );
      operator = FinancialOperator(
        contextService: contextService,
        executionProvider: opExecutionProvider,
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 1: Enough USD (direct funding covers 100%)
    // -------------------------------------------------------------------------
    test('Scenario 1: Direct funding covers payment when USD balance is sufficient', () async {
      final mom = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Mom');
      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_1',
            recipient: mom,
            amount: Money.fromMajorString('500.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      expect(plan.validation.isValid, isTrue);
      expect(plan.shortfall.minorUnits, equals(0));
      expect(plan.availableDirect.toMajorString(), equals('1200.00'));
      expect(plan.fundingAllocations.length, equals(1));
      expect(plan.fundingAllocations.first.requiresConversion, isFalse);
      expect(plan.fundingAllocations.first.currency, equals(Currency.usd));
      expect(plan.fundingAllocations.first.allocatedAmount.toMajorString(), equals('500.00'));
      expect(plan.routeExplanation, contains('Direct funding'));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Insufficient USD ($500 USD + EUR conversion for shortfall)
    // -------------------------------------------------------------------------
    test('Scenario 2: Insufficient USD auto-funds shortfall via EUR conversion', () async {
      walletRepo.setWalletBalance(Currency.usd, Money.fromMajorString('500.00', Currency.usd));

      final mom = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Mom');
      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_2',
            recipient: mom,
            amount: Money.fromMajorString('1200.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      expect(plan.validation.isValid, isTrue);
      expect(plan.availableDirect.toMajorString(), equals('500.00'));
      expect(plan.shortfall.toMajorString(), equals('700.00'));
      expect(plan.fundingAllocations.length, equals(2));

      // Direct USD allocation consumes all $500
      final directAlloc = plan.fundingAllocations.firstWhere((a) => !a.requiresConversion);
      expect(directAlloc.allocatedAmount.toMajorString(), equals('500.00'));

      // EUR allocation covers $700.00 shortfall
      final fxAlloc = plan.fundingAllocations.firstWhere((a) => a.requiresConversion);
      expect(fxAlloc.currency, equals(Currency.eur));
      expect(fxAlloc.convertedOutputAmount.toMajorString(), equals('700.00'));
      expect(fxAlloc.quote, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Cross-border Nigeria (USD -> FX -> NGN Nigerian Bank Account)
    // -------------------------------------------------------------------------
    test('Scenario 3: Cross-border payment delivers NGN to Nigerian bank account', () async {
      final mom = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Mom');
      final quote = await executionProvider.getQuote(
        source: Currency.usd,
        destination: Currency.ngn,
        amount: Money.fromMajorString('500.00', Currency.usd),
      );

      expect(quote.exchangeRate, equals(1550.0));
      // 500 * 1550 = 775,000 NGN
      expect(quote.destinationAmount.toMajorString(), equals('775000.00'));
      expect(quote.destinationCurrency, equals(Currency.ngn));

      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_ngn',
            recipient: mom,
            amount: Money.fromMajorString('500.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      expect(plan.items.first.destinationCurrency, equals(Currency.ngn));
      expect(plan.items.first.destinationAmount.toMajorString(), equals('775000.00'));
      expect(plan.items.first.destinationRail, contains('GTBank'));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Cross-border Ghana (USD -> FX -> GHS Ghanaian Mobile Money)
    // -------------------------------------------------------------------------
    test('Scenario 4: Cross-border payment delivers GHS to Ghanaian account/wallet', () async {
      final designer = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Designer');
      final quote = await executionProvider.getQuote(
        source: Currency.usd,
        destination: Currency.ghs,
        amount: Money.fromMajorString('2000.00', Currency.usd),
      );

      expect(quote.exchangeRate, equals(15.50));
      // 2000 * 15.50 = 31,000 GHS
      expect(quote.destinationAmount.toMajorString(), equals('31000.00'));
      expect(quote.destinationCurrency, equals(Currency.ghs));

      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_ghs',
            recipient: designer,
            amount: Money.fromMajorString('2000.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      expect(plan.items.first.destinationCurrency, equals(Currency.ghs));
      expect(plan.items.first.destinationAmount.toMajorString(), equals('31000.00'));
      expect(plan.items.first.destinationRail, contains('MTN MoMo'));
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Hero Multi-Payment Batch ($500 Mom + $2,000 Designer)
    // -------------------------------------------------------------------------
    test('Scenario 5: Complete Hero Multi-Payment Batch with B-Key PIN Signing', () async {
      // User says: "Send $500 USD to Mom and pay my designer $2,000 USD."
      await operator.processInput('Send \$500 USD to Mom and pay my designer \$2,000 USD.');

      expect(operator.status, equals(OperatorSessionStatus.readyForReview));
      final plan = operator.activePlan;
      expect(plan, isNotNull);

      // Verify total requested = $2,500 USD
      expect(plan!.actions.length, equals(2));
      expect(plan.totalRequested.toMajorString(), equals('2500.00'));

      // Available USD is $1,200 -> shortfall is $1,300
      expect(plan.shortfall?.toMajorString(), equals('1300.00'));

      // Mom delivers NGN, Designer delivers GHS
      final momAction = plan.actions.firstWhere((a) => a.destinationName.contains('Mary Fashola'));
      expect(momAction.destinationCurrency, equals(Currency.ngn));
      expect(momAction.destinationAmount?.toMajorString(), equals('775000.00'));

      final designerAction = plan.actions.firstWhere((a) => a.destinationName.contains('David Mensah'));
      expect(designerAction.destinationCurrency, equals(Currency.ghs));
      expect(designerAction.destinationAmount?.toMajorString(), equals('31000.00'));

      // Multi-wallet balance impacts reflect $0 USD and debited EUR
      final usdImpact = plan.expectedBalanceChanges.firstWhere((b) => b.currency == Currency.usd);
      expect(usdImpact.projectedBalance.toMajorString(), equals('0.00'));

      final eurImpact = plan.expectedBalanceChanges.firstWhere((b) => b.currency == Currency.eur);
      expect(eurImpact.isDebit, isTrue);

      // Approve and execute with B-Key cryptographic PIN
      await operator.approveAndExecute(pin: '123456');

      expect(operator.status, equals(OperatorSessionStatus.completed));
      expect(operator.activePlan?.executionState, equals('COMPLETED'));
      expect(operator.activePlan?.txHash, isNotNull);
      expect(operator.activePlan?.txHash!.startsWith('0x'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Protected reserve (Tax Reserve $1,000 excluded and untouched)
    // -------------------------------------------------------------------------
    test('Scenario 6: Protected tax reserve is strictly excluded from spendable balance', () async {
      // Setup: $1,200 total USD, but $1,000 is protected for Tax Reserve
      executionProvider.setWalletBalance(
        Currency.usd,
        Money.fromMajorString('1200.00', Currency.usd),
        isProtected: true,
        protectedAmount: Money.fromMajorString('1000.00', Currency.usd),
      );

      final mom = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Mom');
      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_tax',
            recipient: mom,
            amount: Money.fromMajorString('500.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      // Spendable USD is only $200 ($1,200 - $1,000 protected)
      expect(plan.availableDirect.toMajorString(), equals('200.00'));
      // Shortfall is $300 ($500 - $200)
      expect(plan.shortfall.toMajorString(), equals('300.00'));

      // EUR is chosen to fund the $300 shortfall, preserving the $1,000 Tax Reserve intact!
      final usdImpact = plan.expectedBalanceChanges.firstWhere((b) => b.currency == Currency.usd);
      expect(usdImpact.projectedBalance.toMajorString(), equals('1000.00'));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Provider unavailable (BMONI outage surfaces message, does not crash)
    // -------------------------------------------------------------------------
    test('Scenario 7: Provider offline surfaces clear error without crashing', () async {
      executionProvider.setAvailable(false);

      expect(
        () async => await executionProvider.getBalances(),
        throwsA(isA<ProviderUnavailableException>()),
      );

      expect(
        () async => await executionProvider.getQuote(
          source: Currency.usd,
          destination: Currency.ngn,
          amount: Money.fromMajorString('100.00', Currency.usd),
        ),
        throwsA(isA<ProviderUnavailableException>()),
      );
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Expired quote (execution blocked until fresh quote)
    // -------------------------------------------------------------------------
    test('Scenario 8: Expired quote blocks execution and requires refresh', () async {
      // Create a plan with an already expired quote
      final expiredPlan = FinancialPlan(
        planId: 'plan_expired_test',
        title: 'Expired Quote Test',
        summary: 'Testing quote expiration gating',
        actions: [
          PlannedFinancialAction(
            id: 'act_exp',
            type: PlannedActionType.send,
            amount: Money.fromMajorString('100.00', Currency.usd),
            sourceWalletId: 'sw_usd',
            sourceWalletName: 'USD Wallet',
            destinationId: 'ben_mom_01',
            destinationName: 'Mom',
            destinationType: 'beneficiary',
            description: 'Send money',
            fee: Money.fromMinor(10, Currency.usd),
          ),
        ],
        totalDebit: Money.fromMajorString('100.00', Currency.usd),
        totalFee: Money.fromMinor(10, Currency.usd),
        expectedBalanceChanges: [],
        validation: const PlanValidationResult(isValid: true),
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        quoteExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(expiredPlan.isQuoteExpired, isTrue);

      final result = await opExecutionProvider.executePlan(expiredPlan, pin: '123456');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('expired'));
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Insufficient funds across all wallets
    // -------------------------------------------------------------------------
    test('Scenario 9: Rejects transfer exceeding all wallet balances combined', () async {
      final mom = (await beneficiaryRepo.getBeneficiaries()).firstWhere((b) => b.nickname == 'Mom');
      final plan = await fundingPlanner.planPaymentBatch(
        requests: [
          PaymentRequest(
            id: 'req_huge',
            recipient: mom,
            amount: Money.fromMajorString('100000.00', Currency.usd),
          ),
        ],
        displayCurrency: Currency.usd,
      );

      expect(plan.validation.isValid, isFalse);
      expect(plan.validation.errors.first, contains('Insufficient funds across all available wallets'));
      expect(plan.executionState, equals(PaymentExecutionState.insufficientFunds));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Ambiguous beneficiary (clarification prompted, execution halted)
    // -------------------------------------------------------------------------
    test('Scenario 10: Ambiguous beneficiary name halts execution and requests clarification', () async {
      // Add a second Mom beneficiary to create ambiguity
      const secondMom = Beneficiary(
        id: 'ben_mom_02',
        nickname: 'Mom (In-Law)',
        legalName: 'Sarah Fashola',
        aliases: ['Mom', 'Mama'],
        relationship: 'Mother-in-law',
        destinationCountry: 'Nigeria',
        countryFlag: '🇳🇬',
        currency: Currency.ngn,
        accountOrAddress: '9876543210 (Zenith Bank)',
      );
      await beneficiaryRepo.addBeneficiary(secondMom);

      await operator.processInput('Send \$200 to Mom');

      expect(operator.status, equals(OperatorSessionStatus.waitingForClarification));
      expect(operator.activePlan, isNull);
      expect(operator.messages.last.text, contains('Which one do you mean?'));
    });

    // -------------------------------------------------------------------------
    // Scenario 11: "Why did you use my EUR?" Data-driven explanation
    // -------------------------------------------------------------------------
    test('Scenario 11: Responds with data-driven explanation for route choice', () async {
      await operator.processInput('Send \$500 USD to Mom and pay my designer \$2,000 USD.');
      expect(operator.status, equals(OperatorSessionStatus.readyForReview));

      // USER asks why EUR was used
      await operator.processInput('Why did you use my EUR?');

      final lastMessage = operator.messages.last.text;
      expect(lastMessage, contains('USD'));
      expect(lastMessage, contains('shortfall'));
      expect(lastMessage, contains('lowest-cost available route'));
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Route override to NGN recalculates plan
    // -------------------------------------------------------------------------
    test('Scenario 12: Route override to NGN recalculates funding plan', () async {
      // Supply sufficient NGN (3,000,000 NGN) to cover the $1,300 shortfall
      walletRepo.setWalletBalance(Currency.ngn, Money.fromMajorString('3000000.00', Currency.ngn));

      await operator.processInput('Send \$500 USD to Mom and pay my designer \$2,000 USD.');
      expect(operator.status, equals(OperatorSessionStatus.readyForReview));
      expect(operator.activePlan?.selectedFundingCurrency, equals(Currency.eur));

      // USER says: "Use NGN instead"
      await operator.processInput('Use NGN instead');

      expect(operator.status, equals(OperatorSessionStatus.readyForReview));
      expect(operator.activePlan?.selectedFundingCurrency, equals(Currency.ngn));
      expect(operator.messages.last.text, contains('NGN'));
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Natural language wallet balancing target command
    // -------------------------------------------------------------------------
    test('Scenario 13: "Make sure I have \$2,000 in USD" proposes wallet balancing top-up', () async {
      final balancer = WalletBalancer(executionProvider: executionProvider);
      final proposal = await balancer.evaluateTarget(
        BalanceTarget(
          currency: Currency.usd,
          minimumAmount: Money.fromMajorString('2000.00', Currency.usd),
        ),
      );

      // Current USD is $1,200. Target is $2,000 -> shortfall top-up needed = $800 USD
      expect(proposal.isExecutable, isTrue);
      expect(proposal.shortfall.toMajorString(), equals('800.00'));
      expect(proposal.fundingCurrency, equals(Currency.eur));
      expect(proposal.explanation.toLowerCase(), contains('convert'));

      // Also verify through the FinancialOperator interface
      await operator.processInput('Make sure I have \$2,000 in USD');
      expect(operator.messages.last.text, contains('short by \$800.00'));
      expect(operator.messages.last.text, contains('EUR wallet'));
      expect(operator.messages.last.text, contains('balancing plan'));
    });
  });
}

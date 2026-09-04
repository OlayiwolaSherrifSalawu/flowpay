import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/money/currency.dart';
import 'package:flowpay_mobile/core/money/money.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_activity_repo.dart';
import 'package:flowpay_mobile/core/providers/demo/demo_transfer_repo.dart';
import 'package:flowpay_mobile/core/repositories/activity_repository.dart';
import 'package:flowpay_mobile/core/repositories/wallet_repository.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/core/transfers/transfer_funding.dart';
import 'package:flowpay_mobile/core/transfers/transfer_intent.dart';
import 'package:flowpay_mobile/modules/personal/components/transfer_review_modal.dart';
import 'package:flowpay_mobile/modules/personal/send_money_screen.dart';

void main() {
  group('Send Money Models & Balance-Aware Routing Unit Tests', () {
    test('TransferIntent JSON serialization and copyWith', () {
      const intent = TransferIntent(
        intentId: 'tx_intent_unit_1',
        originalPrompt: 'Send \$500 to my designer in Ghana',
        recipient: 'my designer in Ghana',
        amount: '500.00',
        amountMinor: '50000',
        currency: Currency.usd,
        purpose: 'Design services',
      );

      final json = intent.toJson();
      expect(json['recipient'], 'my designer in Ghana');
      expect(json['amount'], '500.00');
      expect(json['currency'], 'USD');
      expect(json['requiresExplicitApproval'], true);

      final revived = TransferIntent.fromJson(json);
      expect(revived.recipient, 'my designer in Ghana');
      expect(revived.amount, '500.00');
      expect(revived.currency, Currency.usd);
    });

    test('TransferFundingOption JSON serialization and calculations', () {
      final option = TransferFundingOption(
        fundingWalletId: 'sw_ngn_01',
        fundingCurrency: Currency.ngn,
        fundingWalletName: 'NGN Smart Wallet',
        availableBalance: Money.fromMajorString('6820000.00', Currency.ngn),
        requiresConversion: true,
        conversionLabel: 'NGN → USD',
        exchangeRate: 1550.0,
        convertedDebit: Money.fromMajorString('775000.00', Currency.ngn),
        networkFee: Money.fromMajorString('775.00', Currency.ngn),
        fxFee: Money.fromMajorString('1162.50', Currency.ngn),
        totalDebit: Money.fromMajorString('776937.50', Currency.ngn),
        targetPayment: Money.fromMajorString('500.00', Currency.usd),
      );

      final json = option.toJson();
      expect(json['conversionLabel'], 'NGN → USD');
      expect(json['requiresConversion'], true);
      expect(json['exchangeRate'], 1550.0);

      final revived = TransferFundingOption.fromJson(json);
      expect(revived.conversionLabel, 'NGN → USD');
      expect(revived.fundingCurrency, Currency.ngn);
      expect(revived.totalDebit.amountMinor, BigInt.parse('77693750'));
    });

    test('DemoTransferRepository: natural language prompt interpretation', () async {
      final repo = DemoTransferRepository();
      final intent = await repo.interpretPrompt('Send \$500 to my designer in Ghana.');

      expect(intent.amount, '500.00');
      expect(intent.currency, Currency.usd);
      expect(intent.recipient, contains('designer'));
      expect(intent.requiresExplicitApproval, true);
    });

    test('DemoTransferRepository: Balance-Aware inspection produces NGN funding with NGN->USD conversion', () async {
      final repo = DemoTransferRepository();
      const intent = TransferIntent(
        intentId: 'tx_demo_01',
        originalPrompt: 'Send \$500 to my designer in Ghana',
        recipient: 'my designer in Ghana',
        amount: '500.00',
        amountMinor: '50000',
        currency: Currency.usd,
      );

      // Create test wallets: USD with only $300 (insufficient), NGN with ₦6,820,000 (sufficient)
      final testWallets = [
        WalletAccount(
          id: 'sw_usd_01',
          address: '0x1111111111111111111111111111111111111111',
          currency: Currency.usd,
          stablecoinToken: 'USDB',
          balance: Money.fromMajorString('300.00', Currency.usd),
          status: 'active',
        ),
        WalletAccount(
          id: 'sw_ngn_02',
          address: '0x2222222222222222222222222222222222222222',
          currency: Currency.ngn,
          stablecoinToken: 'CNGN',
          balance: Money.fromMajorString('6820000.00', Currency.ngn),
          status: 'active',
        ),
      ];

      final inspection = await repo.inspectBalances(
        intent: intent,
        wallets: testWallets,
      );

      expect(inspection.isPossible, true);
      expect(inspection.isDirectFunded, false, reason: 'Direct USD balance is only \$300, insufficient for \$500');
      expect(inspection.recommendedFundingOption, isNotNull);

      final rec = inspection.recommendedFundingOption!;
      expect(rec.fundingCurrency, Currency.ngn);
      expect(rec.requiresConversion, true);
      expect(rec.conversionLabel, 'NGN → USD');
      expect(rec.exchangeRate, 1550.0);
    });

    test('DemoTransferRepository: Proposal creation, on-device signing hash, and Activity logging', () async {
      final activityRepo = DemoActivityRepository();
      final repo = DemoTransferRepository(activityRepo: activityRepo);

      const intent = TransferIntent(
        intentId: 'tx_demo_02',
        originalPrompt: 'Send \$500 to my designer in Ghana',
        recipient: 'my designer in Ghana',
        amount: '500.00',
        amountMinor: '50000',
        currency: Currency.usd,
      );

      final fundingOption = TransferFundingOption(
        fundingWalletId: 'sw_ngn_02',
        fundingCurrency: Currency.ngn,
        fundingWalletName: 'NGN Smart Wallet',
        availableBalance: Money.fromMajorString('6820000.00', Currency.ngn),
        requiresConversion: true,
        conversionLabel: 'NGN → USD',
        exchangeRate: 1550.0,
        convertedDebit: Money.fromMajorString('775000.00', Currency.ngn),
        networkFee: Money.fromMajorString('775.00', Currency.ngn),
        fxFee: Money.fromMajorString('1162.50', Currency.ngn),
        totalDebit: Money.fromMajorString('776937.50', Currency.ngn),
        targetPayment: Money.fromMajorString('500.00', Currency.usd),
      );

      final proposal = await repo.createProposal(
        intent: intent,
        fundingOption: fundingOption,
      );

      expect(proposal.proposalId, startsWith('prop_demo_'));
      expect(proposal.hashToSign, startsWith('0x'));

      // Execute proposal
      final dummySig = '0x${'ab' * 65}';
      final execution = await repo.executeProposal(
        proposalId: proposal.proposalId,
        signature: dummySig,
        proposal: proposal,
      );

      expect(execution.status, 'COMPLETED');
      expect(execution.transactionHash, startsWith('0x'));

      // Verify that activity was persisted into ActivityRepository
      final recent = await activityRepo.getRecentActivities();
      expect(recent.any((a) => a.category == ActivityCategory.transfer), true);
    });
  });

  group('Send Money Screen Widget & User Flow Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('Renders Send Money screen with natural language entry, chips, and form fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: SendMoneyScreen(appState: appState),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Top Security Rail Header
      expect(find.text('FlowPay BMONI Rail'), findsOneWidget);
      expect(find.text('Natural Language Entry'), findsOneWidget);

      // Natural language text input
      expect(find.byKey(const Key('send_money_nl_input')), findsOneWidget);
      expect(find.byKey(const Key('send_money_analyze_button')), findsOneWidget);

      // Suggestion chips
      expect(find.text('Send \$500 to my designer in Ghana'), findsOneWidget);
      expect(find.text('Send \$150 to bunch.dillon@example.ng'), findsOneWidget);

      // Form fields
      expect(find.byKey(const Key('send_money_recipient_field')), findsOneWidget);
      expect(find.byKey(const Key('send_money_amount_field')), findsOneWidget);

      // Review Transfer CTA button
      expect(find.byKey(const Key('send_money_review_button')), findsOneWidget);
    });

    testWidgets('Tapping suggestion chip pre-fills fields and inspects balance-aware routing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: SendMoneyScreen(appState: appState),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Tap suggestion chip
      final chipFinder = find.byKey(const Key('chip_Send_\$500_to_my_designer_in_Ghana'));
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Recipient should be populated
      final recipientField = tester.widget<TextField>(find.byKey(const Key('send_money_recipient_field')));
      expect(recipientField.controller?.text, contains('designer'));

      // Amount should be 500.00
      final amountFieldFinder = find.descendant(
        of: find.byKey(const Key('send_money_amount_field')),
        matching: find.byType(TextField),
      );
      final amountField = tester.widget<TextField>(amountFieldFinder);
      expect(amountField.controller?.text, '500.00');

      // Balance-Aware auto-funding card should be present
      expect(find.byKey(const Key('balance_aware_funding_card')), findsOneWidget);
    });

    testWidgets('Full User Flow: Review Confirmation Modal -> "Nothing moves until you approve." -> Edit returns to form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: SendMoneyScreen(appState: appState),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Enter recipient & amount
      await tester.enterText(find.byKey(const Key('send_money_recipient_field')), 'my designer in Ghana');
      final amountFieldFinder = find.descendant(
        of: find.byKey(const Key('send_money_amount_field')),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountFieldFinder, '500.00');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Tap Review Transfer button
      final reviewButtonFinder = find.byKey(const Key('send_money_review_button'));
      await tester.tap(reviewButtonFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();


      // Premium Confirmation Screen (TransferReviewModal)
      expect(find.byType(TransferReviewModal), findsOneWidget);
      expect(find.text('Nothing moves until you approve.'), findsOneWidget);
      expect(find.text('Recipient'), findsOneWidget);
      expect(find.text('Funding Source'), findsOneWidget);
      expect(find.text('Conversion'), findsOneWidget);

      // Verify Buttons: Edit and Approve & Send
      expect(find.byKey(const Key('transfer_review_edit_button')), findsOneWidget);
      expect(find.byKey(const Key('transfer_review_approve_button')), findsOneWidget);

      // Tap Edit -> should dismiss review modal and return to form
      await tester.tap(find.byKey(const Key('transfer_review_edit_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(TransferReviewModal), findsNothing);
      expect(find.byKey(const Key('send_money_review_button')), findsOneWidget);
    });
  });
}

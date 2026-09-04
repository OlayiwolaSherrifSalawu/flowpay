import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/core/theme/theme.dart';
import 'package:flowpay_mobile/core/wallet/components/wallet_pin_auth_sheet.dart';
import 'package:flowpay_mobile/modules/personal/components/activity_detail_modal.dart';
import 'package:flowpay_mobile/modules/personal/personal_activity_screen.dart';

void main() {
  group('FlowPay Personal Activity Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets(
        'Renders Personal Activity Screen with all required items and attributes',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: PersonalActivityScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Check Search and Filter Chips
      expect(find.byType(TextField), findsOneWidget); // Search bar
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      expect(find.text('Conversions'), findsOneWidget);
      expect(find.text('Missions'), findsOneWidget);
      expect(find.text('Wallet Ops'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('Failures'), findsOneWidget);

      // 2. Check presence of core items and required fields
      // Type, Title, Recipient/Merchant, Reference, Status, Timestamp
      expect(find.text('Transfer to Designer in Ghana'), findsOneWidget);
      expect(find.text('Kofi Mensah (Ghana)'), findsOneWidget);
      expect(find.text('Ref: FP-TXN-884210'), findsOneWidget);
      expect(find.text('AWAITING APPROVAL'), findsWidgets);

      expect(find.text('Emergency Fund Auto-Sweep'), findsOneWidget);
      expect(find.text('High-Yield NGN Savings Vault'), findsOneWidget);
      expect(find.text('Ref: FP-SWEEP-9812'), findsOneWidget);
      expect(find.text('COMPLETED'), findsWidgets);

      expect(find.text('Transfer to Bunch Dillon'), findsOneWidget);
      expect(find.text('Bunch Dillon (Nigeria)'), findsOneWidget);
      expect(find.text('Ref: FP-TXN-0428'), findsOneWidget);

      expect(find.text('Virtual Card: AWS Cloud Services'), findsOneWidget);
      expect(find.text('AWS EMEA S.a.r.l.'), findsOneWidget);
      expect(find.text('Ref: FP-CRD-8812'), findsOneWidget);
    });

    testWidgets('Filters activity items by category tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: PersonalActivityScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Transfers" chip
      await tester.tap(find.text('Transfers'));
      await tester.pumpAndSettle();

      expect(find.text('Transfer to Bunch Dillon'), findsOneWidget);
      expect(find.text('Transfer to Samson Jabo'), findsOneWidget);
      expect(find.text('Virtual Card: AWS Cloud Services'), findsNothing);

      // Tap "Conversions" chip
      await tester.tap(find.text('Conversions'));
      await tester.pumpAndSettle();

      expect(find.text('Instant FX: USD → NGN'), findsOneWidget);
      expect(find.text('Transfer to Bunch Dillon'), findsNothing);

      // Tap "Pending Approvals" chip
      await tester.scrollUntilVisible(
        find.text('Pending Approvals'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Pending Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Transfer to Designer in Ghana'), findsOneWidget);
      expect(find.text('Tax Reserve 20% Auto-Sweep'), findsOneWidget);
      expect(find.text('Instant FX: USD → NGN'), findsNothing);

      // Tap "Failures" chip
      await tester.scrollUntilVisible(
        find.text('Failures'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Failures'));
      await tester.pumpAndSettle();

      expect(find.text('Contractor Card Cap Exceeded'), findsOneWidget);
      expect(find.text('Transfer to Vendor Failed'), findsOneWidget);
      expect(find.text('Transfer to Bunch Dillon'), findsNothing);
    });

    testWidgets('Searching filters items by counterparty or reference',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: PersonalActivityScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Bunch Dillon');
      await tester.pumpAndSettle();

      expect(find.text('Transfer to Bunch Dillon'), findsOneWidget);
      expect(find.text('Virtual Card: AWS Cloud Services'), findsNothing);

      // Search by reference
      await tester.enterText(find.byType(TextField), 'FP-FX-3319');
      await tester.pumpAndSettle();

      expect(find.text('Instant FX: USD → NGN'), findsOneWidget);
      expect(find.text('Transfer to Bunch Dillon'), findsNothing);
    });

    testWidgets(
        'Tapping activity item opens ActivityDetailModal with all required fields and privacy guarantee',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: PersonalActivityScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Transfer to Bunch Dillon
      await tester.tap(find.text('Transfer to Bunch Dillon'));
      await tester.pumpAndSettle();

      // Modal is visible
      expect(find.byType(ActivityDetailModal), findsOneWidget);
      expect(find.text('Transfer Details'), findsOneWidget);

      // Check required DETAIL fields:
      // amount, currency, source, destination, fee, exchange rate, timestamp, FlowPay reference, BMONI reference
      expect(find.text('TRANSACTION AMOUNT'), findsOneWidget);
      expect(find.text('150'), findsWidgets);
      expect(find.text('Currency'), findsOneWidget);
      expect(find.textContaining('USDB'), findsWidgets);
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Personal Smart Wallet (USDB)'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Bunch Dillon (0x71C...9a19)'), findsOneWidget);
      expect(find.text('Network Fee'), findsOneWidget);
      expect(find.text('Exchange Rate'), findsOneWidget);
      expect(find.text('N/A (Direct Currency)'), findsOneWidget);
      expect(find.text('Timestamp'), findsOneWidget);
      expect(find.text('FlowPay Reference'), findsOneWidget);
      expect(find.text('FP-TXN-0428'), findsWidgets);
      expect(find.text('BMONI Reference'), findsOneWidget);
      expect(find.text('0x3a92b77...deterministic'), findsOneWidget);

      // Verify privacy & non-exposure reassurance:
      expect(find.text('Verified by On-Device B-Key Signer'), findsOneWidget);
      expect(find.textContaining('Zero AI money movement'), findsOneWidget);

      // Verify private keys and API credentials are NEVER exposed
      expect(find.textContaining('privateKey'), findsNothing);
      expect(find.textContaining('private_key'), findsNothing);
      expect(find.textContaining('api_key'), findsNothing);
      expect(find.textContaining('secretKey'), findsNothing);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDetailModal), findsNothing);
    });

    testWidgets(
        'Approving a pending item via PIN authorizes and updates status to completed',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: PersonalActivityScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the first "Approve (PIN)" button on an item awaiting approval
      final approveBtn = find.text('Approve (PIN)').first;
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // PIN authorization sheet is displayed
      expect(find.byType(WalletPinAuthSheet), findsOneWidget);
      expect(find.text('Your FlowPay wallet is secured on this device.'),
          findsOneWidget);

      // Enter 6 digits on the PIN pad (123456)
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.byKey(Key('pin_key_$digit')));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();

      // Verify success snackbar / completion
      expect(find.textContaining('Action approved and signed via B-Key'),
          findsOneWidget);
    });
  });
}

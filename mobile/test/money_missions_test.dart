import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/modules/personal/components/mission_card.dart';
import 'package:flowpay_mobile/modules/personal/components/mission_preview_modal.dart';
import 'package:flowpay_mobile/modules/personal/money_missions_screen.dart';

void main() {
  group('Money Missions Flagship Feature Tests', () {
    testWidgets('Renders Money Missions screen with primary heading, input, and 5 suggestion chips',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyMissionsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Primary Heading & Tagline
      expect(find.text('Tell your money what to do.'), findsOneWidget);
      expect(
        find.textContaining('Set autonomous directives in plain English'),
        findsOneWidget,
      );

      // 2. Large Natural Language Input & Button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Interpret Directive'), findsOneWidget);

      // 3. 5 Suggested Action Chips
      expect(find.text('Split incoming payment'), findsOneWidget);
      expect(find.text('Save for a goal'), findsOneWidget);
      expect(find.text('Convert currency'), findsOneWidget);
      expect(find.text('Send money'), findsOneWidget);
      expect(find.text('Reserve for taxes'), findsOneWidget);

      // 4. Active Missions List
      expect(find.text('Active Missions'), findsOneWidget);
      expect(find.byType(MissionCard), findsWidgets);
    });

    testWidgets('Tapping suggestion chips prefills the natural language input field',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyMissionsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Save for a goal"
      await tester.tap(find.text('Save for a goal'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.controller?.text,
        contains('Whenever I receive \$1,500, save 25% into high-yield USD emergency vault.'),
      );

      // Tap "Split incoming payment"
      await tester.tap(find.text('Split incoming payment'));
      await tester.pumpAndSettle();

      final updatedField = tester.widget<TextField>(find.byType(TextField));
      expect(
        updatedField.controller?.text,
        contains(
            'Whenever I receive \$2,000, keep 30% in USD, convert 50% to Naira for expenses, and reserve 20% for tax.'),
      );
    });

    testWidgets(
        'Flagship Demo Flow: Natural language -> AI interpretation -> Structured intent -> Deterministic validation -> Preview -> Approval -> Signing -> Execution',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyMissionsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure input has the flagship prompt
      await tester.tap(find.text('Split incoming payment'));
      await tester.pumpAndSettle();

      // 1. Tap "Interpret Directive"
      await tester.tap(find.text('Interpret Directive'));
      await tester.pump();

      // Verify AI pipeline stages appear
      expect(find.text('Financial Safety AI Pipeline'), findsOneWidget);
      expect(find.text('AI understood request'), findsOneWidget);

      // Pump elapsed timers for AI stages & validation
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Plan created (structured intent)'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Deterministic validation passed (100% allocation)'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();

      // 2. Verify MissionPreviewModal is opened
      expect(find.byType(MissionPreviewModal), findsOneWidget);
      expect(find.text('Mission Plan Preview'), findsOneWidget);

      // Check header: "$2,000 incoming"
      expect(find.text('\$2,000 incoming'), findsOneWidget);
      expect(find.text('100% Allocated'), findsOneWidget);

      // Check 3 allocations:
      // USD Reserve (30% | $600)
      expect(find.text('USD Reserve'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('\$600'), findsOneWidget);

      // NGN Expenses (50% | $1,000 equivalent)
      expect(find.text('NGN Expenses'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('\$1,000 equivalent'), findsOneWidget);

      // Tax Reserve (20% | $400)
      expect(find.text('Tax Reserve'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('\$400'), findsOneWidget);

      // Invariant Reassurance Banner
      expect(find.text('Nothing moves until you approve.'), findsOneWidget);
      expect(
        find.text('Requires explicit authorization with your on-device B-Key PIN.'),
        findsOneWidget,
      );

      // Verify Edit and Approve buttons
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Approve Mission'), findsOneWidget);

      // 3. Tap "Approve Mission"
      await tester.tap(find.text('Approve Mission'));
      await tester.pumpAndSettle();

      // 4. Verify B-Key PIN Signing Sheet appears
      expect(find.text('Sign Money Mission'), findsOneWidget);
      expect(find.textContaining('Your FlowPay wallet is secured on this device'), findsOneWidget);

      // Enter 6-digit PIN: 123456
      await tester.tap(find.byKey(const Key('pin_key_1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_2')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_3')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_4')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_5')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_6')));
      await tester.pumpAndSettle();

      // 5. Verify Execution Celebration Dialog
      expect(find.text('Mission Activated & Signed!'), findsOneWidget);
      expect(find.text('BMONI B-Key PIN Verified'), findsOneWidget);
      expect(find.text('ACTIVE • Monitored'), findsOneWidget);

      // Dismiss celebration dialog
      await tester.tap(find.text('View Active Missions'));
      await tester.pumpAndSettle();

      // 6. Verify Mission appears in Active Missions list
      expect(find.text('Incoming 3-Way Split: USD, NGN Expenses & Tax'), findsOneWidget);
      expect(find.textContaining('⚡ Run Now'), findsWidgets);
    });

    testWidgets('Manual trigger on Active Mission prompts PIN and updates execution',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoneyMissionsScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find first "⚡ Run Now" button
      final runNowBtn = find.text('⚡ Run Now').first;
      await tester.tap(runNowBtn);
      await tester.pumpAndSettle();

      // Verify PIN entry sheet opens for test execution
      expect(find.text('Manual Test Execution'), findsOneWidget);

      // Enter PIN: 123456
      await tester.tap(find.byKey(const Key('pin_key_1')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_2')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_3')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_4')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_5')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('pin_key_6')));
      await tester.pumpAndSettle();

      // Verify success snackbar
      expect(
        find.textContaining('⚡ Mission triggered & executed successfully via BMONI rails!'),
        findsOneWidget,
      );
    });
  });
}

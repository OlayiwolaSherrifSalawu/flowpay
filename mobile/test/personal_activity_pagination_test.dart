import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/core/theme/theme.dart';
import 'package:flowpay_mobile/modules/personal/personal_activity_screen.dart';

void main() {
  group('PersonalActivityScreen Pagination Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('Renders 50 activities with 10/page and pagination navigation', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
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

      // 1. Pagination bar shows page 1 of 5
      expect(find.text('Showing 1–10 of 50 activities'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Prev'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Page 1 contains first item
      expect(find.text('Transfer to Designer in Ghana'), findsOneWidget);

      // 2. Navigate to Page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 11–20 of 50 activities'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);

      // 3. Search resets to page 1
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Designer');
      await tester.pumpAndSettle();

      expect(find.text('Transfer to Designer in Ghana'), findsOneWidget);
    });
  });
}

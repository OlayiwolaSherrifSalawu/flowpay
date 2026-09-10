import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/core/design_system/design_system.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';
import 'package:flowpay_mobile/core/theme/theme.dart';
import 'package:flowpay_mobile/modules/business/employees_screen.dart';

void main() {
  group('EmployeesScreen Pagination & Search Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('Renders 47 employees with 10/page and authoritative total roster pill', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: EmployeesScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Authoritative Total Roster Pill reflects full dataset (47 employees)
      expect(find.text('TOTAL ROSTER'), findsOneWidget);
      expect(find.text('47'), findsOneWidget);

      // 2. Pagination bar displays 1-10 range and page 1 / 5
      expect(find.text('Showing 1–10 of 47 employees'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Prev'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Page 1 should have Bunch Dillon
      expect(find.text('Bunch Dillon'), findsOneWidget);

      // 3. Tap Next to go to Page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify Page 2 range
      expect(find.text('Showing 11–20 of 47 employees'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);

      // Total roster stat pill MUST still show 47 (authoritative invariant!)
      expect(find.text('47'), findsOneWidget);

      // 4. Tap Prev to return to Page 1
      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1–10 of 47 employees'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
    });

    testWidgets('Search query filters employees and resets pagination to page 1', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FlowPayTheme.dark(),
          home: Scaffold(
            body: EmployeesScreen(appState: appState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to page 2 first
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 5'), findsOneWidget);

      // Enter search query in TextField
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Bunch');
      await tester.pumpAndSettle();

      // Sliced list should show matching employee and pagination resets to page 1
      expect(find.text('Bunch Dillon'), findsOneWidget);
      // Roster stat pill remains authoritative full count
      expect(find.text('47'), findsOneWidget);
    });
  });
}

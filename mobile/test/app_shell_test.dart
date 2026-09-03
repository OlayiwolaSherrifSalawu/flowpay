import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowpay_mobile/app.dart';
import 'package:flowpay_mobile/core/navigation/role_switcher.dart';
import 'package:flowpay_mobile/core/state/app_state.dart';

void main() {
  group('FlowPay Application Shell Tests', () {
    testWidgets('Initializes in Personal mode with unconfusing Role Switcher', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      // Brand Title
      expect(find.text('FLOWPAY'), findsOneWidget);

      // Role Switcher
      expect(find.byType(FlowPayRoleSwitcher), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);

      // Personal navigation tabs within bottom NavigationBar
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('Overview')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Wallets')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Send')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Missions')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Activity')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Security')), findsOneWidget);

      // Personal Dashboard content
      expect(find.text('Personal Account'), findsOneWidget);
      expect(find.text('Money Missions'), findsOneWidget);
    });

    testWidgets('Tapping Business in Role Switcher seamlessly transitions to Business Shell',
        (tester) async {
      final appState = AppState();

      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      // Tap "Business" on the role switcher pill
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();

      // Assert active role is business
      expect(appState.activeRole, AppRole.business);

      // Business navigation tabs within bottom NavigationBar
      final navBar = find.byType(NavigationBar);
      expect(find.descendant(of: navBar, matching: find.text('Overview')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Team')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Payroll')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Audit')), findsOneWidget);

      // Business Dashboard content
      expect(find.text('Business Dashboard'), findsOneWidget);
      expect(find.text('One Employer. Many Countries. One Bill.'), findsOneWidget);
    });

    testWidgets('Switches tabs cleanly in Business mode', (tester) async {
      final appState = AppState();
      appState.setRole(AppRole.business);

      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      final navBar = find.byType(NavigationBar);

      // Tap Team tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Team')));
      await tester.pumpAndSettle();
      expect(find.text('Global Team'), findsOneWidget);

      // Tap Payroll tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Payroll')));
      await tester.pumpAndSettle();
      expect(find.text('One Aggregate Bill'), findsOneWidget);

      // Tap Audit tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Audit')));
      await tester.pumpAndSettle();
      expect(find.text('Global Payroll Fan-Out'), findsOneWidget);
    });

    testWidgets('Switches tabs cleanly in Personal mode', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      final navBar = find.byType(NavigationBar);

      // Tap Wallets tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Wallets')));
      await tester.pumpAndSettle();
      expect(find.text('Secure Hardware Isolation'), findsOneWidget);

      // Tap Missions tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Missions')));
      await tester.pumpAndSettle();
      expect(find.text('Your money. Your rules. AI executes.'), findsOneWidget);

      // Tap Security tab in nav bar
      await tester.tap(find.descendant(of: navBar, matching: find.text('Security')));
      await tester.pumpAndSettle();
      expect(find.text('B-Key Hardware Enclave Active'), findsOneWidget);
    });

    testWidgets('Toggles theme mode dynamically', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(FlowPayApp(appState: appState));
      await tester.pumpAndSettle();

      expect(appState.isDarkMode, isTrue);

      appState.toggleTheme();
      await tester.pumpAndSettle();

      expect(appState.isDarkMode, isFalse);
      expect(appState.themeMode, ThemeMode.light);
    });
  });
}

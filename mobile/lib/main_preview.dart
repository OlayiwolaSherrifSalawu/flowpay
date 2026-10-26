// DEVELOPMENT ONLY — screen preview harness for design review.
//
//   flutter build web -t lib/main_preview.dart -o build/preview
//   open build/preview/index.html?screen=dashboard&theme=dark
//
// Renders a single screen with DEMO data (no backend, no keys, no money). This
// entrypoint is never used by the shipped app (lib/main.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/design_system.dart';
import 'core/state/app_state.dart';
import 'modules/business/business_activity_screen.dart';
import 'modules/business/business_dashboard_screen.dart';
import 'modules/business/employees_screen.dart';
import 'modules/business/payroll_screen.dart';
import 'modules/personal/cash_in_out_screen.dart';
import 'modules/personal/money_missions_screen.dart';
import 'modules/personal/personal_activity_screen.dart';
import 'modules/personal/personal_dashboard_screen.dart';
import 'modules/personal/personal_security_screen.dart';
import 'modules/personal/send_money_screen.dart';
import 'modules/personal/wallets_screen.dart';

void main() {
  final params = Uri.base.queryParameters;
  final appState = AppState(providerMode: ProviderMode.demo);
  final screens = <String, Widget Function()>{
    'dashboard': () => PersonalDashboardScreen(appState: appState),
    'wallets': () => WalletsScreen(appState: appState),
    'send': () => SendMoneyScreen(appState: appState),
    'missions': () => MoneyMissionsScreen(appState: appState),
    'activity': () => PersonalActivityScreen(appState: appState),
    'security': () => PersonalSecurityScreen(appState: appState),
    'bank': () => CashInOutScreen(appState: appState),
    'business': () => BusinessDashboardScreen(appState: appState),
    'team': () => EmployeesScreen(appState: appState),
    'payroll': () => PayrollScreen(appState: appState),
    'audit': () => BusinessActivityScreen(appState: appState),
  };
  final build = screens[params['screen']] ?? screens['dashboard']!;
  runApp(ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: FlowPayTheme.light(),
      darkTheme: FlowPayTheme.dark(),
      themeMode: params['theme'] == 'light' ? ThemeMode.light : ThemeMode.dark,
      home: Scaffold(body: build()),
    ),
  ));
}

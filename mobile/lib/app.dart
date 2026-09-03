import 'package:flutter/material.dart';
import 'core/state/app_state.dart';
import 'core/theme/colors.dart';
import 'core/theme/typography.dart';
import 'modules/business/business_activity_screen.dart';
import 'modules/business/business_dashboard_screen.dart';
import 'modules/business/employees_screen.dart';
import 'modules/business/payroll_screen.dart';
import 'modules/personal/money_missions_screen.dart';
import 'modules/personal/personal_activity_screen.dart';
import 'modules/personal/personal_dashboard_screen.dart';
import 'modules/personal/personal_security_screen.dart';
import 'modules/personal/wallets_screen.dart';

class FlowPayApp extends StatefulWidget {
  const FlowPayApp({Key? key}) : super(key: key);

  @override
  State<FlowPayApp> createState() => _FlowPayAppState();
}

class _FlowPayAppState extends State<FlowPayApp> {
  final AppState appState = AppState();
  int _personalIndex = 0;
  int _businessIndex = 0;

  @override
  void initState() {
    super.initState();
    appState.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = appState.activeRole == AppRole.personal;

    final personalScreens = [
      PersonalDashboardScreen(appState: appState),
      WalletsScreen(appState: appState),
      MoneyMissionsScreen(appState: appState),
      PersonalActivityScreen(appState: appState),
      PersonalSecurityScreen(appState: appState),
    ];

    final businessScreens = [
      BusinessDashboardScreen(appState: appState),
      EmployeesScreen(appState: appState),
      PayrollScreen(appState: appState),
      BusinessActivityScreen(appState: appState),
    ];

    return MaterialApp(
      title: 'FlowPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: FlowPayColors.background,
        primaryColor: FlowPayColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: FlowPayColors.primary,
          secondary: FlowPayColors.accent,
          surface: FlowPayColors.surface,
          background: FlowPayColors.background,
        ),
      ),
      home: Scaffold(
        drawer: Drawer(
          backgroundColor: FlowPayColors.surfaceElevated,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: FlowPayColors.surface),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('FLOWPAY', style: FlowPayTypography.headingLg),
                    const SizedBox(height: 4),
                    Text(
                      'Your money. Your rules. AI executes.',
                      style: FlowPayTypography.caption.copyWith(color: FlowPayColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: FlowPayColors.primaryLight),
                title: const Text('Role: Personal / Business'),
                subtitle: Text(
                  isPersonal ? 'Active: Personal Mode' : 'Active: Business Mode',
                  style: const TextStyle(color: FlowPayColors.textSecondary),
                ),
                onTap: () {
                  appState.setRole(isPersonal ? AppRole.business : AppRole.personal);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: FlowPayColors.border),
              ListTile(
                leading: Icon(
                  Icons.layers_outlined,
                  color: appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
                ),
                title: const Text('Provider Mode'),
                subtitle: Text(
                  appState.isDemo ? '● Deterministic Demo' : '● BMONI Sandbox Live',
                  style: TextStyle(
                    color: appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: !appState.isDemo,
                  activeColor: FlowPayColors.accent,
                  onChanged: (val) {
                    appState.setProviderMode(val ? ProviderMode.bmoniSandbox : ProviderMode.demo);
                  },
                ),
              ),
            ],
          ),
        ),
        body: isPersonal ? personalScreens[_personalIndex] : businessScreens[_businessIndex],
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: FlowPayColors.surface,
            indicatorColor: FlowPayColors.primary.withOpacity(0.2),
            labelTextStyle: MaterialStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: FlowPayColors.textSecondary),
            ),
          ),
          child: isPersonal
              ? NavigationBar(
                  selectedIndex: _personalIndex,
                  onDestinationSelected: (i) => setState(() => _personalIndex = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: FlowPayColors.primaryLight),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet, color: FlowPayColors.primaryLight),
                      label: 'Wallets',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bolt_outlined),
                      selectedIcon: Icon(Icons.bolt, color: FlowPayColors.primaryLight),
                      label: 'Missions',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history, color: FlowPayColors.primaryLight),
                      label: 'Activity',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.shield_outlined),
                      selectedIcon: Icon(Icons.shield, color: FlowPayColors.primaryLight),
                      label: 'Security',
                    ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: _businessIndex,
                  onDestinationSelected: (i) => setState(() => _businessIndex = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard, color: FlowPayColors.primaryLight),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people, color: FlowPayColors.primaryLight),
                      label: 'Team',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.payments_outlined),
                      selectedIcon: Icon(Icons.payments, color: FlowPayColors.primaryLight),
                      label: 'Payroll',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long, color: FlowPayColors.primaryLight),
                      label: 'Audit',
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

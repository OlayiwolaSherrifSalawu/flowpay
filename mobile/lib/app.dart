import 'package:flutter/material.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/theme/components.dart';
import 'core/theme/radii.dart';
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
      theme: FlowPayTheme.lightTheme,
      home: Scaffold(
        backgroundColor: FlowPayColors.canvas,
        appBar: AppBar(
          backgroundColor: FlowPayColors.canvas,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 16,
          title: Row(
            children: [
              Text(
                'FlowPay',
                style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 12),
              SegmentedRoleSwitch(
                isPersonal: isPersonal,
                onRoleChanged: (personal) {
                  appState.setRole(personal ? AppRole.personal : AppRole.business);
                },
              ),
            ],
          ),
          actions: [
            if (appState.isDemo) ...[
              const Center(child: DemoPill()),
              const SizedBox(width: 8),
            ],
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.tune_rounded, color: FlowPayColors.ink),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                tooltip: 'Settings & Environment',
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        endDrawer: Drawer(
          backgroundColor: FlowPayColors.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: FlowPayColors.surfaceAlt),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FLOWPAY',
                      style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'One Employer. Many Countries. One Bill.',
                      style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: FlowPayColors.ink),
                title: const Text('Active Surface', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  isPersonal ? 'Personal Wallet & Missions' : 'Business Multi-Rail Payroll',
                  style: const TextStyle(color: FlowPayColors.textSecondary),
                ),
                trailing: SegmentedRoleSwitch(
                  isPersonal: isPersonal,
                  onRoleChanged: (personal) {
                    appState.setRole(personal ? AppRole.personal : AppRole.business);
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(color: FlowPayColors.hairline),
              ListTile(
                leading: Icon(
                  Icons.layers_outlined,
                  color: appState.isDemo ? FlowPayColors.amber : FlowPayColors.signal,
                ),
                title: const Text('Provider Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  appState.isDemo ? '● Deterministic Demo Mode' : '● BMONI Live Sandbox',
                  style: TextStyle(
                    color: appState.isDemo ? const Color(0xFFB45309) : FlowPayColors.signal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: !appState.isDemo,
                  activeColor: FlowPayColors.signal,
                  onChanged: (val) {
                    appState.setProviderMode(val ? ProviderMode.bmoniSandbox : ProviderMode.demo);
                  },
                ),
              ),
              const Divider(color: FlowPayColors.hairline),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FlowPayColors.surfaceAlt,
                    borderRadius: FlowPayRadii.input,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BMONI Rails Active',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FlowPayColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nigeria (NGN / CNGN)\nMexico (MXN / MEXe)\nCanada (CAD / CADC)',
                        style: FlowPayTypography.captionStyle(color: FlowPayColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        body: isPersonal ? personalScreens[_personalIndex] : businessScreens[_businessIndex],
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: FlowPayColors.hairline, width: 1)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: FlowPayColors.surface,
              indicatorColor: FlowPayColors.ink.withOpacity(0.08),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FlowPayColors.ink,
                  );
                }
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FlowPayColors.textSecondary,
                );
              }),
            ),
            child: isPersonal
                ? NavigationBar(
                    selectedIndex: _personalIndex,
                    onDestinationSelected: (i) => setState(() => _personalIndex = i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded, color: FlowPayColors.ink),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: FlowPayColors.ink),
                        label: 'Wallets',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bolt_outlined),
                        selectedIcon: Icon(Icons.bolt_rounded, color: FlowPayColors.ink),
                        label: 'Missions',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history_rounded, color: FlowPayColors.ink),
                        label: 'Activity',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.shield_outlined),
                        selectedIcon: Icon(Icons.shield_rounded, color: FlowPayColors.ink),
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
                        selectedIcon: Icon(Icons.dashboard_rounded, color: FlowPayColors.ink),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded, color: FlowPayColors.ink),
                        label: 'Team',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.payments_outlined),
                        selectedIcon: Icon(Icons.payments_rounded, color: FlowPayColors.ink),
                        label: 'Payroll',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded, color: FlowPayColors.ink),
                        label: 'Audit',
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

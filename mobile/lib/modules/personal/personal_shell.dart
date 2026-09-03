import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/navigation/personal_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';

/// Independent Navigation Shell for Personal Account Mode.
/// Maintains its own navigation stack, active tab state, and app bar.
class PersonalShell extends ConsumerStatefulWidget {
  final AppState? appState;

  const PersonalShell({super.key, this.appState});

  @override
  ConsumerState<PersonalShell> createState() => _PersonalShellState();
}

class _PersonalShellState extends ConsumerState<PersonalShell> {
  int _currentIndex = 0;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: FlowPayColors.ink),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Revolut-style Segmented Role Switch
            SegmentedRoleSwitch(
              activeRole: AppRole.personal,
              onRoleChanged: (newRole) {
                ref.read(appLockStateProvider.notifier).setAccountMode(
                      newRole == AppRole.business
                          ? AccountMode.business
                          : AccountMode.personal,
                    );
              },
            ),
            const SizedBox(width: 8),
            const DemoPill(),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, color: FlowPayColors.ink, size: 20),
            tooltip: 'Lock FlowPay',
            onPressed: () {
              ref.read(appLockStateProvider.notifier).lockApp();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(context),
      body: PersonalRoutes.buildScreen(_currentIndex, _appState),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: FlowPayColors.surface,
          border: Border(
            top: BorderSide(color: FlowPayColors.hairline, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: FlowPayColors.surface,
          indicatorColor: FlowPayColors.surfaceAlt,
          elevation: 0,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: FlowPayColors.ink),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: FlowPayColors.ink),
              label: 'Wallets',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: FlowPayColors.ink),
              label: 'Missions',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: FlowPayColors.ink),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.security_outlined),
              selectedIcon: Icon(Icons.security, color: FlowPayColors.ink),
              label: 'Security',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: FlowPayColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: FlowPayColors.surfaceAlt),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: FlowPayColors.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt, color: FlowPayColors.amber, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'FLOWPAY',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: FlowPayColors.ink,
                      ),
                    ),
                    const Text(
                      'Personal Account',
                      style: TextStyle(fontSize: 12, color: FlowPayColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: FlowPayColors.ink),
              title: const Text('Switch to Business Mode'),
              onTap: () {
                Navigator.pop(context);
                ref.read(appLockStateProvider.notifier).setAccountMode(AccountMode.business);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: FlowPayColors.ink),
              title: const Text('Lock App Now'),
              onTap: () {
                Navigator.pop(context);
                ref.read(appLockStateProvider.notifier).lockApp();
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'FlowPay v1.0.0 (BMONI Infrastructure)',
                style: TextStyle(fontSize: 11, color: FlowPayColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

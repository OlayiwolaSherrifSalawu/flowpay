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
    final capabilitiesAsync = ref.watch(accountCapabilitiesProvider);
    final hasBothModes = capabilitiesAsync.asData?.value.hasBothModes ?? true;

    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: hasBothModes
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Revolut-style Segmented Role Switch
                  SegmentedRoleSwitch(
                    isPersonal: true,
                    onRoleChanged: (isPersonal) {
                      ref.read(appLockStateProvider.notifier).setAccountMode(
                            isPersonal ? AccountMode.personal : AccountMode.business,
                          );
                    },
                  ),
                  const SizedBox(width: 8),
                  const PoweredByBmoniBadge(),
                ],
              )
            : const PoweredByBmoniBadge(),
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
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt, color: FlowPayColors.ink),
              label: 'Missions',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: FlowPayColors.ink),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield, color: FlowPayColors.ink),
              label: 'Security',
            ),
          ],
        ),
      ),
    );
  }
}

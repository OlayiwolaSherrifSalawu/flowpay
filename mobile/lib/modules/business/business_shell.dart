import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/account_capabilities.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/navigation/business_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/design_system/logo.dart';

/// Independent Navigation Shell for Business Account Mode.
/// Maintains its own navigation stack, active tab state, and app bar.
class BusinessShell extends ConsumerStatefulWidget {
  final AppState? appState;

  const BusinessShell({super.key, this.appState});

  @override
  ConsumerState<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends ConsumerState<BusinessShell> {
  int _currentIndex = 0;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capabilitiesAsync = ref.watch(accountCapabilitiesProvider);
    final capabilities = capabilitiesAsync.asData?.value;
    final hasBothModes = capabilities?.hasBothModes ?? true;

    final bgColor = isDark
        ? FlowPayColors.darkBackground
        : FlowPayColors.lightBackground;
    final surfaceColor = isDark
        ? FlowPayColors.darkSurface
        : FlowPayColors.lightSurface;
    final borderColor = isDark
        ? FlowPayColors.darkBorder
        : FlowPayColors.lightBorder;
    final iconColor = isDark
        ? FlowPayColors.darkTextPrimary
        : FlowPayColors.ink;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.mint100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.emerald400.withAlpha(80),
                  width: 1,
                ),
              ),
              child: const Center(
                child: FlowPayLogo(size: 20),
              ),
            ),
          ),
        ),
        leadingWidth: 54,
        title: hasBothModes
            ? SegmentedRoleSwitch(
                isPersonal: false,
                onRoleChanged: (isPersonal) {
                  ref.read(appLockStateProvider.notifier).setAccountMode(
                        isPersonal
                            ? AccountMode.personal
                            : AccountMode.business,
                      );
                },
              )
            : null,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.lock_outline_rounded,
                    color: iconColor, size: 18),
                tooltip: 'Lock FlowPay',
                onPressed: () {
                  ref.read(appLockStateProvider.notifier).lockApp();
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.logout_rounded,
                    color: iconColor, size: 18),
                tooltip: 'Log Out',
                onPressed: () {
                  ref.read(appLockStateProvider.notifier).logout();
                },
              ),
            ),
          ),
        ],
      ),
      body: BusinessRoutes.buildScreen(_currentIndex, _appState),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            backgroundColor: surfaceColor,
            indicatorColor: isDark
                ? FlowPayColors.emerald600.withAlpha(50)
                : FlowPayColors.mint100,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark
                        ? FlowPayColors.emerald400
                        : FlowPayColors.emerald700)
                    : (isDark
                        ? FlowPayColors.darkTextTertiary
                        : FlowPayColors.lightTextTertiary),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected
                    ? (isDark
                        ? FlowPayColors.emerald400
                        : FlowPayColors.emerald600)
                    : (isDark
                        ? FlowPayColors.darkTextTertiary
                        : FlowPayColors.lightTextTertiary),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: surfaceColor,
            elevation: 0,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Team',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Payroll',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Activity',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

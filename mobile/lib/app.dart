import 'package:flutter/material.dart';
import 'core/design_system/design_system.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/business_routes.dart';
import 'core/navigation/personal_routes.dart';
import 'core/navigation/role_switcher.dart';
import 'core/state/app_state.dart';
import 'modules/personal/ai_operator_modal.dart';

class FlowPayApp extends StatefulWidget {
  final AppState? appState;

  const FlowPayApp({super.key, this.appState});

  @override
  State<FlowPayApp> createState() => _FlowPayAppState();
}

class _FlowPayAppState extends State<FlowPayApp> {
  late final AppState _appState;
  int _personalIndex = 0;
  int _businessIndex = 0;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
    _appState.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    if (widget.appState == null) {
      _appState.dispose();
    }
    super.dispose();
  }

  void _showProviderSettings(BuildContext context) {
    showFlowPayBottomSheet(
      context: context,
      title: 'Environment & Provider Settings',
      subtitle: 'Manage sandbox execution mode & appearance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Provider Mode Toggle
          FlowPayCard(
            variant: FlowPayCardVariant.elevated,
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: _appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Provider Mode', style: FlowPayTypography.headingSm),
                      Text(
                        _appState.isDemo ? 'Deterministic Demo Sandbox' : 'Live BMONI REST Rails',
                        style: FlowPayTypography.caption.copyWith(
                          color: _appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: !_appState.isDemo,
                  activeTrackColor: FlowPayColors.accent,
                  onChanged: (val) {
                    _appState.setProviderMode(
                      val ? ProviderMode.bmoniSandbox : ProviderMode.demo,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.md),

          // Theme Mode Toggle
          FlowPayCard(
            variant: FlowPayCardVariant.elevated,
            child: Row(
              children: [
                Icon(
                  _appState.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: FlowPayColors.primaryLight,
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Mode', style: FlowPayTypography.headingSm),
                      Text(
                        _appState.isDarkMode ? 'BMoni Deep Plum Obsidian' : 'Fintech Crisp Light',
                        style: FlowPayTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_appState.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => _appState.toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: FlowPaySpacing.lg),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = _appState.activeRole == AppRole.personal;
    final activeColor = isPersonal ? FlowPayColors.primary : FlowPayColors.accent;

    return MaterialApp(
      title: 'FlowPay',
      debugShowCheckedModeBanner: false,
      themeMode: _appState.themeMode,
      theme: FlowPayTheme.light(),
      darkTheme: FlowPayTheme.dark(),
      onGenerateRoute: (settings) => FlowPayRouter.onGenerateRoute(settings, _appState),
      home: Scaffold(
        appBar: AppBar(
          titleSpacing: FlowPaySpacing.md,
          title: Row(
            children: [
              // Logo text with subtle dot
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FLOWPAY',
                    style: FlowPayTypography.headingSm.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Prominent Role Switcher in header
              FlowPayRoleSwitcher(
                activeRole: _appState.activeRole,
                onRoleChanged: (role) => _appState.setRole(role),
              ),
            ],
          ),
          actions: [
            // AI Assistant action
            IconButton(
              icon: const Icon(Icons.psychology_outlined, color: FlowPayColors.primaryLight),
              tooltip: 'AI Financial Operator',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AiOperatorModal(appState: _appState),
                );
              },
            ),
            // Provider / Theme settings sheet button
            IconButton(
              icon: Icon(
                Icons.tune,
                size: 20,
                color: _appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
              ),
              tooltip: 'Environment Settings',
              onPressed: () => _showProviderSettings(context),
            ),
            const SizedBox(width: FlowPaySpacing.xs),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isPersonal
              ? KeyedSubtree(
                  key: const ValueKey('personal_view'),
                  child: PersonalRoutes.buildScreen(_personalIndex, _appState),
                )
              : KeyedSubtree(
                  key: const ValueKey('business_view'),
                  child: BusinessRoutes.buildScreen(_businessIndex, _appState),
                ),
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: activeColor.withAlpha(35),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPersonal ? FlowPayColors.primaryLight : FlowPayColors.accentLight,
                );
              }
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              );
            }),
          ),
          child: isPersonal
              ? NavigationBar(
                  selectedIndex: _personalIndex,
                  onDestinationSelected: (i) => setState(() => _personalIndex = i),
                  destinations: PersonalRoutes.destinations.map((d) {
                    return NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon, color: FlowPayColors.primaryLight),
                      label: d.label,
                    );
                  }).toList(),
                )
              : NavigationBar(
                  selectedIndex: _businessIndex,
                  onDestinationSelected: (i) => setState(() => _businessIndex = i),
                  destinations: BusinessRoutes.destinations.map((d) {
                    return NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon, color: FlowPayColors.accentLight),
                      label: d.label,
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/repositories/activity_repository.dart';
import '../../core/repositories/approval_repository.dart';
import '../../core/repositories/wallet_repository.dart';
import 'components/pending_approvals_card.dart';
import 'personal_activity_screen.dart';

import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/state/app_state.dart';
import '../../core/state/personal_provider.dart';
import 'ai_operator_modal.dart';
import 'components/ai_allocation_modal.dart';
import 'components/ai_command_bar.dart';
import 'components/ai_fx_conversion_modal.dart';
import 'money_missions_screen.dart';
import 'personal_shell.dart';
import 'send_money_screen.dart';
import 'wallet_provisioning_screen.dart';
import 'wallets_screen.dart';
import '../../core/navigation/personal_tab_provider.dart';

/// FLOWPAY — PERSONAL DASHBOARD
///
/// Route/Screen: Personal Dashboard
/// Tagline: "Your money. Your rules. AI executes."
///
/// Features:
/// - Total portfolio value & available balances (no fake precision, sandbox identified)
/// - Multi-currency wallet summaries (USD, NGN, MXN, CAD) using shared components
/// - AI Command interaction ("What should your money do?")
/// - Task-specific financial workflows (Allocation, Send, FX Convert)
/// - Pending Approvals queue with on-device B-Key PIN signing
/// - Active Money Missions summary with live toggling
/// - Shared Activity model transaction history
/// - Architecture powered by PersonalProvider decoupling data from widgets
class PersonalDashboardScreen extends StatefulWidget {
  final AppState appState;

  const PersonalDashboardScreen({super.key, required this.appState});

  @override
  State<PersonalDashboardScreen> createState() =>
      _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  late final PersonalProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.appState.personalProvider;
    _provider.loadDashboard();
  }

  void _openAiAllocationModal({Money? amount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiAllocationModal(
        personalProvider: _provider,
        initialAmount: amount ?? Money.fromMajorString('2000.00', Currency.usd),
      ),
    );
  }

  void _openAiFxConversionModal({Money? amount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiFxConversionModal(
        personalProvider: _provider,
        initialAmount: amount ?? Money.fromMajorString('1000.00', Currency.usd),
      ),
    );
  }

  void _navigateToTab(int tabIndex,
      {required Widget fallbackScreen, required String routeName}) {
    widget.appState.setPersonalTabIndex(tabIndex);
    final hasShell =
        context.findAncestorWidgetOfExactType<PersonalShell>() != null;
    if (!hasShell) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => fallbackScreen,
          settings: RouteSettings(name: routeName),
        ),
      );
    }
  }

  void _openSendMoneyScreen({String? initialAmount, String? initialRecipient}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendMoneyScreen(appState: widget.appState),
        settings: const RouteSettings(name: AppRoutes.personalSendMoney),
      ),
    );
  }

  void _openAiOperatorModal(String customPrompt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiOperatorModal(
        appState: widget.appState,
        initialPrompt: customPrompt,
      ),
    );
  }

  Future<void> _handleApprove(PendingApprovalModel approval, String pin) async {
    try {
      final success = await _provider.approveAction(approval.id, pin: pin);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Action approved and signed: ${approval.title}'),
            backgroundColor: FlowPayColors.primary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed: $e'), backgroundColor: FlowPayColors.error),
      );
    }
  }

  Future<void> _handleReject(PendingApprovalModel approval) async {
    await _provider.rejectAction(approval.id, reason: 'Dismissed by user');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action dismissed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final totalPortfolio = _provider.totalPortfolioUsd;
        final totalFormatted =
            totalPortfolio.formatFormatted(includeSymbol: true);
        final wholePart = totalFormatted.split('.')[0];
        final decimalPart = '.${totalPortfolio.toMajorString().split('.')[1]}';

        Widget content = RefreshIndicator(
          onRefresh: _provider.refresh,
          color: FlowPayColors.primary,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Header Subtitle & Status Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Personal Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? Colors.white
                                    : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                            // Clear Sandbox / Demo Indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? FlowPayColors.emerald600.withAlpha(40)
                                    : FlowPayColors.mint100,
                                borderRadius: FlowPayRadii.chip,
                                border: Border.all(
                                  color: isDark
                                      ? FlowPayColors.emerald400.withAlpha(80)
                                      : FlowPayColors.emerald600.withAlpha(50),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.appState.isDemo
                                    ? 'Sandbox Demo'
                                    : 'Live Network',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? FlowPayColors.emerald400
                                      : FlowPayColors.emerald700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Your money. Your rules. AI executes.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FlowPayColors.emerald400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WalletProvisioningScreen()),
                      );
                    },
                    borderRadius: FlowPayRadii.chip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? FlowPayColors.darkSurfaceElevated
                            : FlowPayColors.mint100,
                        borderRadius: FlowPayRadii.chip,
                        border: Border.all(
                          color: isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.emerald400.withAlpha(60),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: isDark
                                ? FlowPayColors.emerald400
                                : FlowPayColors.emerald700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Secure wallet',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Premium Scalloped Card Hero
              FlowPayScallopedCard(
                title: 'Total balance',
                balance: totalFormatted,
                holderName: 'Waffiyyi Fashola',
                expiryDate: '',
                actionLabel: 'Details',
                onActionTap: () {
                  _navigateToTab(
                    PersonalTab.wallets,
                    fallbackScreen: WalletsScreen(appState: widget.appState),
                    routeName: AppRoutes.personalWallets,
                  );
                },
                customContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total balance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD8F0E4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    BMoniWalletCardBalance(
                      wholePart: wholePart,
                      decimalPart: decimalPart,
                      isHidden: _provider.isBalanceHidden,
                      onToggleHidden: _provider.toggleBalanceVisibility,
                      balanceColor: Colors.white,
                      decimalColor: FlowPayColors.mint100,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _provider.secondaryValuationNgn,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD8F0E4),
                          ),
                        ),
                        Text(
                          '${_provider.availableBalanceUsd.formatFormatted(includeSymbol: true)} available',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Dribbble-inspired Quick Actions Row
              FlowPayQuickActionRow(
                customItems: [
                  QuickActionItem(
                    label: 'Create Mission',
                    icon: Icons.bolt_rounded,
                    onTap: () {
                      _navigateToTab(
                        PersonalTab.missions,
                        fallbackScreen:
                            MoneyMissionsScreen(appState: widget.appState),
                        routeName: AppRoutes.personalMissions,
                      );
                    },
                  ),
                  QuickActionItem(
                    label: 'Send Money',
                    icon: Icons.arrow_outward_rounded,
                    onTap: () => _openSendMoneyScreen(),
                  ),
                  QuickActionItem(
                    label: 'View Wallets',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      _navigateToTab(
                        PersonalTab.wallets,
                        fallbackScreen:
                            WalletsScreen(appState: widget.appState),
                        routeName: AppRoutes.personalWallets,
                      );
                    },
                  ),
                   QuickActionItem(
                    label: 'Ask AI',
                    icon: Icons.auto_awesome_rounded,
                    onTap: () =>
                        _openAiOperatorModal("What should your money do?"),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Money Missions Feature Card
              InkWell(
                onTap: () {
                  _navigateToTab(
                    PersonalTab.missions,
                    fallbackScreen:
                        MoneyMissionsScreen(appState: widget.appState),
                    routeName: AppRoutes.personalMissions,
                  );
                },
                borderRadius: FlowPayRadii.cardLarge,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.lightSurface,
                    borderRadius: FlowPayRadii.cardLarge,
                    border: Border.all(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.lightBorder,
                      width: 1,
                    ),
                    boxShadow: isDark
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x0A0F1712),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.emerald600.withAlpha(40)
                              : FlowPayColors.mint100,
                          borderRadius: FlowPayRadii.quickAction,
                          border: Border.all(
                            color: isDark
                                ? FlowPayColors.emerald400.withAlpha(80)
                                : FlowPayColors.emerald600.withAlpha(50),
                          ),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: isDark
                              ? FlowPayColors.emerald400
                              : FlowPayColors.emerald600,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Money Missions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '"Your money. Your rules. AI executes."',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: FlowPayColors.emerald400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: FlowPayColors.emerald400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Financial Pulse Metric Pills (Available vs Active Missions)
              FlowPayIncomeExpenseRow(
                incomeLabel: 'Available Balance',
                incomeAmount: _provider.availableBalanceUsd
                    .formatFormatted(includeSymbol: true),
                expenseLabel: 'Active Missions',
                expenseAmount:
                    '${_provider.activeMissionCount} Active',
                onIncomeTap: () {
                  _navigateToTab(
                    PersonalTab.wallets,
                    fallbackScreen: WalletsScreen(appState: widget.appState),
                    routeName: AppRoutes.personalWallets,
                  );
                },
                onExpenseTap: () {
                  _navigateToTab(
                    PersonalTab.missions,
                    fallbackScreen:
                        MoneyMissionsScreen(appState: widget.appState),
                    routeName: AppRoutes.personalMissions,
                  );
                },
              ),
              const SizedBox(height: 16),

              // 5. Primary AI Interaction ("What should your money do?")
              AiCommandBar(
                onCommandSubmit: (prompt) => _openAiOperatorModal(prompt),
                onAllocateTap: () => _openAiAllocationModal(
                  amount: Money.fromMajorString('2000.00', Currency.usd),
                ),
                onSendMoneyTap: () => _openSendMoneyScreen(
                  initialAmount: '500.00',
                  initialRecipient: 'samson.jabo@example.mx',
                ),
                onConvertTap: () => _openAiFxConversionModal(
                  amount: Money.fromMajorString('1000.00', Currency.usd),
                ),
              ),
              // 6. Pending Approvals Queue (Highlighted when actions need explicit signature)
              if (_provider.pendingApprovals.isNotEmpty)
                PendingApprovalsCard(
                  pendingApprovals: _provider.pendingApprovals,
                  onApprove: _handleApprove,
                  onReject: _handleReject,
                ),
              const SizedBox(height: 14),

              // 6. Active Strategy Rules Section
              SectionHeader(
                title: 'Active Strategy Rules',
                backgroundColor: Colors.transparent,
                showBottomDivider: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                titleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                ),
                trailing: TextButton(
                  onPressed: () {
                    _navigateToTab(
                      PersonalTab.missions,
                      fallbackScreen:
                          MoneyMissionsScreen(appState: widget.appState),
                      routeName: AppRoutes.personalMissions,
                    );
                  },
                  child: Text(
                    'Manage (${_provider.activeMissionCount} Active)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              ..._provider.missions.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isDark ? FlowPayColors.darkSurface : Colors.white,
                    borderRadius: FlowPayRadii.cardSmall,
                    border: Border.all(
                      color: m.isActive
                          ? (isDark
                              ? FlowPayColors.emerald400.withAlpha(90)
                              : FlowPayColors.emerald600.withAlpha(90))
                          : (isDark
                              ? FlowPayColors.darkBorder
                              : FlowPayColors.lightBorder),
                      width: m.isActive ? 1.5 : 1,
                    ),
                    boxShadow: isDark
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x0A0F1712),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: m.isActive
                              ? (isDark
                                  ? FlowPayColors.emerald600.withAlpha(40)
                                  : FlowPayColors.mint100)
                              : (isDark
                                  ? FlowPayColors.darkSurfaceElevated
                                  : FlowPayColors.lightSurfaceElevated),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 18,
                          color: m.isActive
                              ? (isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald700)
                              : (isDark
                                  ? FlowPayColors.darkTextSecondary
                                  : FlowPayColors.lightTextSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.stats,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: FlowPayColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: m.isActive,
                        activeThumbColor: FlowPayColors.primary,
                        onChanged: (_) => _provider.toggleMission(m.id),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // 7. Active Multi-Currency Wallets Section
              SectionHeader(
                title: 'Multi-Currency Smart Wallets',
                backgroundColor: Colors.transparent,
                showBottomDivider: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                titleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                ),
                trailing: TextButton(
                  onPressed: () {
                    _navigateToTab(
                      PersonalTab.wallets,
                      fallbackScreen: WalletsScreen(appState: widget.appState),
                      routeName: AppRoutes.personalWallets,
                    );
                  },
                  child: const Text(
                    'View All (4)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Wallets breakdown
              ..._provider.wallets.map((w) {
                return _WalletSummaryCard(
                  wallet: w,
                  isDark: isDark,
                  onCopyAddress: () {
                    Clipboard.setData(ClipboardData(text: w.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Copied ${w.currency.code} address: ${w.address}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 16),

              // 8. Recent Activity Section
              SectionHeader(
                title: 'Recent Activity',
                backgroundColor: Colors.transparent,
                showBottomDivider: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                titleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                ),
                trailing: TextButton(
                  onPressed: () {
                    _navigateToTab(
                      PersonalTab.activity,
                      fallbackScreen:
                          PersonalActivityScreen(appState: widget.appState),
                      routeName: AppRoutes.personalActivity,
                    );
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.primaryLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              ..._provider.recentActivities.take(5).map((act) {
                IconData catIcon = Icons.history;
                if (act.category == ActivityCategory.mission) {
                  catIcon = Icons.bolt;
                }
                if (act.category == ActivityCategory.transfer) {
                  catIcon = Icons.arrow_outward;
                }
                if (act.category == ActivityCategory.card) {
                  catIcon = Icons.credit_card;
                }
                if (act.category == ActivityCategory.fx) {
                  catIcon = Icons.currency_exchange;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? FlowPayColors.darkSurface : Colors.white,
                    borderRadius: FlowPayRadii.cardSmall,
                    border: Border.all(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.lightBorder,
                    ),
                    boxShadow: isDark
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x0A0F1712),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.emerald600.withAlpha(35)
                              : FlowPayColors.mint100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          catIcon,
                          size: 16,
                          color: isDark
                              ? FlowPayColors.emerald400
                              : FlowPayColors.emerald700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white : FlowPayColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? FlowPayColors.darkTextSecondary
                                    : FlowPayColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FlowPayStatusBadge(
                            appStatus: act.status,
                            showDot: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            act.timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? FlowPayColors.darkTextSecondary
                                  : FlowPayColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );

        if (canPop) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Personal Dashboard'),
            ),
            body: content,
          );
        }

        return content;
      },
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  final WalletAccount wallet;
  final bool isDark;
  final VoidCallback onCopyAddress;

  const _WalletSummaryCard({
    required this.wallet,
    required this.isDark,
    required this.onCopyAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : Colors.white,
        borderRadius: FlowPayRadii.cardSmall,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F1712),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FlowPayCurrencyDisplay(
              code: wallet.currency.code,
              symbol: wallet.currency.symbol,
              name: wallet.currency.name,
              tokenName: 'Active',
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FlowPayAmountDisplay(
                amount: wallet.balance.formatFormatted(),
                size: AmountDisplaySize.medium,
              ),
              const SizedBox(height: 5),
              InkWell(
                onTap: onCopyAddress,
                borderRadius: FlowPayRadii.chip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkSurfaceElevated
                        : FlowPayColors.mint100.withAlpha(120),
                    borderRadius: FlowPayRadii.chip,
                    border: Border.all(
                      color: isDark
                          ? FlowPayColors.darkBorder
                          : FlowPayColors.emerald400.withAlpha(40),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${wallet.address.substring(0, 6)}...${wallet.address.substring(wallet.address.length - 4)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.emerald700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.copy_rounded,
                        size: 10,
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.emerald700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

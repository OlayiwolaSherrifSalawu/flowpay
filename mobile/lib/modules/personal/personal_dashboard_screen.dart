import 'package:flutter/material.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../core/theme/typography.dart';
import 'ai_operator_modal.dart';
import 'money_missions_screen.dart';
import 'send_money_screen.dart';
import 'wallets_screen.dart';

class PersonalDashboardScreen extends StatefulWidget {
  final AppState appState;

  const PersonalDashboardScreen({Key? key, required this.appState}) : super(key: key);

  @override
  State<PersonalDashboardScreen> createState() => _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  List<Money> balances = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final b = await widget.appState.walletRepo.getBalances();
    setState(() {
      balances = b;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowPayColors.background,
      appBar: AppBar(
        backgroundColor: FlowPayColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FlowPay Personal', style: FlowPayTypography.headingSm),
            Text(
              widget.appState.isDemo ? '● Demo Provider' : '● BMONI Sandbox Live',
              style: TextStyle(
                fontSize: 12,
                color: widget.appState.isDemo ? FlowPayColors.warning : FlowPayColors.accent,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: FlowPayColors.primaryLight),
            tooltip: 'AI Financial Operator',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AiOperatorModal(appState: widget.appState),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FlowPayColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Total Balance Card
                  FlowPayCard(
                    backgroundColor: FlowPayColors.surfaceElevated,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Multi-Currency Value', style: FlowPayTypography.caption),
                        const SizedBox(height: 8),
                        Text(
                          balances.isNotEmpty ? balances.first.formatFormatted() : '\$0.00',
                          style: FlowPayTypography.financialLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const StatusBadge(status: 'Self-Custody (B-Key)'),
                            const Spacer(),
                            Text(
                              'On-Device EVM',
                              style: FlowPayTypography.caption.copyWith(color: FlowPayColors.accentLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FlowPayButton(
                          text: 'Send Money',
                          icon: Icons.arrow_outward,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SendMoneyScreen(appState: widget.appState),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FlowPayButton(
                          text: 'Wallets',
                          isSecondary: true,
                          icon: Icons.account_balance_wallet_outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WalletsScreen(appState: widget.appState),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Money Missions Feature Card
                  FlowPayCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MoneyMissionsScreen(appState: widget.appState),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FlowPayColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bolt, color: FlowPayColors.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Money Missions', style: FlowPayTypography.headingSm),
                              SizedBox(height: 4),
                              Text(
                                '"Your money. Your rules. AI executes."',
                                style: FlowPayTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: FlowPayColors.textTertiary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Balances breakdown
                  Text('Active Currency Balances', style: FlowPayTypography.headingSm),
                  const SizedBox(height: 12),
                  ...balances.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FlowPayCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: FlowPayColors.surfaceElevated,
                              radius: 18,
                              child: Text(
                                m.currency.symbol,
                                style: const TextStyle(
                                  color: FlowPayColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.currency.name, style: FlowPayTypography.bodyLg),
                                Text(
                                  'BMONI ${m.currency.stablecoinToken}',
                                  style: FlowPayTypography.caption,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(m.formatFormatted(), style: FlowPayTypography.financialMedium),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}

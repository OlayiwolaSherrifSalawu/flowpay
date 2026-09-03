import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/money.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/state/app_state.dart';
import 'money_missions_screen.dart';
import 'send_money_screen.dart';
import 'wallets_screen.dart';

class PersonalDashboardScreen extends StatefulWidget {
  final AppState appState;

  const PersonalDashboardScreen({super.key, required this.appState});

  @override
  State<PersonalDashboardScreen> createState() => _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  List<Money> balances = [];
  bool isLoading = true;
  bool isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final b = await widget.appState.walletRepo.getBalances();
    if (mounted) {
      setState(() {
        balances = b;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    final primaryBalance = balances.isNotEmpty ? balances.first : null;
    final wholePart = primaryBalance != null
        ? primaryBalance.formatFormatted(includeSymbol: true).split('.')[0]
        : '\$0';
    final decimalPart = primaryBalance != null
        ? '.${primaryBalance.toMajorString().split('.')[1]}'
        : '.00';

    Widget content = isLoading
        ? const FlowPayLoadingState(message: 'Syncing smart wallets...')
        : RefreshIndicator(
            onRefresh: _loadData,
            color: BMoniColors.brand500,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Header Subtitle & Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? BMoniColors.grey50 : BMoniColors.grey950,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '● BMONI Financial Operating Layer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BMoniColors.brand400,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BMoniColors.brand500.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: BMoniColors.brand400),
                          SizedBox(width: 4),
                          Text(
                            'Self-Custody (B-Key)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BMoniColors.brand400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hero BMoni Wallet Card
                BMoniWalletCard(
                  height: 180,
                  background: const BMoniWalletCardBackground.gradient(
                    LinearGradient(
                      colors: [
                        Color(0xFF4A0E4E),
                        Color(0xFF28092B),
                        Color(0xFF160418),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  balanceChild: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Multi-Currency Value',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: BMoniColors.grey400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      BMoniWalletCardBalance(
                        wholePart: wholePart,
                        decimalPart: decimalPart,
                        isHidden: isBalanceHidden,
                        onToggleHidden: () => setState(() => isBalanceHidden = !isBalanceHidden),
                        balanceColor: Colors.white,
                        decimalColor: BMoniColors.brand200,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '≈ ₦6,800,000 NGN across 3 rails',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: BMoniColors.brand300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: BMoniButton(
                        text: 'Send Money',
                        variant: BMoniButtonVariant.primary,
                        icon: Icons.arrow_outward,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SendMoneyScreen(appState: widget.appState),
                              settings: const RouteSettings(name: AppRoutes.personalSendMoney),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BMoniButton(
                        text: 'Wallets',
                        variant: BMoniButtonVariant.secondary,
                        icon: Icons.account_balance_wallet_outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WalletsScreen(appState: widget.appState),
                              settings: const RouteSettings(name: AppRoutes.personalWallets),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Money Missions Feature Card
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MoneyMissionsScreen(appState: widget.appState),
                        settings: const RouteSettings(name: AppRoutes.personalMissions),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          BMoniColors.offbrand900,
                          BMoniColors.brand950.withAlpha(200),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: BMoniColors.brand500.withAlpha(70),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BMoniColors.brand500.withAlpha(35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bolt, color: BMoniColors.brand400, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Money Missions',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: BMoniColors.grey50,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '"Your money. Your rules. AI executes."',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BMoniColors.grey400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: BMoniColors.grey400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // SectionHeader from bkey_uikit
                SectionHeader(
                  title: 'Active Multi-Currency Balances',
                  backgroundColor: Colors.transparent,
                  showBottomDivider: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  titleStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? BMoniColors.grey50 : BMoniColors.grey950,
                  ),
                ),

                // Balances breakdown
                ...balances.map((m) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: BMoniColors.offbrand900,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BMoniColors.offbrand700),
                    ),
                    child: Row(
                      children: [
                        FlowPayCurrencyDisplay(
                          code: m.currency.code,
                          symbol: m.currency.symbol,
                          name: m.currency.name,
                          tokenName: 'BMONI ${m.currency.stablecoinToken}',
                        ),
                        const Spacer(),
                        FlowPayAmountDisplay(
                          amount: m.formatFormatted(),
                          size: AmountDisplaySize.medium,
                        ),
                      ],
                    ),
                  );
                }),
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
  }
}

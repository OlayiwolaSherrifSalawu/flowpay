import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/design_system/design_system.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/state/app_state.dart';

class WalletsScreen extends StatefulWidget {
  final AppState appState;

  const WalletsScreen({super.key, required this.appState});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<WalletAccount> wallets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final list = await widget.appState.walletRepo.getWallets();
    if (mounted) {
      setState(() {
        wallets = list;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = isLoading
        ? const FlowPayLoadingState(message: 'Querying B-Key wallet registry...')
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // Security info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38103A), Color(0xFF1E0720)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: BMoniColors.brand400, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure Hardware Isolation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: BMoniColors.grey50,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Private keys never leave your phone. Created and protected on-device via BMONI B-Key SDK.',
                            style: TextStyle(
                              fontSize: 12,
                              color: BMoniColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SectionHeader(
                title: 'Configured Multi-Currency Wallets',
                backgroundColor: Colors.transparent,
                showBottomDivider: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                titleStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? BMoniColors.grey50 : BMoniColors.grey950,
                ),
              ),
              const SizedBox(height: 8),

              ...wallets.map((w) {
                final wholePart = w.balance.formatFormatted(includeSymbol: true).split('.')[0];
                final decimalPart = '.${w.balance.toMajorString().split('.')[1]}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: BMoniColors.offbrand900,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: BMoniColors.offbrand700),
                  ),
                  child: Column(
                    children: [
                      // Card Top Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            FlowPayCurrencyDisplay(
                              code: w.currency.code,
                              symbol: w.currency.symbol,
                              name: w.currency.name,
                              isCompact: true,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: BMoniColors.brand500.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: BMoniColors.brand500.withAlpha(60)),
                              ),
                              child: Text(
                                w.status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: BMoniColors.brand400,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$wholePart$decimalPart',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: BMoniColors.grey50,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: BMoniColors.offbrand800, height: 1),
                      // Card Address & Rail Details
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Contract Address',
                                  style: TextStyle(fontSize: 11, color: BMoniColors.grey400),
                                ),
                                const Spacer(),
                                Text(
                                  'BMONI ${w.stablecoinToken}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: BMoniColors.brand300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: BMoniColors.offbrand800,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      w.address,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: BMoniColors.grey300,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.copy, size: 14, color: BMoniColors.grey400),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Smart Wallets'),
        ),
        body: content,
      );
    }

    return content;
  }
}

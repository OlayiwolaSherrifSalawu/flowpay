import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/money.dart';
import '../../core/repositories/wallet_repository.dart';
import '../../core/state/app_state.dart';
import 'send_money_screen.dart';
import 'wallet_provisioning_screen.dart';

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
    widget.appState.addListener(_onAppStateChanged);
    _load();
  }

  void _onAppStateChanged() {
    if (mounted) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
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

  void _handleSend(WalletAccount wallet) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendMoneyScreen(appState: widget.appState),
      ),
    );
  }

  void _handleReceive(WalletAccount wallet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlowPayColors.darkSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Receive ${wallet.currency.code}',
              style: FlowPayTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Share your FlowPay account address to receive funds directly into your ${wallet.currency.name} wallet.',
              textAlign: TextAlign.center,
              style: FlowPayTypography.captionStyle(
                color: FlowPayColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlowPayColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FlowPayColors.darkBorder),
              ),
              child: SelectableText(
                wallet.address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: FlowPayColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FlowPayButton(
              text: 'Done',
              isFullWidth: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _handleConvert(WalletAccount wallet) {
    widget.appState.setPersonalTabIndex(0); // Switch to dashboard FX
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    Widget content = isLoading
        ? const FlowPayLoadingState(message: 'Loading wallets...')
        : RefreshIndicator(
            onRefresh: _load,
            color: FlowPayColors.primary,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // Security info banner
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const WalletProvisioningScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.darkSurface
                          : FlowPayColors.lightSurface,
                      borderRadius: FlowPaySpacing.borderRadiusLg,
                      border: Border.all(
                        color: FlowPayColors.primary.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FlowPayColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: FlowPayColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Secure Hardware Isolation',
                                style: FlowPayTypography.bodyMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? FlowPayColors.darkTextPrimary
                                      : FlowPayColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Keys sealed on this device. Tap to inspect security enclave.',
                                style: FlowPayTypography.captionStyle(
                                  color: FlowPayColors.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: FlowPayColors.darkTextSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Configured Multi-Currency Wallets',
                  style: FlowPayTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                ...wallets.map((w) {
                  // Calculate available vs reserved breakdown
                  final totalBal = w.balance;
                  final reservedMajor = (totalBal.majorUnits * 0.15); // mock active mission reserve
                  final availableBal = Money.fromMajorString(
                    (totalBal.majorUnits - reservedMajor).toStringAsFixed(2),
                    w.currency,
                  );
                  final reservedBal = Money.fromMajorString(
                    reservedMajor.toStringAsFixed(2),
                    w.currency,
                  );

                  return FlowPayWalletCard(
                    walletName: '${w.currency.name} Wallet',
                    currency: w.currency,
                    balance: totalBal,
                    availableBalance: availableBal,
                    reservedBalance: reservedBal,
                    accountOrAddress: w.address,
                    status: w.status,
                    onSend: () => _handleSend(w),
                    onReceive: () => _handleReceive(w),
                    onConvert: () => _handleConvert(w),
                  );
                }),
              ],
            ),
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

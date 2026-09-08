import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/repositories/activity_repository.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultAmount = wallet.currency == Currency.ngn
        ? '100000'
        : (wallet.currency == Currency.mxn ? '5000' : '500.00');
    final amountController = TextEditingController(text: defaultAmount);
    bool isDepositing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? FlowPayColors.darkSurfaceElevated
          : FlowPayColors.lightSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final quickAmounts = wallet.currency == Currency.ngn
              ? ['50000', '100000', '250000', '500000']
              : wallet.currency == Currency.mxn
                  ? ['1000', '2500', '5000', '10000']
                  : ['100', '250', '500', '1000'];

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: bottomInset + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FlowPayColors.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receive ${wallet.currency.code}',
                        style: FlowPayTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FlowPayColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${wallet.currency.name} Wallet',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FlowPayColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your address or simulate an instant incoming deposit below.',
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wallet address box
                  const Text(
                    'FLOWPAY ACCOUNT ADDRESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: FlowPayColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.darkSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            wallet.address,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: FlowPayColors.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy,
                              size: 16, color: FlowPayColors.primary),
                          tooltip: 'Copy Address',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: wallet.address));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Simulate deposit section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: FlowPayColors.primary.withAlpha(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.arrow_downward,
                                size: 16, color: FlowPayColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'SIMULATE INCOMING DEPOSIT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: FlowPayColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick amounts
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: quickAmounts.map((q) {
                            final isSel = amountController.text == q;
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  amountController.text = q;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? FlowPayColors.primary
                                      : (isDark
                                          ? FlowPayColors.darkSurface
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel
                                        ? FlowPayColors.primary
                                        : FlowPayColors.darkBorder,
                                  ),
                                ),
                                child: Text(
                                  '+${wallet.currency.symbol}$q',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? Colors.black
                                        : (isDark
                                            ? FlowPayColors.darkTextPrimary
                                            : FlowPayColors.lightTextPrimary),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Amount input field
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText:
                                'Amount to receive (${wallet.currency.code})',
                            prefixText: '${wallet.currency.symbol} ',
                            filled: true,
                            fillColor: isDark
                                ? FlowPayColors.darkSurface
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Receive button
                        FlowPayButton(
                          text: isDepositing
                              ? 'Depositing...'
                              : '⚡ Receive Funds into Wallet',
                          isFullWidth: true,
                          isLoading: isDepositing,
                          onPressed: isDepositing
                              ? null
                              : () async {
                                  final numVal = double.tryParse(
                                          amountController.text.trim()) ??
                                      0.0;
                                  if (numVal <= 0) return;

                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  setModalState(() => isDepositing = true);
                                  try {
                                    final creditAmount =
                                        Money.fromMajorString(
                                      numVal.toStringAsFixed(2),
                                      wallet.currency,
                                    );

                                    await widget.appState.walletRepo
                                        .creditWallet(
                                      walletId: wallet.id,
                                      amount: creditAmount,
                                    );

                                    // Log incoming activity
                                    try {
                                      final act = ActivityModel(
                                        id: 'act_rcv_${DateTime.now().millisecondsSinceEpoch}',
                                        title:
                                            'Received ${creditAmount.formatFormatted()}',
                                        description:
                                            'Deposit into ${wallet.currency.name} Wallet',
                                        amount: creditAmount,
                                        currency: wallet.currency,
                                        type: ActivityType.transfer,
                                        category: ActivityCategory.transfer,
                                        status: FlowPayAppStatus.completed,
                                        timestamp: DateTime.now(),
                                        reference:
                                            'DEP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                      );
                                      await widget.appState.activityRepo
                                          .recordActivity(act);
                                    } catch (_) {}

                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }

                                    // Refresh provider & screen
                                    await widget.appState.personalProvider
                                        .refresh();
                                    await _load();

                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Successfully received ${creditAmount.formatFormatted()} into ${wallet.currency.name} Wallet!'),
                                          backgroundColor:
                                              FlowPayColors.success,
                                        ),
                                      );
                                    }
                                  } catch (err) {
                                    setModalState(() => isDepositing = false);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Deposit failed: $err'),
                                          backgroundColor:
                                              FlowPayColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

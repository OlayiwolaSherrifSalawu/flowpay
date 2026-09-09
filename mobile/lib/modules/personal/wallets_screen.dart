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

/// FLOWPAY — MULTI-CURRENCY SMART WALLETS SCREEN
///
/// Features:
/// - Interactive Card Deck / Carousel (USD, NGN, MXN, CAD) with tactile indicators
/// - Quick Actions Row (Send, Receive, Convert, Security)
/// - Spendable Balance vs Active Mission Reservations metric pill split
/// - On-Device B-Key Hardware Enclave status banner
/// - Configured Multi-Currency Wallets list with 1-tap address copying and actions
class WalletsScreen extends StatefulWidget {
  final AppState appState;

  const WalletsScreen({super.key, required this.appState});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<WalletAccount> wallets = [];
  bool isLoading = true;
  int _selectedWalletIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
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
    _pageController.dispose();
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final list = await widget.appState.walletRepo.getWallets();
    if (mounted) {
      setState(() {
        wallets = list;
        if (_selectedWalletIndex >= wallets.length) {
          _selectedWalletIndex = (wallets.length - 1).clamp(0, 99);
        }
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
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: FlowPayRadii.sheet,
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
              left: 20,
              right: 20,
              top: 18,
              bottom: bottomInset + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? FlowPayColors.darkBorder
                            : FlowPayColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            wallet.currency.flagEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Receive ${wallet.currency.code}',
                            style: FlowPayTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark
                                  ? Colors.white
                                  : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? FlowPayColors.emerald600.withAlpha(30)
                              : FlowPayColors.mint100,
                          borderRadius: FlowPayRadii.chip,
                          border: Border.all(
                            color: isDark
                                ? FlowPayColors.emerald400.withAlpha(60)
                                : FlowPayColors.emerald600.withAlpha(40),
                          ),
                        ),
                        child: Text(
                          '${wallet.stablecoinToken} Rail',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FlowPayColors.emerald400
                                : FlowPayColors.emerald700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share your address or simulate an instant incoming deposit below.',
                    style: FlowPayTypography.captionStyle(
                      color: isDark
                          ? FlowPayColors.darkTextSecondary
                          : FlowPayColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wallet address box
                  Text(
                    'FLOWPAY ACCOUNT ADDRESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark
                          ? FlowPayColors.darkTextSecondary
                          : FlowPayColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.darkSurface
                          : FlowPayColors.lightSurface,
                      borderRadius: FlowPayRadii.cardSmall,
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
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: isDark
                                ? FlowPayColors.emerald400
                                : FlowPayColors.emerald700,
                          ),
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
                  const SizedBox(height: 18),

                  // Simulate deposit section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.darkSurface
                          : FlowPayColors.mint100.withAlpha(90),
                      borderRadius: FlowPayRadii.cardSmall,
                      border: Border.all(
                        color: isDark
                            ? FlowPayColors.emerald400.withAlpha(50)
                            : FlowPayColors.emerald600.withAlpha(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.south_west_rounded,
                              size: 16,
                              color: isDark
                                  ? FlowPayColors.emerald400
                                  : FlowPayColors.emerald700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SIMULATE INCOMING DEPOSIT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? FlowPayColors.emerald400
                                    : FlowPayColors.emerald700,
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
                              borderRadius: FlowPayRadii.chip,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? FlowPayColors.emerald600
                                      : (isDark
                                          ? FlowPayColors.darkSurfaceElevated
                                          : Colors.white),
                                  borderRadius: FlowPayRadii.chip,
                                  border: Border.all(
                                    color: isSel
                                        ? FlowPayColors.emerald600
                                        : (isDark
                                            ? FlowPayColors.darkBorder
                                            : FlowPayColors.lightBorder),
                                  ),
                                ),
                                child: Text(
                                  '+${wallet.currency.symbol}$q',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
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
                                ? FlowPayColors.darkSurfaceElevated
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: FlowPayRadii.input,
                              borderSide: BorderSide(
                                color: isDark
                                    ? FlowPayColors.darkBorder
                                    : FlowPayColors.lightBorder,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: FlowPayRadii.input,
                              borderSide: BorderSide(
                                color: isDark
                                    ? FlowPayColors.darkBorder
                                    : FlowPayColors.lightBorder,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: FlowPayRadii.input,
                              borderSide: BorderSide(
                                color: FlowPayColors.emerald600,
                                width: 1.5,
                              ),
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

  LinearGradient _getWalletGradient(Currency currency) {
    if (currency == Currency.usd) {
      return const LinearGradient(
        colors: [
          Color(0xFF0B6E4F),
          Color(0xFF128A63),
          Color(0xFF0F1712),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (currency == Currency.ngn) {
      return const LinearGradient(
        colors: [
          Color(0xFF181B26),
          Color(0xFF12141C),
          Color(0xFF0B6E4F),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (currency == Currency.mxn) {
      return const LinearGradient(
        colors: [
          Color(0xFF0F3B2E),
          Color(0xFF149E72),
          Color(0xFF0F1712),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [
          Color(0xFF141E28),
          Color(0xFF0F1712),
          Color(0xFF128A63),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    if (isLoading) {
      return const FlowPayLoadingState(message: 'Loading wallets...');
    }

    final activeWallet = wallets.isNotEmpty
        ? wallets[_selectedWalletIndex.clamp(0, wallets.length - 1)]
        : null;

    Money? availableBal;
    Money? reservedBal;
    if (activeWallet != null) {
      final totalBal = activeWallet.balance;
      final reservedMajor = (totalBal.majorUnits * 0.15);
      availableBal = Money.fromMajorString(
        (totalBal.majorUnits - reservedMajor).toStringAsFixed(2),
        activeWallet.currency,
      );
      reservedBal = Money.fromMajorString(
        reservedMajor.toStringAsFixed(2),
        activeWallet.currency,
      );
    }

    Widget content = RefreshIndicator(
      onRefresh: _load,
      color: FlowPayColors.emerald600,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Multi-Currency Hero Card Carousel / Deck
          if (wallets.isNotEmpty) ...[
            SizedBox(
              height: 228,
              child: PageView.builder(
                controller: _pageController,
                itemCount: wallets.length,
                onPageChanged: (idx) {
                  setState(() => _selectedWalletIndex = idx);
                },
                itemBuilder: (context, index) {
                  final w = wallets[index];
                  final gradient = _getWalletGradient(w.currency);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FlowPayScallopedCard(
                      title: '${w.currency.name} Portfolio',
                      balance: w.balance.formatFormatted(includeSymbol: true),
                      holderName: 'Waffiyyi Fashola',
                      expiryDate: '${w.stablecoinToken} Rail',
                      gradient: gradient,
                      actionLabel: 'Receive',
                      onActionTap: () => _handleReceive(w),
                      onTap: () => _handleReceive(w),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Tactile dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(wallets.length, (i) {
                final isSel = i == _selectedWalletIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSel ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSel
                        ? FlowPayColors.emerald600
                        : (isDark
                            ? FlowPayColors.darkSurfaceElevated
                            : FlowPayColors.mint100),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // 2. Quick Actions for Active Wallet
            if (activeWallet != null) ...[
              FlowPayQuickActionRow(
                customItems: [
                  QuickActionItem(
                    label: 'Send',
                    icon: Icons.arrow_outward_rounded,
                    onTap: () => _handleSend(activeWallet),
                  ),
                  QuickActionItem(
                    label: 'Receive',
                    icon: Icons.south_west_rounded,
                    onTap: () => _handleReceive(activeWallet),
                  ),
                  QuickActionItem(
                    label: 'Convert',
                    icon: Icons.sync_alt_rounded,
                    onTap: () => _handleConvert(activeWallet),
                  ),
                  QuickActionItem(
                    label: 'Security',
                    icon: Icons.shield_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WalletProvisioningScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Spendable vs Reserved Breakdown
              if (availableBal != null && reservedBal != null)
                FlowPayIncomeExpenseRow(
                  incomeLabel: '${activeWallet.currency.code} Spendable',
                  incomeAmount:
                      availableBal.formatFormatted(includeSymbol: true),
                  expenseLabel: 'Reserved (Missions)',
                  expenseAmount:
                      reservedBal.formatFormatted(includeSymbol: true),
                  onIncomeTap: () => _handleSend(activeWallet),
                  onExpenseTap: () => _handleConvert(activeWallet),
                ),
              const SizedBox(height: 16),
            ],
          ],

          // 4. Hardware Isolation Security Banner
          InkWell(
            borderRadius: FlowPayRadii.cardSmall,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FlowPayColors.emerald600.withAlpha(35)
                          : FlowPayColors.mint100,
                      borderRadius: FlowPayRadii.quickAction,
                      border: Border.all(
                        color: isDark
                            ? FlowPayColors.emerald400.withAlpha(70)
                            : FlowPayColors.emerald600.withAlpha(40),
                      ),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: isDark
                          ? FlowPayColors.emerald400
                          : FlowPayColors.emerald700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Hardware Isolation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Keys sealed on this device. Tap to inspect security enclave.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: FlowPayColors.emerald400,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 5. Configured Multi-Currency Wallets List Section
          Text(
            'Configured Multi-Currency Wallets',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : FlowPayColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...wallets.asMap().entries.map((entry) {
            final idx = entry.key;
            final w = entry.value;

            final totalBal = w.balance;
            final reservedMajor = (totalBal.majorUnits * 0.15);
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
              onTap: () {
                setState(() => _selectedWalletIndex = idx);
                _pageController.animateToPage(
                  idx,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              onSend: () => _handleSend(w),
              onReceive: () => _handleReceive(w),
              onConvert: () => _handleConvert(w),
            );
          }),
          const SizedBox(height: 24),
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

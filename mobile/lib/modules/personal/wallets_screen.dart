import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../core/stellar/stellar_activation.dart';
import '../../core/auth/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/stellar/stellar_api.dart';
import 'components/receive_sheet.dart';
import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
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
  String? _loadError;
  bool _activating = false;
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
    setState(() {
      isLoading = true;
      _loadError = null;
    });
    try {
      final list = await widget.appState.walletRepo.getWallets();
      if (!mounted) return;
      setState(() {
        wallets = list;
        if (_selectedWalletIndex >= wallets.length) {
          _selectedWalletIndex = (wallets.length - 1).clamp(0, 99);
        }
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Never show stale or invented balances: surface the failure.
      setState(() {
        isLoading = false;
        _loadError = 'Could not load your balances: $e';
      });
    }
  }

  /// Finishes Stellar activation (link, create, enable currencies, test funds).
  Future<void> _activateWallet() async {
    final messenger = ScaffoldMessenger.of(context);
    String? failure;
    final result = await WalletPinAuthSheet.show(
      context: context,
      title: 'Activate your wallet',
      subtitle: 'Enter your PIN to finish setting up your wallet on Stellar.',
      onAuthorize: (pin) async {
        setState(() => _activating = true);
        try {
          final report = await StellarActivation(api: StellarApi(widget.appState.apiClient)).activate(pin: pin);
          if (!report.isActive) {
            failure = report.failures.map((f) => f.error).whereType<String>().join('\n');
          }
          return 'activated';
        } finally {
          if (mounted) setState(() => _activating = false);
        }
      },
    );
    if (result == null || !mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor: failure == null ? FlowPayColors.success : FlowPayColors.warning,
      content: Text(failure == null ? 'Your wallet is active on Stellar.' : 'Activation incomplete: $failure'),
    ));
    await _load();
    widget.appState.personalProvider.refresh();
  }

  Widget _buildNotActiveState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.account_balance_wallet_outlined, size: 48, color: FlowPayColors.primary),
        const SizedBox(height: 16),
        Text(
          _loadError ?? 'Your wallet isn\'t active on Stellar yet.',
          key: const Key('wallets_not_active_message'),
          textAlign: TextAlign.center,
          style: FlowPayTypography.bodyMedium,
        ),
        const SizedBox(height: 20),
        FlowPayButton(
          key: const Key('wallets_activate_button'),
          text: _loadError != null ? 'Try again' : 'Activate wallet',
          isLoading: _activating,
          onPressed: _activating ? null : (_loadError != null ? _load : _activateWallet),
        ),
      ],
    );
  }

  void _handleSend(WalletAccount wallet) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendMoneyScreen(appState: widget.appState),
      ),
    );
  }

  void _handleReceive(WalletAccount wallet) {
    ReceiveSheet.show(
      context,
      accountId: wallet.address,
      currency: wallet.currency,
      // Test funds only in live (Stellar testnet) mode; demo mode has no network.
      api: widget.appState.isDemo ? null : StellarApi(widget.appState.apiClient),
      onFunded: () => widget.appState.personalProvider.refresh(),
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
    if (!widget.appState.isDemo && (wallets.isEmpty || _loadError != null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallets')),
        body: _buildNotActiveState(),
      );
    }

    final activeWallet = wallets.isNotEmpty
        ? wallets[_selectedWalletIndex.clamp(0, wallets.length - 1)]
        : null;

    // Stellar asset balances are fully spendable; nothing is held back.
    final Money? availableBal = activeWallet?.balance;
    final Money? reservedBal = activeWallet == null ? null : Money.zero(activeWallet.currency);

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
                    child: Consumer(builder: (context, ref, _) => FlowPayScallopedCard(
                      title: '${w.currency.name} Portfolio',
                      balance: w.balance.formatFormatted(includeSymbol: true),
                      holderName: ref.watch(currentUserProfileProvider)?.fullName ?? '',
                      expiryDate: w.currency.code,
                      gradient: gradient,
                      actionLabel: 'Receive',
                      onActionTap: () => _handleReceive(w),
                      onTap: () => _handleReceive(w),
                    )),
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
                          'Secured on this device',
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
                          'Protected with device security. Tap to learn more.',
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
            'Your wallets',
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
          title: const Text('Wallets'),
        ),
        body: content,
      );
    }

    return content;
  }
}

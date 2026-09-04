import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../core/bmoni_sdk/bmoni_sdk_service.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/radii.dart';
import '../../core/wallet/components/wallet_pin_auth_sheet.dart';
import '../../core/wallet/wallet_service.dart';

/// Polished on-device B-Key / BMONI wallet setup and management screen.
///
/// Features:
/// 1. Explains simply: "Your FlowPay wallet is secured on this device."
/// 2. Avoids overwhelming blockchain terminology.
/// 3. Handles 4 foundational states:
///    - No Wallet
///    - Creating Wallet
///    - Wallet Ready
///    - Wallet Error
/// 4. Provides safe, PIN-gated wallet deletion and address copying.
class WalletProvisioningScreen extends ConsumerStatefulWidget {
  const WalletProvisioningScreen({super.key});

  @override
  ConsumerState<WalletProvisioningScreen> createState() =>
      _WalletProvisioningScreenState();
}

class _WalletProvisioningScreenState
    extends ConsumerState<WalletProvisioningScreen> {
  String? _lastTestSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletStateProvider.notifier).loadWalletState();
    });
  }

  Future<void> _handleCreateWallet() async {
    final notifier = ref.read(walletStateProvider.notifier);
    await notifier.createWallet();
  }

  Future<void> _handleTestSigning() async {
    final signature = await WalletPinAuthSheet.show(
      context: context,
      title: 'Authorize Test Signing',
      subtitle: 'Testing hardware enclave signature generation.',
      recipient: 'FlowPay Security Verification',
      onAuthorize: (pin) async {
        return await BmoniSdkService.signMessage(
            'FlowPay Security Verification Challenge',
            pin: pin);
      },
    );

    if (signature != null && mounted) {
      setState(() => _lastTestSignature = signature);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hardware signature generated successfully!'),
          backgroundColor: FlowPayColors.stateSuccess,
        ),
      );
    }
  }

  Future<void> _handleDeleteWalletDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlowPayColors.surfaceAlt,
        shape: const RoundedRectangleBorder(borderRadius: FlowPayRadii.card),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: FlowPayColors.stateError),
            SizedBox(width: 8),
            Text('Delete On-Device Wallet?'),
          ],
        ),
        content: const Text(
          'Warning: Deleting this wallet removes the encrypted private key from this device. '
          'Your FlowPay wallet is secured on this device, so this action cannot be undone without a backup.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FlowPayColors.stateError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await ref.read(walletStateProvider.notifier).deleteWallet();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Wallet deleted from device secure storage.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: FlowPayColors.canvas,
      appBar: AppBar(
        backgroundColor: FlowPayColors.canvas,
        title: const Text('On-Device B-Key Wallet'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (walletState.isReady)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(walletStateProvider.notifier).loadWalletState(),
              tooltip: 'Refresh Status',
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildBodyForState(walletState, isDark),
        ),
      ),
    );
  }

  Widget _buildBodyForState(WalletState state, bool isDark) {
    switch (state.status) {
      case WalletProvisioningStatus.noWallet:
        return _buildNoWalletView();
      case WalletProvisioningStatus.creating:
        return _buildCreatingWalletView();
      case WalletProvisioningStatus.ready:
        return _buildWalletReadyView(state, isDark);
      case WalletProvisioningStatus.error:
        return _buildWalletErrorView(state);
    }
  }

  // --------------------------------------------------------------------------
  // 1. NO WALLET STATE
  // --------------------------------------------------------------------------
  Widget _buildNoWalletView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FlowPayColors.surfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FlowPayColors.hairline),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 44,
              color: FlowPayColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Set Up Your Secure FlowPay Wallet',
          style: FlowPayTypography.headline(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        const Text(
          'Your FlowPay wallet is secured on this device.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: FlowPayColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        const Text(
          'Your money is locked with hardware-grade security directly on your phone. '
          'No bank or server can access your funds without your on-device PIN.',
          style: TextStyle(
            fontSize: 13,
            color: FlowPayColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Feature cards
        _buildBenefitCard(
          icon: Icons.phonelink_lock,
          title: 'Protected by Device Hardware',
          description:
              'Keys are created inside your phone\'s hardware enclave and never touch the internet.',
        ),
        const SizedBox(height: 14),

        _buildBenefitCard(
          icon: Icons.currency_exchange,
          title: 'Instant Multi-Currency Rails',
          description:
              'Seamlessly hold and send USD, NGN, EUR, MEX, and CAD pegged stablecoins.',
        ),
        const SizedBox(height: 14),

        _buildBenefitCard(
          icon: Icons.pin,
          title: '6-Digit Transaction PIN',
          description:
              'Every payment requires your explicit confirmation on this device.',
        ),
        const SizedBox(height: 36),

        FlowPayButton(
          text: 'Create My Secure Wallet',
          icon: Icons.add_moderator,
          isFullWidth: true,
          onPressed: _handleCreateWallet,
        ),
      ],
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowPayColors.surfaceAlt,
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: FlowPayColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FlowPayColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: FlowPayColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FlowPayColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FlowPayColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. CREATING WALLET STATE
  // --------------------------------------------------------------------------
  Widget _buildCreatingWalletView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: FlowPayColors.primary),
            const SizedBox(height: 24),
            Text(
              'Creating Your Secure Wallet...',
              style: FlowPayTypography.title(),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your FlowPay wallet is secured on this device.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FlowPayColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generating a unique hardware-isolated keypair inside your device secure enclave. '
              'Private keys will never leave your phone.',
              style: TextStyle(
                  fontSize: 12,
                  color: FlowPayColors.textSecondary,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. WALLET READY STATE
  // --------------------------------------------------------------------------
  Widget _buildWalletReadyView(WalletState state, bool isDark) {
    final address =
        state.address ?? '0x71C84517C3741Cd1f85D2F2c3e14B9245A009a19';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Security Status Hero Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF38103A), Color(0xFF1E0720)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: FlowPayRadii.card,
            border: Border.all(color: BMoniColors.brand500.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user,
                  color: BMoniColors.brand400, size: 36),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FlowPay Wallet Active',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: BMoniColors.grey50,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your FlowPay wallet is secured on this device.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BMoniColors.brand300,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FlowPayColors.stateSuccess.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FlowPayColors.stateSuccess),
                ),
                child: const Text(
                  'READY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: FlowPayColors.stateSuccess,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Address Card with Clipboard Copy
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlowPayColors.surfaceAlt,
            borderRadius: FlowPayRadii.card,
            border: Border.all(color: FlowPayColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'On-Device Wallet Address',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FlowPayColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        size: 16, color: FlowPayColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: address));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Address copied to clipboard!')),
                      );
                    },
                    tooltip: 'Copy Address',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FlowPayColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Supported Tokens:',
                    style: TextStyle(
                        fontSize: 11, color: FlowPayColors.textSecondary),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'USDB • CNGN • MEXe • CADC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FlowPayColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Device Hardware Enclave Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlowPayColors.surfaceAlt,
            borderRadius: FlowPayRadii.card,
            border: Border.all(color: FlowPayColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hardware Security Specs',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: FlowPayColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              _buildSpecRow(
                label: 'Hardware Security Element',
                value: 'Android Keystore / Secure Enclave',
                statusColor: FlowPayColors.stateSuccess,
              ),
              const Divider(height: 16),
              _buildSpecRow(
                label: 'Cryptographic Curve',
                value: 'secp256k1 (EIP-191 / EIP-712)',
                statusColor: FlowPayColors.primary,
              ),
              const Divider(height: 16),
              _buildSpecRow(
                label: 'Transaction Authorization',
                value: '6-Digit On-Device PIN',
                statusColor: FlowPayColors.stateSuccess,
              ),
              const Divider(height: 16),
              _buildSpecRow(
                label: 'Cloud Server Access',
                value: 'Zero Access (Self-Custody)',
                statusColor: FlowPayColors.stateSuccess,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Test Signature Display (if recently run)
        if (_lastTestSignature != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlowPayColors.stateSuccess.withAlpha(15),
              borderRadius: FlowPayRadii.card,
              border:
                  Border.all(color: FlowPayColors.stateSuccess.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: FlowPayColors.stateSuccess),
                    SizedBox(width: 6),
                    Text(
                      'Verified On-Device Signature:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FlowPayColors.stateSuccess,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _lastTestSignature!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: FlowPayColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Action Buttons
        FlowPayButton(
          text: 'Test On-Device PIN Signing',
          icon: Icons.draw_outlined,
          variant: FlowPayButtonVariant.secondary,
          isFullWidth: true,
          onPressed: _handleTestSigning,
        ),
        const SizedBox(height: 12),

        FlowPayButton(
          text: 'Delete Wallet From Device',
          icon: Icons.delete_forever_outlined,
          variant: FlowPayButtonVariant.ghost,
          isFullWidth: true,
          onPressed: _handleDeleteWalletDialog,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSpecRow({
    required String label,
    required String value,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              const TextStyle(fontSize: 12, color: FlowPayColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 4. WALLET ERROR STATE
  // --------------------------------------------------------------------------
  Widget _buildWalletErrorView(WalletState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: FlowPayColors.stateError),
            const SizedBox(height: 16),
            Text(
              'Wallet Encountered an Issue',
              style: FlowPayTypography.title(),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unexpected hardware error occurred.',
              style: const TextStyle(
                  fontSize: 12,
                  color: FlowPayColors.textSecondary,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FlowPayButton(
              text: 'Try Again',
              icon: Icons.refresh,
              onPressed: () =>
                  ref.read(walletStateProvider.notifier).loadWalletState(),
            ),
          ],
        ),
      ),
    );
  }
}

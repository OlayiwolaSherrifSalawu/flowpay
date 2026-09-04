import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../../design_system/design_system.dart';
import '../models/embedded_wallet.dart';

/// EmbeddedWalletCard wraps the bkey_uikit BMoniWalletCard primitive with
/// currency formatting, 6 background art variants per currency (USD/NGN/EUR/GBP/CAD/MXN),
/// and live balance state wired to the EmbeddedWallet model.
class EmbeddedWalletCard extends StatelessWidget {
  final EmbeddedWallet wallet;
  final bool isBalanceHidden;
  final VoidCallback? onToggleHideBalance;
  final bool isLoading;
  final bool isRefreshing;
  final VoidCallback? onInfoTap;
  final VoidCallback? onTap;

  const EmbeddedWalletCard({
    super.key,
    required this.wallet,
    this.isBalanceHidden = false,
    this.onToggleHideBalance,
    this.isLoading = false,
    this.isRefreshing = false,
    this.onInfoTap,
    this.onTap,
  });

  /// Resolves the canonical BMoniWalletType background variant matching
  /// the employee's payroll currency rather than picking arbitrarily.
  static BMoniWalletType resolveWalletType(String currency) {
    switch (currency.toUpperCase()) {
      case 'NGN':
      case 'CNGN':
        return BMoniWalletType.ngn;
      case 'MXN':
      case 'MEXE':
        return BMoniWalletType.mxn;
      case 'CAD':
      case 'CADC':
        return BMoniWalletType.cad;
      case 'EUR':
      case 'EURE':
        return BMoniWalletType.eur;
      case 'GBP':
      case 'GBPE':
        return BMoniWalletType.gbp;
      case 'USD':
      case 'USDB':
      default:
        return BMoniWalletType.usd;
    }
  }

  /// Resolves rich background styling for the currency card art
  static BoxDecoration resolveCardArtDecoration(String currency) {
    switch (currency.toUpperCase()) {
      case 'NGN':
      case 'CNGN':
        // Emerald / Forest Green for Nigerian Naira (CNGN)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D3B2E), Color(0xFF051C15), Color(0xFF0F4735)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'MXN':
      case 'MEXE':
        // Warm Terracotta / Aztec Amber for Mexican Peso (MEXe)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF421C0E), Color(0xFF240E06), Color(0xFF5A2510)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'CAD':
      case 'CADC':
        // Crimson / Maple Red for Canadian Dollar (CADC)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B0D14), Color(0xFF1C0509), Color(0xFF54121C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'EUR':
      case 'EURE':
        // Deep Indigo for Euro (EURe)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F0E2A), Color(0xFF2E2A72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'GBP':
      case 'GBPE':
        // Royal Purple for British Pound (GBPe)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B0764), Color(0xFF1F0435), Color(0xFF581C87)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.25),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA855F7).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case 'USD':
      case 'USDB':
      default:
        // Royal Sapphire Blue for US Dollar (USDB)
        return BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0C2340), Color(0xFF05101E), Color(0xFF133663)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
    }
  }

  String _formatCurrency(double amount, String cur) {
    final sym = cur.toUpperCase() == 'NGN' || cur.toUpperCase() == 'CNGN'
        ? '₦'
        : cur.toUpperCase() == 'MXN' || cur.toUpperCase() == 'MEXE'
            ? 'Mex\$'
            : cur.toUpperCase() == 'CAD' || cur.toUpperCase() == 'CADC'
                ? 'CA\$'
                : '\$';
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$sym$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final cardDecoration = resolveCardArtDecoration(wallet.currency);
    final isNg = wallet.currency.toUpperCase() == 'NGN' ||
        wallet.currency.toUpperCase() == 'CNGN';
    final isMx = wallet.currency.toUpperCase() == 'MXN' ||
        wallet.currency.toUpperCase() == 'MEXE';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 196,
        padding: const EdgeInsets.all(20),
        decoration: cardDecoration,
        child: Stack(
          children: [
            // Background Watermark Art per Currency
            Positioned(
              right: -15,
              bottom: -20,
              child: Opacity(
                opacity: 0.08,
                child: Text(
                  isNg
                      ? '₦'
                      : isMx
                          ? 'Mex\$'
                          : '\$',
                  style: const TextStyle(
                    fontSize: 160,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Card Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            wallet.currency.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (wallet.stablecoinToken != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: FlowPayColors.brand.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              wallet.stablecoinToken!,
                              style: const TextStyle(
                                color: FlowPayColors.brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (isLoading || isRefreshing) ...[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (onInfoTap != null) ...[
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded,
                                color: Colors.white70, size: 20),
                            onPressed: onInfoTap,
                            tooltip: 'Wallet Details',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Center: Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'SMART WALLET BALANCE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (onToggleHideBalance != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onToggleHideBalance,
                            child: Icon(
                              isBalanceHidden
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white60,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isBalanceHidden
                          ? '••••••••'
                          : _formatCurrency(wallet.balance, wallet.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                // Bottom Footer: Wallet Name & Status Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      wallet.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: wallet.status.toLowerCase() == 'active'
                            ? FlowPayColors.signal.withValues(alpha: 0.25)
                            : Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: wallet.status.toLowerCase() == 'active'
                                  ? FlowPayColors.signal
                                  : Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            wallet.status.toUpperCase(),
                            style: TextStyle(
                              color: wallet.status.toLowerCase() == 'active'
                                  ? FlowPayColors.signal
                                  : Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

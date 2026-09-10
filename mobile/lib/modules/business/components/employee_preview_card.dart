import 'package:flutter/material.dart';
import '../../../core/repositories/employee_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Employee Preview Card
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// Displays all 7 employee preview attributes with 20dp card geometry,
/// universal pill badges, and tabular figures for all salaries.
class EmployeePreviewCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const EmployeePreviewCard({
    super.key,
    required this.employee,
    this.onTap,
    this.onRetry,
  });

  bool get _isFailed => employee.status.toUpperCase() == 'FAILED';

  /// Truthful wallet line — never invents a "0x...Ready" address (per AGENTS.md).
  String _walletDisplay(EmployeeModel e) {
    final addr = e.walletAddress;
    if (addr != null && addr.isNotEmpty) {
      final short = addr.length > 12
          ? '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}'
          : addr;
      return '${e.walletStatus} • $short';
    }
    return 'Not provisioned';
  }

  /// Truthful card line — never invents a "•••• 4289" (per AGENTS.md).
  String _cardDisplay(EmployeeModel e) {
    final last4 = e.cardLast4;
    if (last4 != null && last4.isNotEmpty) {
      return '${e.cardStatus} • •••• $last4';
    }
    return 'Not issued';
  }

  Color _getCurrencyBg(String code, bool isDark) {
    switch (code.toUpperCase()) {
      case 'NGN':
        return isDark ? const Color(0xFF064E3B) : FlowPayColors.ngnBadge;
      case 'MXN':
        return isDark ? const Color(0xFF581C87) : FlowPayColors.mxnBadge;
      case 'CAD':
        return isDark ? const Color(0xFF7F1D1D) : FlowPayColors.cadBadge;
      default:
        return isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.usdBadge;
    }
  }

  Color _getCurrencyFg(String code, bool isDark) {
    switch (code.toUpperCase()) {
      case 'NGN':
        return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
      case 'MXN':
        return isDark ? const Color(0xFFF0ABFC) : const Color(0xFF86198F);
      case 'CAD':
        return isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
      default:
        return isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final surfaceAltColor =
        isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    final payrollFormatted = employee.payrollAmount != null
        ? employee.payrollAmount!.formatFormatted()
        : '${employee.targetCurrency.symbol}2,000.00';

    final usdFormatted = employee.usdPayrollAmount != null
        ? employee.usdPayrollAmount!.formatFormatted()
        : '\$2,000.00 USD';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FlowPayCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Name, Email, and Onboarding Status
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surfaceAltColor,
                    borderRadius: FlowPayRadii.avatar,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      employee.flagEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: FlowPayTypography.title(color: inkColor).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.email,
                        style: FlowPayTypography.captionStyle(
                          color: textSecondaryColor,
                        ).copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: employee.onboardingStatus),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 12),

            // Row 2: Country, Currency, and Payroll Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country & Currency Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COUNTRY',
                        style: FlowPayTypography.captionStyle(
                          color: textTertiaryColor,
                        ).copyWith(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${employee.flagEmoji} ${employee.resolvedCountryName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: inkColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getCurrencyBg(
                                  employee.targetCurrency.code, isDark),
                              borderRadius: FlowPayRadii.chip,
                            ),
                            child: Text(
                              employee.targetCurrency.code,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getCurrencyFg(
                                    employee.targetCurrency.code, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Payroll Amount (Target Currency + USD Equivalent)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PAYROLL AMOUNT',
                      style: FlowPayTypography.captionStyle(
                        color: textTertiaryColor,
                      ).copyWith(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payrollFormatted,
                      style: FlowPayTypography.amount(color: inkColor).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      usdFormatted,
                      style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: Wallet Status & Card Status Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: surfaceAltColor,
                borderRadius: FlowPayRadii.input,
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  // Wallet Status Chip
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 14, color: FlowPayColors.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WALLET STATUS',
                                style: FlowPayTypography.captionStyle(
                                  color: textTertiaryColor,
                                ).copyWith(fontSize: 9),
                              ),
                              Text(
                                _walletDisplay(employee),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: inkColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: borderColor,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Card Status Chip
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded,
                            size: 14, color: FlowPayColors.amber),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD STATUS',
                                style: FlowPayTypography.captionStyle(
                                  color: textTertiaryColor,
                                ).copyWith(fontSize: 9),
                              ),
                              Text(
                                _cardDisplay(employee),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: inkColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Failure banner + Retry — only for employees whose BMONI identity
            // creation failed, so the employer can see WHY and fix it without
            // re-entering everything.
            if (_isFailed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlowPayColors.error.withValues(alpha: 0.1),
                  borderRadius: FlowPayRadii.input,
                  border: Border.all(color: FlowPayColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: FlowPayColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Onboarding failed',
                            style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.error,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.failureReason ??
                                (employee.failedStage == 'BMONI_USER_CREATION'
                                    ? 'Employee account could not be created. Please retry.'
                                    : 'This employee could not be onboarded. Tap retry to try again.'),
                            style: FlowPayTypography.captionStyle(
                              color: textSecondaryColor,
                            ),
                          ),
                          if (onRetry != null) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: onRetry,
                              borderRadius: FlowPayRadii.chip,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: const BoxDecoration(
                                  color: FlowPayColors.error,
                                  borderRadius: FlowPayRadii.chip,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retry onboarding',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

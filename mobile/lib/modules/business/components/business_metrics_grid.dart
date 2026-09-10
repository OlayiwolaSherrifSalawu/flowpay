import 'package:flutter/material.dart';
import '../../../core/state/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Business Metrics Grid
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// Displays all 6 employer metrics in 20dp cards with hairline borders,
/// squircle icon containers, pill badges, and tabular figures for all numbers.
class BusinessMetricsGrid extends StatelessWidget {
  final BusinessProvider businessProvider;

  const BusinessMetricsGrid({super.key, required this.businessProvider});

  @override
  Widget build(BuildContext context) {
    final totalUsd = businessProvider.totalPayrollUsd;
    final pendingUsd = businessProvider.pendingPayrollUsd;
    final employeeCount = businessProvider.employeeCount;
    final onboardedCount = businessProvider.onboardedEmployeeCount;
    final walletsCount = businessProvider.walletsProvisionedCount;
    final cardsCount = businessProvider.cardsActiveCount;

    return Column(
      children: [
        // Metric Row 1: Total Payroll & Pending Payroll
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.payments_outlined,
                iconColor: FlowPayColors.primary,
                label: 'TOTAL PAYROLL',
                value: totalUsd.formatFormatted(),
                subtitle: 'Monthly aggregate run',
                badgeText: 'USD BASE',
                badgeBg: FlowPayColors.primary.withValues(alpha: 0.12),
                badgeFg: FlowPayColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.hourglass_top_outlined,
                iconColor: const Color(0xFFB45309),
                label: 'PENDING PAYROLL',
                value: pendingUsd.formatFormatted(),
                subtitle: 'Ready to disburse',
                badgeText: 'SCHEDULED',
                badgeBg: FlowPayColors.amber.withValues(alpha: 0.16),
                badgeFg: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Metric Row 2: Employee Count & Employee Status
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.people_outline_rounded,
                iconColor: FlowPayColors.primary,
                label: 'EMPLOYEE COUNT',
                value: '$employeeCount Members',
                subtitle: 'Global remote team',
                badgeText: 'TEAM',
                badgeBg: FlowPayColors.primary.withValues(alpha: 0.12),
                badgeFg: FlowPayColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.verified_user_outlined,
                iconColor: FlowPayColors.signal,
                label: 'EMPLOYEE STATUS',
                value: '$onboardedCount / $employeeCount Onboarded',
                subtitle: '100% KYC verified',
                badgeText: 'ACTIVE',
                badgeBg: FlowPayColors.signal.withValues(alpha: 0.12),
                badgeFg: FlowPayColors.signal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Metric Row 3: Countries & Wallet/Card Status
        Row(
          children: [
            const Expanded(
              child: _MetricCard(
                icon: Icons.public_rounded,
                iconColor: FlowPayColors.accent,
                label: 'COUNTRIES',
                value: '3 Active',
                subtitle: '🇳🇬 NG • 🇲🇽 MX • 🇨🇦 CA',
                badgeText: 'GLOBAL',
                badgeBg: Color(0x1F6366F1),
                badgeFg: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.credit_card_outlined,
                iconColor: FlowPayColors.signal,
                label: 'WALLET / CARD STATUS',
                value: '$walletsCount Wallets • $cardsCount Cards',
                subtitle: 'Hardware-secured & active',
                badgeText: 'LIVE',
                badgeBg: FlowPayColors.signal.withValues(alpha: 0.12),
                badgeFg: FlowPayColors.signal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;
  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeFg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;
    final textSecondaryColor =
        isDark ? FlowPayColors.darkTextSecondary : FlowPayColors.lightTextSecondary;
    final textTertiaryColor =
        isDark ? FlowPayColors.darkTextTertiary : FlowPayColors.lightTextTertiary;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPayRadii.cardSmall,
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: FlowPayRadii.chip,
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: FlowPayTypography.captionStyle(
              color: textTertiaryColor,
            ).copyWith(
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: FlowPayTypography.amount(color: inkColor).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: FlowPayTypography.captionStyle(
              color: textSecondaryColor,
            ).copyWith(
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

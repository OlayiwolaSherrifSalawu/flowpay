import 'package:flutter/material.dart';
import '../../../core/state/business_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/typography.dart';

/// Hero Bill Card
/// FlowPay Business Design System (Dribbble Fintech & Emerald Branding):
/// - 24dp card geometry (FlowPayRadii.card)
/// - Theme-adaptive canvas (lightSurface / darkSurface) with hairline border
/// - Headline: "One Employer. Many Countries. One Bill."
/// - Squircle globe icon container
/// - Tactile 3-pillar banner: 1 Employer • Many Countries • 1 Bill
/// - Tabular figures on aggregate settlement figures
/// - Signal emerald savings badge
class HeroBillCard extends StatelessWidget {
  final BusinessProvider businessProvider;
  final VoidCallback onRunPayroll;

  const HeroBillCard({
    super.key,
    required this.businessProvider,
    required this.onRunPayroll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = businessProvider.pendingPayroll;
    final totalUsd = businessProvider.totalPayrollUsd;
    final savedUsd = businessProvider.savedFeeUsd;
    final savedPct = businessProvider.savedPercentage.toStringAsFixed(0);

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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface,
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Core Message Hook Banner
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FlowPayColors.primary.withValues(alpha: 0.12),
                  borderRadius: FlowPayRadii.avatar,
                  border: Border.all(
                    color: FlowPayColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.public_rounded,
                    color: FlowPayColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One Employer. Many Countries. One Bill.',
                      style: FlowPayTypography.title(color: inkColor).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send international payroll to Nigeria & Mexico with instant virtual cards — paid in one simple USD bill.',
                      style: FlowPayTypography.captionStyle(
                        color: textSecondaryColor,
                      ).copyWith(
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Core Pillars: One Employer • Many Countries • One Bill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: surfaceAltColor,
              borderRadius: FlowPayRadii.chip,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business_rounded,
                        size: 14, color: FlowPayColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '1 Employer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
                Text('•', style: TextStyle(color: textTertiaryColor)),
                Row(
                  children: [
                    const Icon(Icons.public_rounded,
                        size: 14, color: FlowPayColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Many Countries',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
                Text('•', style: TextStyle(color: textTertiaryColor)),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 14, color: FlowPayColors.signal),
                    const SizedBox(width: 6),
                    Text(
                      '1 Bill',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 16),

          // Total Aggregate Bill Figure
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AGGREGATE PAYROLL',
                      style: FlowPayTypography.captionStyle(
                        color: textTertiaryColor,
                      ).copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      totalUsd.formatFormatted(),
                      style: FlowPayTypography.display(color: inkColor).copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FlowPayColors.signal.withValues(alpha: 0.12),
                  borderRadius: FlowPayRadii.chip,
                  border: Border.all(
                    color: FlowPayColors.signal.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        color: FlowPayColors.signal, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Saved ${savedUsd.formatFormatted()} ($savedPct%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FlowPayColors.signal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sub-metrics (Rail fee vs Wire)
          Row(
            children: [
              Text(
                'Transfer Fee: ${pending?.totalFeeUsd.formatFormatted() ?? "\$10.00"}',
                style: FlowPayTypography.captionStyle(
                  color: textSecondaryColor,
                ).copyWith(fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Traditional Wire: ~\$340.00',
                style: FlowPayTypography.captionStyle(
                  color: textTertiaryColor,
                ).copyWith(
                  decoration: TextDecoration.lineThrough,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

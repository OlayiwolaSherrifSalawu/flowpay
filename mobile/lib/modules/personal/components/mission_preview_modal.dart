import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/missions/mission_intent.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class MissionPreviewModal extends StatelessWidget {
  final MissionIntent intent;
  final VoidCallback onEdit;
  final VoidCallback onApprove;

  const MissionPreviewModal({
    super.key,
    required this.intent,
    required this.onEdit,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sourceAmountStr = intent.triggerCondition.sourceAmount;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1.2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title & Sparkle Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FlowPayColors.primary.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: FlowPayColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mission Plan Preview',
                        style: FlowPayTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? FlowPayColors.darkTextPrimary
                              : FlowPayColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI structured • Deterministically validated',
                        style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: FlowPayColors.darkTextSecondary),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Source Trigger Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurface
                    : FlowPayColors.lightSurfaceElevated,
                borderRadius: FlowPaySpacing.borderRadiusLg,
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WHEN PAYMENT ARRIVES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: FlowPayColors.darkTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sourceAmountStr.contains('2000') ||
                                  sourceAmountStr == '2000.00'
                              ? '\$2,000 incoming'
                              : (sourceAmountStr.isNotEmpty
                                  ? '\$$sourceAmountStr incoming'
                                  : 'Any incoming'),
                          style: FlowPayTypography.amount(
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ).copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trigger: ${intent.triggerCondition.type.toUpperCase()}',
                          style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: FlowPayColors.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: FlowPayColors.primaryLight),
                        SizedBox(width: 6),
                        Text(
                          '100% Allocated',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'ALLOCATION BREAKDOWN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FlowPayColors.darkTextSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // Allocations List
            ...intent.allocations.map((alloc) {
              final amountDisplay = () {
                if (alloc.targetAmountFormatted != null &&
                    alloc.targetAmountFormatted!.isNotEmpty) {
                  return alloc.targetAmountFormatted!;
                }
                final parsed = double.tryParse(alloc.sourceAmountFormatted
                    .replaceAll(RegExp(r'[^0-9.]'), ''));
                if (parsed != null &&
                    parsed == parsed.roundToDouble() &&
                    parsed > 0) {
                  return '\$${parsed.toInt()}';
                }
                return alloc.sourceAmountFormatted;
              }();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? FlowPayColors.darkSurface
                      : FlowPayColors.lightSurface,
                  borderRadius: FlowPaySpacing.borderRadiusMd,
                  border: Border.all(
                    color: isDark
                        ? FlowPayColors.darkBorder
                        : FlowPayColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 32,
                      decoration: BoxDecoration(
                        color: FlowPayColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${alloc.percentage.toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alloc.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? FlowPayColors.darkTextPrimary
                                  : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Destination: ${alloc.destinationWalletTag}',
                            style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          alloc.targetCurrency.code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: FlowPayColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Reassurance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: FlowPayColors.surfaceAlt,
                borderRadius: FlowPaySpacing.borderRadiusMd,
                border: Border.all(color: FlowPayColors.hairline),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 16, color: FlowPayColors.primaryLight),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing moves until you approve.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.ink,
                          ),
                        ),
                        Text(
                          'Requires explicit authorization with your on-device B-Key PIN.',
                          style: TextStyle(
                            fontSize: 11,
                            color: FlowPayColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Buttons: Edit and Approve Mission
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: FlowPayButton(
                    text: 'Edit',
                    variant: FlowPayButtonVariant.secondary,
                    size: FlowPayButtonSize.large,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FlowPayButton(
                    text: 'Approve Mission',
                    variant: FlowPayButtonVariant.primary,
                    size: FlowPayButtonSize.large,
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

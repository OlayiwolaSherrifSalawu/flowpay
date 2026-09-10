import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/missions/mission_intent.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkBackground : FlowPayColors.paper,
        borderRadius: FlowPayRadii.sheet,
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  borderRadius: FlowPayRadii.chip,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title & Sparkle Icon
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FlowPayColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FlowPayColors.primary.withAlpha(50),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: FlowPayColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
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
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: isDark
                        ? FlowPayColors.darkTextSecondary
                        : FlowPayColors.lightTextSecondary,
                  ),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Source Trigger Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurface
                    : Colors.white,
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 20 : 6),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.triggerCondition.type.toUpperCase() ==
                                  'BALANCE_THRESHOLD'
                              ? 'BALANCE THRESHOLD TRIGGER'
                              : 'WHEN PAYMENT ARRIVES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          intent.triggerCondition.type.toUpperCase() ==
                                  'BALANCE_THRESHOLD'
                              ? intent.triggerCondition.description
                              : (sourceAmountStr.contains('2000') ||
                                      sourceAmountStr == '2000.00'
                                  ? '\$2,000 incoming'
                                  : (sourceAmountStr.isNotEmpty
                                      ? '\$$sourceAmountStr incoming'
                                      : 'Any incoming')),
                          style: FlowPayTypography.amount(
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.lightTextPrimary,
                          ).copyWith(
                            fontSize: intent.triggerCondition.type.toUpperCase() ==
                                    'BALANCE_THRESHOLD'
                                ? 16
                                : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trigger: ${intent.triggerCondition.type.toUpperCase()}',
                          style: FlowPayTypography.captionStyle(
                            color: FlowPayColors.primary,
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
                      color: FlowPayColors.primary.withAlpha(24),
                      borderRadius: FlowPayRadii.chip,
                      border: Border.all(
                        color: FlowPayColors.primary.withAlpha(60),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: FlowPayColors.primary),
                        SizedBox(width: 6),
                        Text(
                          '100% Allocated',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FlowPayColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'ALLOCATION BREAKDOWN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? FlowPayColors.darkTextSecondary
                    : FlowPayColors.lightTextSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

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
                      : Colors.white,
                  borderRadius: FlowPayRadii.cardSmall,
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
                      height: 34,
                      decoration: BoxDecoration(
                        color: FlowPayColors.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
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
                              color: isDark
                                  ? FlowPayColors.darkTextSecondary
                                  : FlowPayColors.lightTextSecondary,
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

            const SizedBox(height: 14),

            // Reassurance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.mint100.withAlpha(60),
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(
                  color: isDark
                      ? FlowPayColors.darkBorder
                      : FlowPayColors.primary.withAlpha(40),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: FlowPayColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing moves until you approve.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? FlowPayColors.darkTextPrimary
                                : FlowPayColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Requires explicit authorization with your on-device B-Key PIN.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? FlowPayColors.darkTextSecondary
                                : FlowPayColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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

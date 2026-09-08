import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/financial_operator/models/financial_plan_models.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

/// FlowPay AI Financial Plan Card
/// Renders structured financial plans with action breakdown, before/after balance
/// projections, fee transparency, and explicit user approval controls.
class AiFinancialPlanCard extends StatelessWidget {
  final FinancialPlan plan;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;
  final bool isExecuting;

  const AiFinancialPlanCard({
    super.key,
    required this.plan,
    this.onApprove,
    this.onCancel,
    this.isExecuting = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: FlowPayColors.primary.withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: FlowPayColors.primary.withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Plan Title + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FlowPayColors.primary.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: FlowPayColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.title,
                  style: FlowPayTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.isApproved
                      ? FlowPayColors.primary.withAlpha(35)
                      : FlowPayColors.accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  plan.isApproved ? 'APPROVED' : 'AWAITING APPROVAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: plan.isApproved
                        ? FlowPayColors.primary
                        : FlowPayColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Actions List
          Text(
            'ACTIONS TO EXECUTE',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          ...plan.actions.map((act) => _buildActionRow(context, act, isDark)),

          const SizedBox(height: 12),
          const Divider(height: 1, color: FlowPayColors.darkBorder),
          const SizedBox(height: 12),

          // Balance Impact Projections
          Text(
            'PROJECTED BALANCES AFTER EXECUTION',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          ...plan.expectedBalanceChanges
              .map((impact) => _buildBalanceImpactRow(context, impact, isDark)),

          const SizedBox(height: 14),

          // Safety Reassurance Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FlowPayColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FlowPayColors.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: FlowPayColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nothing moves until you approve • Zero AI money movement',
                    style: FlowPayTypography.captionStyle(
                      color: isDark
                          ? FlowPayColors.darkTextSecondary
                          : FlowPayColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Approval Actions
          if (!plan.isApproved && onApprove != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: FlowPayButton(
                      text: 'Cancel',
                      variant: FlowPayButtonVariant.secondary,
                      size: FlowPayButtonSize.medium,
                      onPressed: isExecuting ? null : onCancel,
                    ),
                  ),
                if (onCancel != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FlowPayButton(
                    text: 'Approve & Execute',
                    icon: Icons.fingerprint,
                    isLoading: isExecuting,
                    size: FlowPayButtonSize.medium,
                    onPressed: isExecuting ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(
      BuildContext context, PlannedFinancialAction act, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceSubtle
            : FlowPayColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: act.type == PlannedActionType.send
                  ? FlowPayColors.primary.withAlpha(30)
                  : FlowPayColors.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              act.type.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: act.type == PlannedActionType.send
                    ? FlowPayColors.primary
                    : FlowPayColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.destinationName,
                  style: FlowPayTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? FlowPayColors.darkTextPrimary
                        : FlowPayColors.lightTextPrimary,
                  ),
                ),
                Text(
                  act.description,
                  style: FlowPayTypography.captionStyle(
                    color: FlowPayColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            act.amount.toFormattedString(),
            style: FlowPayTypography.bodyLg.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark
                  ? FlowPayColors.darkTextPrimary
                  : FlowPayColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceImpactRow(
      BuildContext context, BalanceImpact impact, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            impact.walletName,
            style: FlowPayTypography.captionStyle(
              color: isDark
                  ? FlowPayColors.darkTextSecondary
                  : FlowPayColors.lightTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '${impact.currentBalance.toFormattedString()}  →  ',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextMuted,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Text(
            impact.projectedBalance.toFormattedString(),
            style: FlowPayTypography.captionStyle(
              color: impact.isCredit
                  ? FlowPayColors.primary
                  : (isDark
                      ? FlowPayColors.darkTextPrimary
                      : FlowPayColors.lightTextPrimary),
            ).copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

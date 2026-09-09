import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/financial_operator/models/financial_plan_models.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

/// FlowPay AI Financial Plan Card
/// Renders structured financial plans with action breakdown, cross-border deliveries,
/// multi-wallet funding allocations, before/after balance projections, fee transparency,
/// quote expiration monitoring, route explanations, and explicit user approval controls.
class AiFinancialPlanCard extends StatefulWidget {
  final FinancialPlan plan;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onOverrideRoute;
  final VoidCallback? onAskWhy;
  final bool isExecuting;

  const AiFinancialPlanCard({
    super.key,
    required this.plan,
    this.onApprove,
    this.onCancel,
    this.onOverrideRoute,
    this.onAskWhy,
    this.isExecuting = false,
  });

  @override
  State<AiFinancialPlanCard> createState() => _AiFinancialPlanCardState();
}

class _AiFinancialPlanCardState extends State<AiFinancialPlanCard> {
  bool _showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.plan;
    final isExpired = plan.isQuoteExpired;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.lightSurface,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        border: Border.all(
          color: isExpired
              ? FlowPayColors.error.withAlpha(120)
              : FlowPayColors.primary.withAlpha(80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? FlowPayColors.error : FlowPayColors.primary).withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Plan Title + Status & Expiration Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
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
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (plan.actions.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlowPayColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${plan.actions.length} PAYMENTS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: FlowPayColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (plan.quoteExpiresAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? FlowPayColors.error.withAlpha(35)
                        : FlowPayColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: isExpired ? FlowPayColors.error : FlowPayColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired ? 'QUOTE EXPIRED' : 'LIVE QUOTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isExpired ? FlowPayColors.error : FlowPayColors.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // Shortfall notice if applicable
          if (plan.shortfall != null && plan.shortfall!.minorUnits > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FlowPayColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FlowPayColors.accent.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: FlowPayColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Multi-Wallet Auto-Balancing: ${plan.shortfall!.toFormattedString()} shortfall auto-funded via FX conversion.',
                      style: FlowPayTypography.captionStyle(
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions List
          Text(
            'ACTIONS TO EXECUTE (${plan.actions.length})',
            style: FlowPayTypography.captionStyle(
              color: FlowPayColors.darkTextMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          ...plan.actions.map((act) => _buildActionRow(context, act, isDark)),

          // Batch Total Box
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? FlowPayColors.darkSurfaceSubtle : FlowPayColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: FlowPayTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      plan.totalRequested.toFormattedString(),
                      style: FlowPayTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: FlowPayColors.primary,
                      ),
                    ),
                  ],
                ),
                if (plan.totalFee.minorUnits > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Fees',
                        style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.darkTextSecondary,
                        ),
                      ),
                      Text(
                        plan.totalFee.toFormattedString(),
                        style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.darkTextSecondary,
                        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Route Explanation ("Why this route?")
          if (plan.routeExplanation != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showExplanation = !_showExplanation;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? FlowPayColors.darkSurfaceSubtle
                      : FlowPayColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlowPayColors.primary.withAlpha(50),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 15,
                          color: FlowPayColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Why this funding route?',
                            style: FlowPayTypography.captionStyle(
                              color: FlowPayColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(
                          _showExplanation
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: FlowPayColors.primary,
                        ),
                      ],
                    ),
                    if (_showExplanation) ...[
                      const SizedBox(height: 6),
                      Text(
                        plan.routeExplanation!,
                        style: FlowPayTypography.captionStyle(
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : FlowPayColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Route Overrides Chips
          if (plan.availableRouteOverrides.isNotEmpty &&
              widget.onOverrideRoute != null) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    'Route override:',
                    style: FlowPayTypography.captionStyle(
                      color: FlowPayColors.darkTextMuted,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  ...plan.availableRouteOverrides.map((curr) {
                    final displayCode = curr
                        .replaceAll('Use ', '')
                        .replaceAll(' instead', '')
                        .trim();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => widget.onOverrideRoute!(displayCode),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FlowPayColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: FlowPayColors.primary.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            'Fund via $displayCode',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: FlowPayColors.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

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
                    'Zero AI money movement • B-Key cryptographic authorization required',
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
          if (!plan.isApproved && widget.onApprove != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onCancel != null)
                  Expanded(
                    child: FlowPayButton(
                      text: 'Cancel',
                      variant: FlowPayButtonVariant.secondary,
                      size: FlowPayButtonSize.medium,
                      onPressed: widget.isExecuting ? null : widget.onCancel,
                    ),
                  ),
                if (widget.onCancel != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FlowPayButton(
                    text: isExpired ? 'Quote Expired' : 'Approve & Execute',
                    icon: isExpired ? Icons.refresh_rounded : Icons.fingerprint,
                    isLoading: widget.isExecuting,
                    size: FlowPayButtonSize.medium,
                    onPressed: (widget.isExecuting || isExpired) ? null : widget.onApprove,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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

          // Cross-Border Delivery details if destination currency differs or destinationAmount is set
          if (act.destinationAmount != null || act.fxRate != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkSurfaceElevated
                    : FlowPayColors.lightSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff_rounded,
                      size: 13, color: FlowPayColors.accent),
                  const SizedBox(width: 6),
                  if (act.destinationAmount != null)
                    Expanded(
                      child: Text(
                        'Delivers ${act.destinationAmount!.toFormattedString()}${act.destinationRail != null ? ' via ${act.destinationRail}' : ''}',
                        style: FlowPayTypography.captionStyle(
                          color: FlowPayColors.accent,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (act.fxRate != null)
                    Text(
                      act.fxRate!,
                      style: FlowPayTypography.captionStyle(
                        color: FlowPayColors.darkTextMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
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

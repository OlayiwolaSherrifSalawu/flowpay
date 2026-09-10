import 'package:flutter/material.dart';
import '../../../core/design_system/buttons.dart';
import '../../../core/financial_operator/models/financial_plan_models.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
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
        color: isDark ? FlowPayColors.darkSurface : Colors.white,
        borderRadius: FlowPayRadii.card,
        border: Border.all(
          color: isExpired
              ? FlowPayColors.error.withAlpha(120)
              : FlowPayColors.emerald600.withAlpha(isDark ? 80 : 50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? FlowPayColors.error : FlowPayColors.emerald600).withAlpha(16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FlowPayColors.emerald600.withAlpha(isDark ? 40 : 25),
                  borderRadius: FlowPayRadii.avatar,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: FlowPayColors.emerald600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : FlowPayColors.ink,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlowPayColors.emerald600.withAlpha(isDark ? 35 : 20),
                    borderRadius: FlowPayRadii.chip,
                  ),
                  child: Text(
                    '${plan.actions.length} PAYMENTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (plan.quoteExpiresAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? FlowPayColors.error.withAlpha(25)
                        : FlowPayColors.emerald600.withAlpha(isDark ? 30 : 15),
                    borderRadius: FlowPayRadii.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: isExpired ? FlowPayColors.error : FlowPayColors.emerald600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired ? 'QUOTE EXPIRED' : 'LIVE QUOTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isExpired ? FlowPayColors.error : (isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.isApproved
                      ? FlowPayColors.emerald600.withAlpha(isDark ? 35 : 20)
                      : (isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF3F4F6)),
                  borderRadius: FlowPayRadii.chip,
                ),
                child: Text(
                  plan.isApproved ? 'APPROVED' : 'AWAITING APPROVAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: plan.isApproved
                        ? (isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700)
                        : (isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280)),
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
                color: FlowPayColors.emerald600.withAlpha(isDark ? 25 : 15),
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(color: FlowPayColors.emerald600.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: FlowPayColors.emerald600),
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
              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),

          ...plan.actions.map((act) => _buildActionRow(context, act, isDark)),

          // Batch Total Box
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? FlowPayColors.darkSurfaceElevated : const Color(0xFFF9FAFB),
              borderRadius: FlowPayRadii.cardSmall,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : FlowPayColors.ink,
                      ),
                    ),
                    Text(
                      plan.totalRequested.toFormattedString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: FlowPayColors.emerald600,
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
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        plan.totalFee.toFormattedString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? FlowPayColors.darkSurfaceElevated
                      : const Color(0xFFF9FAFB),
                  borderRadius: FlowPayRadii.cardSmall,
                  border: Border.all(
                    color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: FlowPayColors.emerald600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Why this funding route?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                            ),
                          ),
                        ),
                        Icon(
                          _showExplanation
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
                        ),
                      ],
                    ),
                    if (_showExplanation) ...[
                      const SizedBox(height: 8),
                      Text(
                        plan.routeExplanation!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? FlowPayColors.darkTextSecondary
                              : const Color(0xFF4B5563),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
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
                        borderRadius: FlowPayRadii.chip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: FlowPayColors.emerald600.withAlpha(isDark ? 30 : 20),
                            borderRadius: FlowPayRadii.chip,
                            border: Border.all(
                              color: FlowPayColors.emerald600.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            'Fund via $displayCode',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700,
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
          Divider(height: 1, color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder),
          const SizedBox(height: 12),

          // Balance Impact Projections
          Text(
            'PROJECTED BALANCES AFTER EXECUTION',
            style: FlowPayTypography.captionStyle(
              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
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
              color: FlowPayColors.emerald600.withAlpha(isDark ? 25 : 15),
              borderRadius: FlowPayRadii.cardSmall,
              border: Border.all(color: FlowPayColors.emerald600.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 15, color: FlowPayColors.emerald600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zero AI money movement • B-Key cryptographic authorization required',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? FlowPayColors.darkTextSecondary
                          : const Color(0xFF4B5563),
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
            ? FlowPayColors.darkSurfaceElevated
            : const Color(0xFFF9FAFB),
        borderRadius: FlowPayRadii.cardSmall,
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
                      ? FlowPayColors.emerald600.withAlpha(30)
                      : FlowPayColors.accent.withAlpha(30),
                  borderRadius: FlowPayRadii.chip,
                ),
                child: Text(
                  act.type.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: act.type == PlannedActionType.send
                        ? FlowPayColors.emerald600
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : FlowPayColors.ink,
                      ),
                    ),
                    Text(
                      act.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                act.amount.toFormattedString(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isDark ? Colors.white : FlowPayColors.ink,
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
                    ? FlowPayColors.darkSurface
                    : Colors.white,
                borderRadius: FlowPayRadii.cardSmall,
                border: Border.all(
                  color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
                ),
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FlowPayColors.accent,
                        ),
                      ),
                    ),
                  if (act.fxRate != null)
                    Text(
                      act.fxRate!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
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
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? FlowPayColors.darkTextSecondary
                  : const Color(0xFF4B5563),
            ),
          ),
          const Spacer(),
          Text(
            '${impact.currentBalance.toFormattedString()}  →  ',
            style: TextStyle(
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isDark ? FlowPayColors.darkTextSecondary : const Color(0xFF9CA3AF),
            ),
          ),
          Text(
            impact.projectedBalance.toFormattedString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: impact.isCredit
                  ? FlowPayColors.emerald600
                  : (isDark ? Colors.white : FlowPayColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

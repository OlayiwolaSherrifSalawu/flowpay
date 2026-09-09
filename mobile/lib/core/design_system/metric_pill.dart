import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';

/// Dribbble-inspired Metric Pill Card
/// Displays key financial indicators (e.g. Income vs Expense) with circular arrows and tabular amounts
class FlowPayMetricPill extends StatelessWidget {
  final String label;
  final String amount;
  final bool isIncome;
  final IconData? icon;
  final Color? customColor;
  final VoidCallback? onTap;

  const FlowPayMetricPill({
    super.key,
    required this.label,
    required this.amount,
    this.isIncome = true,
    this.icon,
    this.customColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = customColor ??
        (isIncome ? FlowPayColors.warning : FlowPayColors.emerald600);

    final bgColor = isDark
        ? (isIncome
            ? const Color(0xFF262114)
            : const Color(0xFF14291F))
        : (isIncome
            ? const Color(0xFFFBF4D8)
            : const Color(0xFFD8F0E4));

    final iconBgColor = isIncome
        ? FlowPayColors.warning.withAlpha(isDark ? 80 : 180)
        : FlowPayColors.emerald600.withAlpha(isDark ? 80 : 180);

    final defaultIcon =
        isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: FlowPayRadii.cardSmall,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: FlowPayRadii.cardSmall,
            border: Border.all(
              color: primaryColor.withAlpha(isDark ? 50 : 35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    icon ?? defaultIcon,
                    size: 18,
                    color: isDark ? Colors.white : FlowPayColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlowPayTypography.caption.copyWith(
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlowPayTypography.financialSmall.copyWith(
                        color: isDark
                            ? FlowPayColors.darkTextPrimary
                            : FlowPayColors.lightTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper container rendering paired Income & Expense metric pills side by side
class FlowPayIncomeExpenseRow extends StatelessWidget {
  final String incomeAmount;
  final String expenseAmount;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  const FlowPayIncomeExpenseRow({
    super.key,
    required this.incomeAmount,
    required this.expenseAmount,
    this.onIncomeTap,
    this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FlowPayMetricPill(
          label: 'Income',
          amount: incomeAmount,
          isIncome: true,
          onTap: onIncomeTap,
        ),
        const SizedBox(width: 12),
        FlowPayMetricPill(
          label: 'Expense',
          amount: expenseAmount,
          isIncome: false,
          onTap: onExpenseTap,
        ),
      ],
    );
  }
}

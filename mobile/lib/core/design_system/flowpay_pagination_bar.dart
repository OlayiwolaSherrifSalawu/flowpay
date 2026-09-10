import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';

/// FlowPayPaginationBar
/// A refined, theme-adaptive pagination control adhering to the FlowPay Design System.
/// Provides compact mobile navigation, localized loading states, disabled boundaries,
/// and tabular figure ranges ("Showing 1–10 of 47").
class FlowPayPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final bool isLoading;
  final String? itemLabel;

  const FlowPayPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.pageSize = 10,
    required this.onPageChanged,
    this.isLoading = false,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? FlowPayColors.darkSurfaceElevated
        : FlowPayColors.lightSurfaceElevated;
    final borderColor =
        isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder;
    final textSecondaryColor = isDark
        ? FlowPayColors.darkTextSecondary
        : FlowPayColors.lightTextSecondary;
    final inkColor =
        isDark ? FlowPayColors.darkTextPrimary : FlowPayColors.ink;

    final int safePage = currentPage.clamp(1, max(1, totalPages)).toInt();
    final hasPrevious = safePage > 1 && !isLoading;
    final hasNext = safePage < totalPages && !isLoading;

    final startIdx = (safePage - 1) * pageSize + 1;
    final endIdx = min(safePage * pageSize, totalItems);
    final labelSuffix = itemLabel != null ? ' $itemLabel' : '';
    final rangeText = 'Showing $startIdx–$endIdx of $totalItems$labelSuffix';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: FlowPayRadii.cardSmall,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Tabular Range Label
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    rangeText,
                    key: const Key('pagination_range_label'),
                    style: FlowPayTypography.captionStyle(
                      color: textSecondaryColor,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlowPayColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Compact Navigation Controls (< 2 / 5 >)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous Button
              _PaginationButton(
                key: const Key('pagination_prev_button'),
                icon: Icons.chevron_left_rounded,
                label: 'Prev',
                isEnabled: hasPrevious,
                isDark: isDark,
                onTap: hasPrevious ? () => onPageChanged(safePage - 1) : null,
              ),

              const SizedBox(width: 6),

              // Current Page Indicator Pill
              Container(
                key: const Key('pagination_page_indicator'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? FlowPayColors.darkSurface
                      : FlowPayColors.lightSurface,
                  borderRadius: FlowPayRadii.chip,
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '$safePage / ${max(1, totalPages)}',
                  style: FlowPayTypography.captionStyle(
                    color: inkColor,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Next Button
              _PaginationButton(
                key: const Key('pagination_next_button'),
                icon: Icons.chevron_right_rounded,
                label: 'Next',
                isEnabled: hasNext,
                isDark: isDark,
                isNext: true,
                onTap: hasNext ? () => onPageChanged(safePage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final bool isDark;
  final bool isNext;
  final VoidCallback? onTap;

  const _PaginationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.isDark,
    this.isNext = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? FlowPayColors.primary.withValues(alpha: 0.16)
        : FlowPayColors.mint100;
    final disabledBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.03);

    final activeBorder = isDark
        ? FlowPayColors.primary.withValues(alpha: 0.35)
        : FlowPayColors.emerald400.withValues(alpha: 0.35);
    final disabledBorder = isDark
        ? FlowPayColors.darkBorder.withValues(alpha: 0.4)
        : FlowPayColors.lightBorder.withValues(alpha: 0.4);

    final activeFg =
        isDark ? FlowPayColors.emerald400 : FlowPayColors.emerald700;
    final disabledFg = isDark
        ? FlowPayColors.darkTextSecondary.withValues(alpha: 0.3)
        : FlowPayColors.lightTextSecondary.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: FlowPayRadii.chip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isEnabled ? activeBg : disabledBg,
            borderRadius: FlowPayRadii.chip,
            border: Border.all(
              color: isEnabled ? activeBorder : disabledBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isNext)
                Icon(icon, size: 16, color: isEnabled ? activeFg : disabledFg),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? activeFg : disabledFg,
                  letterSpacing: 0.3,
                ),
              ),
              if (isNext)
                Icon(icon, size: 16, color: isEnabled ? activeFg : disabledFg),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/typography.dart';

/// Single Quick Action Item Data
class QuickActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
  });
}

/// Dribbble-inspired Quick Action Row (Deposit, Transfer, Withdraw, More)
/// Features 4 pillowed squircle action buttons with soft mint/paper background
class FlowPayQuickActionRow extends StatelessWidget {
  final VoidCallback? onDeposit;
  final VoidCallback? onTransfer;
  final VoidCallback? onWithdraw;
  final VoidCallback? onMore;
  final List<QuickActionItem>? customItems;

  const FlowPayQuickActionRow({
    super.key,
    this.onDeposit,
    this.onTransfer,
    this.onWithdraw,
    this.onMore,
    this.customItems,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultItems = [
      QuickActionItem(
        label: 'Deposit',
        icon: Icons.south_west_rounded,
        onTap: onDeposit ?? () {},
      ),
      QuickActionItem(
        label: 'Transfer',
        icon: Icons.sync_alt_rounded,
        onTap: onTransfer ?? () {},
      ),
      QuickActionItem(
        label: 'Withdraw',
        icon: Icons.north_east_rounded,
        onTap: onWithdraw ?? () {},
      ),
      QuickActionItem(
        label: 'More',
        icon: Icons.grid_view_rounded,
        onTap: onMore ?? () {},
      ),
    ];

    final items = customItems ?? defaultItems;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items.map((item) {
        final bg = item.backgroundColor ??
            (isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.mint100.withAlpha(150));
        final fg = item.iconColor ??
            (isDark
                ? FlowPayColors.darkTextPrimary
                : FlowPayColors.ink);

        return GestureDetector(
          onTap: item.onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: FlowPayRadii.quickAction,
                  border: Border.all(
                    color: isDark
                        ? FlowPayColors.darkBorder
                        : FlowPayColors.mint100,
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x080F1712),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: Icon(item.icon, color: fg, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: FlowPayTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? FlowPayColors.darkTextSecondary
                      : FlowPayColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

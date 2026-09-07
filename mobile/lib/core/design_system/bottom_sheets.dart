import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class FlowPayBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottomAction;
  final bool showCloseButton;

  const FlowPayBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.bottomAction,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FlowPaySpacing.radiusXl),
            ),
            border: Border.all(
              color:
                  isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? FlowPayColors.darkBorderLight
                        : FlowPayColors.lightBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FlowPaySpacing.xl,
                  vertical: FlowPaySpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: FlowPayTypography.headingSm.copyWith(
                              color: isDark
                                  ? FlowPayColors.darkTextPrimary
                                  : FlowPayColors.lightTextPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: FlowPayTypography.caption.copyWith(
                                color: isDark
                                    ? FlowPayColors.darkTextSecondary
                                    : FlowPayColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        color: isDark
                            ? FlowPayColors.darkTextSecondary
                            : FlowPayColors.lightTextSecondary,
                      ),
                  ],
                ),
              ),
              const Divider(),

              // Body Content
              Padding(
                padding: FlowPaySpacing.insetXl,
                child: child,
              ),

              // Sticky Bottom Action
              if (bottomAction != null) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    left: FlowPaySpacing.xl,
                    right: FlowPaySpacing.xl,
                    bottom: FlowPaySpacing.lg,
                  ),
                  child: bottomAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showFlowPayBottomSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  Widget? bottomAction,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FlowPayBottomSheet(
      title: title,
      subtitle: subtitle,
      bottomAction: bottomAction,
      child: child,
    ),
  );
}

/// Selector bottom sheet for choosing from a list of options with FlowPay styling
class FlowPaySelectorBottomSheet<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final T? selectedItem;
  final String title;
  final String Function(T)? label;
  final String Function(T)? itemTitle;
  final String Function(T)? itemSubtitle;
  final dynamic Function(T)? value;
  final bool showIcon;
  final ValueChanged<T>? onItemSelected;

  const FlowPaySelectorBottomSheet({
    super.key,
    required this.items,
    this.selected,
    this.selectedItem,
    required this.title,
    this.label,
    this.itemTitle,
    this.itemSubtitle,
    this.value,
    this.showIcon = false,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = selected ?? selectedItem;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? FlowPayColors.darkBorderLight
                    : FlowPayColors.lightBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: FlowPayTypography.headingSm.copyWith(
              color: isDark
                  ? FlowPayColors.darkTextPrimary
                  : FlowPayColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? FlowPayColors.darkBorder
                    : FlowPayColors.lightBorder,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = effectiveSelected == item;
                final text = label?.call(item) ??
                    itemTitle?.call(item) ??
                    item.toString();
                final subtitle = itemSubtitle?.call(item);

                return InkWell(
                  onTap: () {
                    onItemSelected?.call(item);
                    Navigator.of(context).pop(item);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FlowPayColors.primary.withAlpha(25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: FlowPayTypography.bodyMd.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? FlowPayColors.primaryLight
                                      : (isDark
                                          ? FlowPayColors.darkTextPrimary
                                          : FlowPayColors.lightTextPrimary),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: FlowPayTypography.caption.copyWith(
                                    color: isDark
                                        ? FlowPayColors.darkTextSecondary
                                        : FlowPayColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: FlowPayColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Backwards-compatible alias for SelectorBottomSheet
typedef SelectorBottomSheet<T> = FlowPaySelectorBottomSheet<T>;

/// Compatibility helper for bottom sheet display
class BMoniBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => child,
    );
  }
}


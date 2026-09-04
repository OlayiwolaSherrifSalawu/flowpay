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

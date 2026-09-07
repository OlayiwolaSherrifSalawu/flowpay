import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'buttons.dart';

class FlowPayDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;

  const FlowPayDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? FlowPayColors.darkSurfaceElevated
          : FlowPayColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: FlowPaySpacing.borderRadiusXl,
        side: BorderSide(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: FlowPaySpacing.insetXxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (iconColor ??
                          (isDestructive
                              ? FlowPayColors.error
                              : FlowPayColors.primary))
                      .withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor ??
                      (isDestructive
                          ? FlowPayColors.error
                          : FlowPayColors.primaryLight),
                ),
              ),
              const SizedBox(height: FlowPaySpacing.lg),
            ],
            Text(
              title,
              style: FlowPayTypography.headingSm.copyWith(
                color: isDark
                    ? FlowPayColors.darkTextPrimary
                    : FlowPayColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FlowPaySpacing.sm),
            Text(
              message,
              style: FlowPayTypography.bodyMd.copyWith(
                color: isDark
                    ? FlowPayColors.darkTextSecondary
                    : FlowPayColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FlowPaySpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: FlowPayButton(
                    text: cancelText,
                    variant: FlowPayButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      onCancel?.call();
                    },
                  ),
                ),
                const SizedBox(width: FlowPaySpacing.md),
                Expanded(
                  child: FlowPayButton(
                    text: confirmText,
                    variant: isDestructive
                        ? FlowPayButtonVariant.danger
                        : FlowPayButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
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

Future<bool?> showFlowPayConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  IconData? icon,
  Color? iconColor,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => FlowPayDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      iconColor: iconColor,
      isDestructive: isDestructive,
      onConfirm: () {},
    ),
  );
}

/// FlowPay Toast Feedback Utility
class FlowPayToast {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: FlowPayColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: FlowPayColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: FlowPayColors.info, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Backwards compatibility wrapper for toast notifications
class BMoniToastOverlay {
  static void showSuccess({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    FlowPayToast.showSuccess(
      context,
      message != null && message.isNotEmpty ? '$title: $message' : title,
    );
  }

  static void showError({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    FlowPayToast.showError(
      context,
      message != null && message.isNotEmpty ? '$title: $message' : title,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    FlowPayToast.showInfo(
      context,
      message != null && message.isNotEmpty ? '$title: $message' : title,
    );
  }
}


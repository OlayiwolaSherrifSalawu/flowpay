import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class FlowPayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;

  const FlowPayCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? FlowPayColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: border ?? Border.all(color: FlowPayColors.border, width: 1),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: decoration,
          child: child,
        ),
      );
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: decoration,
      child: child,
    );
  }
}

class FlowPayButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;

  const FlowPayButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = isSecondary ? FlowPayColors.surfaceElevated : FlowPayColors.primary;
    final fg = isSecondary ? FlowPayColors.textPrimary : Colors.white;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSecondary
              ? const BorderSide(color: FlowPayColors.border, width: 1)
              : BorderSide.none,
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'LINKED':
      case 'SUCCESS':
        bg = FlowPayColors.accent.withOpacity(0.15);
        fg = FlowPayColors.accentLight;
        break;
      case 'PENDING':
      case 'INVITED':
        bg = FlowPayColors.warning.withOpacity(0.15);
        fg = FlowPayColors.warning;
        break;
      case 'FROZEN':
      case 'SUSPENDED':
      case 'FAILED':
        bg = FlowPayColors.error.withOpacity(0.15);
        fg = FlowPayColors.error;
        break;
      default:
        bg = FlowPayColors.surfaceElevated;
        fg = FlowPayColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlowPayColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: FlowPayColors.border),
              ),
              child: Icon(icon, size: 36, color: FlowPayColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(title, style: FlowPayTypography.headingSm),
            const SizedBox(height: 8),
            Text(
              description,
              style: FlowPayTypography.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              FlowPayButton(text: actionText!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

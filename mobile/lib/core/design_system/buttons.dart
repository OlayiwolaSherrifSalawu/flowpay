import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';

enum FlowPayButtonVariant { primary, secondary, outline, ghost, danger }

enum FlowPayButtonSize { small, medium, large }

/// Dribbble-inspired FlowPay Pill Button
/// Features full pill geometry (9999dp), confident Emerald 600 primary action styling,
/// tactile padding, and built-in loading indicator.
class FlowPayButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final FlowPayButtonVariant variant;
  final FlowPayButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final IconData? suffixIcon;
  final bool isFullWidth;
  final bool disabled;

  const FlowPayButton({
    super.key,
    required this.text,
    required this.onPressed,
    FlowPayButtonVariant? variant,
    bool isSecondary = false,
    this.size = FlowPayButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.suffixIcon,
    this.isFullWidth = false,
    this.disabled = false,
  }) : variant = variant ??
            (isSecondary
                ? FlowPayButtonVariant.secondary
                : FlowPayButtonVariant.primary);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case FlowPayButtonVariant.primary:
        bg = FlowPayColors.emerald600;
        fg = Colors.white;
        break;
      case FlowPayButtonVariant.secondary:
        bg = isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.mint100.withAlpha(120);
        fg = isDark
            ? FlowPayColors.darkTextPrimary
            : FlowPayColors.ink;
        borderSide = BorderSide(
          color: isDark
              ? FlowPayColors.darkBorderLight
              : FlowPayColors.mint100,
          width: 1,
        );
        break;
      case FlowPayButtonVariant.outline:
        bg = Colors.transparent;
        fg = FlowPayColors.emerald600;
        borderSide =
            const BorderSide(color: FlowPayColors.emerald600, width: 1.5);
        break;
      case FlowPayButtonVariant.ghost:
        bg = Colors.transparent;
        fg = isDark
            ? FlowPayColors.darkTextSecondary
            : FlowPayColors.lightTextSecondary;
        break;
      case FlowPayButtonVariant.danger:
        bg = FlowPayColors.error;
        fg = Colors.white;
        break;
    }

    EdgeInsets padding;
    double fontSize;
    double iconSize;
    double? minHeight;

    switch (size) {
      case FlowPayButtonSize.small:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        fontSize = 13;
        iconSize = 16;
        minHeight = 36;
        break;
      case FlowPayButtonSize.medium:
        padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
        fontSize = 14;
        iconSize = 18;
        minHeight = 46;
        break;
      case FlowPayButtonSize.large:
        padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
        fontSize = 16;
        iconSize = 20;
        minHeight = 54;
        break;
    }

    Widget content = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: fg),
                const SizedBox(width: FlowPaySpacing.sm),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: -0.2,
                ),
              ),
              if (suffixIcon != null) ...[
                const SizedBox(width: FlowPaySpacing.sm),
                Icon(suffixIcon, size: iconSize, color: fg),
              ],
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: minHeight,
      child: ElevatedButton(
        onPressed: isLoading || disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: padding,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: FlowPayRadii.button,
            side: borderSide,
          ),
          shadowColor: Colors.transparent,
        ),
        child: content,
      ),
    );
  }
}

class FlowPayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  const FlowPayIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.backgroundColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark
            ? FlowPayColors.darkSurfaceElevated
            : FlowPayColors.lightSurfaceElevated);
    final fg = color ??
        (isDark
            ? FlowPayColors.darkTextPrimary
            : FlowPayColors.lightTextPrimary);

    return Semantics(
      button: true,
      label: tooltip ?? 'Action button',
      child: Tooltip(
        message: tooltip ?? '',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(size / 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? FlowPayColors.darkBorder
                        : FlowPayColors.lightBorder,
                  ),
                ),
                child: Icon(icon, size: size * 0.5, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Backward-compatibility aliases
typedef BMoniButton = FlowPayButton;
typedef BMoniButtonVariant = FlowPayButtonVariant;
typedef BMoniButtonSize = FlowPayButtonSize;

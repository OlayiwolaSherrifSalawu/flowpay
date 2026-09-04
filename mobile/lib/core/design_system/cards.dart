import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum FlowPayCardVariant { surface, elevated, outlined, accent }

class FlowPayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final FlowPayCardVariant variant;
  final BorderRadius? borderRadius;

  const FlowPayCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.variant = FlowPayCardVariant.surface,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? FlowPaySpacing.borderRadiusLg;

    Color bg;
    Border? b = border;

    switch (variant) {
      case FlowPayCardVariant.surface:
        bg = backgroundColor ??
            (isDark ? FlowPayColors.darkSurface : FlowPayColors.lightSurface);
        b ??= Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1,
        );
        break;
      case FlowPayCardVariant.elevated:
        bg = backgroundColor ??
            (isDark
                ? FlowPayColors.darkSurfaceElevated
                : FlowPayColors.lightSurfaceElevated);
        b ??= Border.all(
          color: isDark
              ? FlowPayColors.darkBorderLight
              : FlowPayColors.lightBorderLight,
          width: 1,
        );
        break;
      case FlowPayCardVariant.outlined:
        bg = Colors.transparent;
        b ??= Border.all(
          color: isDark ? FlowPayColors.darkBorder : FlowPayColors.lightBorder,
          width: 1.5,
        );
        break;
      case FlowPayCardVariant.accent:
        bg = isDark
            ? FlowPayColors.primary.withAlpha(25)
            : FlowPayColors.primary.withAlpha(15);
        b ??= Border.all(
          color: FlowPayColors.primary.withAlpha(100),
          width: 1,
        );
        break;
    }

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: r,
      border: b,
    );

    final resolvedPadding = padding ?? FlowPaySpacing.insetXl;

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Container(
          padding: resolvedPadding,
          decoration: decoration,
          child: child,
        ),
      );
    }

    return Container(
      padding: resolvedPadding,
      decoration: decoration,
      child: child,
    );
  }
}

class FlowPayStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const FlowPayStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? FlowPayColors.primaryLight;

    return FlowPayCard(
      onTap: onTap,
      padding: FlowPaySpacing.insetLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: FlowPayTypography.caption.copyWith(
                  color: isDark
                      ? FlowPayColors.darkTextSecondary
                      : FlowPayColors.lightTextSecondary,
                ),
              ),
              const Spacer(),
              if (icon != null) Icon(icon, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: FlowPaySpacing.sm),
          Text(
            value,
            style: FlowPayTypography.headingSm.copyWith(
              color: isDark
                  ? FlowPayColors.darkTextPrimary
                  : FlowPayColors.lightTextPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: FlowPaySpacing.xs),
            Text(
              subtitle!,
              style: FlowPayTypography.caption.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }
}

class FlowPayGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;

  const FlowPayGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = gradientColors ??
        (isDark
            ? [
                FlowPayColors.darkSurfaceElevated,
                FlowPayColors.darkSurface,
              ]
            : [
                FlowPayColors.lightSurface,
                FlowPayColors.lightSurfaceElevated,
              ]);

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: FlowPaySpacing.borderRadiusXl,
      border: Border.all(
        color: isDark
            ? FlowPayColors.darkBorderLight.withAlpha(120)
            : FlowPayColors.lightBorderLight,
        width: 1.2,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: FlowPaySpacing.borderRadiusXl,
        child: Container(
          padding: padding ?? FlowPaySpacing.insetXxl,
          decoration: decoration,
          child: child,
        ),
      );
    }

    return Container(
      padding: padding ?? FlowPaySpacing.insetXxl,
      decoration: decoration,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum FlowPayCardVariant { surface, elevated, outlined, accent, heroEmerald, heroInk }

/// FlowPay Card Primitive
/// Conforms to Dribbble Reference: 24dp pillowed radius with soft, tactile borders
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
    final r = borderRadius ?? FlowPayRadii.card;

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
            ? FlowPayColors.emerald700.withAlpha(45)
            : FlowPayColors.mint100;
        b ??= Border.all(
          color: FlowPayColors.primary.withAlpha(80),
          width: 1,
        );
        break;
      case FlowPayCardVariant.heroEmerald:
        bg = FlowPayColors.emerald600;
        b ??= Border.all(
          color: FlowPayColors.emerald400.withAlpha(120),
          width: 1,
        );
        break;
      case FlowPayCardVariant.heroInk:
        bg = isDark ? FlowPayColors.darkSurfaceElevated : FlowPayColors.ink;
        b ??= Border.all(
          color: isDark ? FlowPayColors.darkBorderLight : FlowPayColors.hairline,
          width: 1,
        );
        break;
    }

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: r,
      border: b,
      boxShadow: isDark
          ? null
          : const [
              BoxShadow(
                color: Color(0x0A0F1712),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
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

/// Dribbble-inspired Organic Scalloped Card
/// Features signature pillowed corners (28dp), top brand header, masked account number,
/// and holder / expiry information with tactile action pill button.
class FlowPayScallopedCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? maskedNumber;
  final String? balance;
  final String holderName;
  final String? expiryDate;
  final String? actionLabel;
  final Widget? trailingAction;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;
  final bool isEmerald;
  final LinearGradient? gradient;
  final Widget? customContent;

  const FlowPayScallopedCard({
    super.key,
    required this.title,
    this.subtitle,
    this.maskedNumber,
    this.balance,
    required this.holderName,
    this.expiryDate,
    this.actionLabel,
    this.trailingAction,
    this.onActionTap,
    this.onTap,
    this.isEmerald = true,
    this.gradient,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    final cardGradient = gradient ??
        (isEmerald
            ? const LinearGradient(
                colors: [
                  Color(0xFF149E72),
                  Color(0xFF128A63),
                  Color(0xFF0B6E4F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF1B2422),
                  Color(0xFF0F1712),
                  Color(0xFF0C1210),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ));

    const textColor = Colors.white;
    final subtextColor = isEmerald
        ? const Color(0xFFD8F0E4)
        : const Color(0xFFA3B8AD);

    return InkWell(
      onTap: onTap,
      borderRadius: FlowPayRadii.cardLarge,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: FlowPayRadii.cardLarge,
          boxShadow: [
            BoxShadow(
              color: isEmerald
                  ? FlowPayColors.emerald600.withAlpha(70)
                  : const Color(0x33000000),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Brand / Type + Action Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: FlowPayRadii.chip,
                      ),
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (trailingAction != null)
                  trailingAction!
                else if (onActionTap != null)
                  InkWell(
                    onTap: onActionTap,
                    borderRadius: FlowPayRadii.chip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: FlowPayRadii.chip,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actionLabel != null) ...[
                            Text(
                              actionLabel!,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: textColor,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Middle: Balance or Masked Card Number
            if (customContent != null)
              customContent!
            else if (balance != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance!,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              )
            else if (maskedNumber != null)
              Text(
                maskedNumber!,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                  fontFamily: 'monospace',
                ),
              ),

            const SizedBox(height: 16),

            // Bottom Row: Holder Name & Expiry / Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holder',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      holderName,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (expiryDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Exp Date',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expiryDate!,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dribbble-inspired Stacked Card Deck
/// Renders a hero card with back cards peeking out at the top with recognizable brand tabs
class FlowPayCardDeck extends StatelessWidget {
  final Widget heroCard;
  final List<Widget>? backCardTabs;

  const FlowPayCardDeck({
    super.key,
    required this.heroCard,
    this.backCardTabs,
  });

  @override
  Widget build(BuildContext context) {
    if (backCardTabs == null || backCardTabs!.isEmpty) {
      return heroCard;
    }

    return Column(
      children: [
        // Peeking tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: backCardTabs!,
          ),
        ),
        const SizedBox(height: 6),
        heroCard,
      ],
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
      borderRadius: FlowPayRadii.cardLarge,
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
        borderRadius: FlowPayRadii.cardLarge,
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

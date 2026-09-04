import 'package:flutter/material.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

export '../design_system/buttons.dart';
export '../design_system/cards.dart';
export '../design_system/states.dart';
export '../design_system/status_badges.dart';

/// Powered By BMoni Indicator Badge
class PoweredByBmoniBadge extends StatelessWidget {
  const PoweredByBmoniBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FlowPayColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlowPayColors.hairline),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: FlowPayColors.primary),
          SizedBox(width: 4),
          Text(
            'Powered by BMoni',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FlowPayColors.ink,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Revolut-style Segmented Role Switch [ Personal | Business ]
/// Conforms to design.md §2.4 & §4.4: Universal pill container and active segment.
class SegmentedRoleSwitch extends StatelessWidget {
  final bool isPersonal;
  final ValueChanged<bool> onRoleChanged;

  const SegmentedRoleSwitch({
    super.key,
    required this.isPersonal,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: FlowPayColors.surfaceAlt,
        borderRadius: FlowPayRadii.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment('Personal', isPersonal, () => onRoleChanged(true)),
          _buildSegment('Business', !isPersonal, () => onRoleChanged(false)),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? FlowPayColors.ink : Colors.transparent,
          borderRadius: FlowPayRadii.button,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : FlowPayColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// FlowPay Virtual Spend Card Object
/// Conforms strictly to design.md §4.5 & §3.5:
/// Aspect ratio 1.586, FlowPay Amber fill, masked PAN, Mastercard logo,
/// Virtual Card as an Object
/// Built strictly to design.md §4.5:
/// - FlowPay Amber (#F4B740) surface (not default bkey_uikit plum)
/// - Soft physical shadow (Color(0x1A0D2E2A), blur 24, offset (0, 8))
/// - Tabular numbers with wide letter-spacing
/// - Distinct visual state ("Issuing...") for reserved card proposals (isReserved: true)
/// - Frozen state styling (BLOCKED / FROZEN)
/// - Mastercard overlapping circles & contactless glyph
class VirtualCardObject extends StatelessWidget {
  final String cardLast4;
  final String countryFlag;
  final String cardHolderName;
  final String cardName;
  final String currencyCode;
  final bool isFrozen;
  final bool isReserved;
  final String? proposalStatus;
  final VoidCallback? onTap;

  static const Color flowpayAmber = Color(0xFFF4B740);

  const VirtualCardObject({
    super.key,
    required this.cardLast4,
    required this.countryFlag,
    required this.cardHolderName,
    this.cardName = 'FlowPay Spend Card',
    this.currencyCode = 'NGN',
    this.isFrozen = false,
    this.isReserved = false,
    this.proposalStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Card face color resolution
    final Color cardBackground;
    if (isReserved) {
      cardBackground = const Color(0xFF332612); // Deep Amber-bronze for issuing state
    } else if (isFrozen) {
      cardBackground = const Color(0xFF2C2D35); // Slate frozen surface
    } else {
      cardBackground = flowpayAmber; // FlowPay Amber #F4B740
    }

    final Color textColor = (isReserved || isFrozen)
        ? FlowPayColors.ink
        : const Color(0xFF1E1B18); // Dark contrast ink on vibrant amber

    return AspectRatio(
      aspectRatio: 1.586,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: FlowPayRadii.card,
            border: isReserved
                ? Border.all(color: flowpayAmber.withValues(alpha: 0.5), width: 1.5)
                : (isFrozen ? Border.all(color: Colors.white24, width: 1) : null),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0D2E2A),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Brand, Currency & Country Flag, Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'FlowPay',
                        style: FlowPayTypography.title(color: textColor).copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currencyCode.toUpperCase(),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isReserved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: flowpayAmber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: flowpayAmber.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: flowpayAmber,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                proposalStatus != null
                                    ? (proposalStatus!.contains('SIGN')
                                        ? 'Sign Needed'
                                        : 'Issuing...')
                                    : 'Issuing...',
                                style: const TextStyle(
                                  color: flowpayAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isFrozen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.ac_unit_rounded, size: 10, color: Colors.white70),
                              SizedBox(width: 4),
                              Text(
                                'FROZEN',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(countryFlag, style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                ],
              ),

              // Middle: Chip & Contactless Glyph
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 24,
                    decoration: BoxDecoration(
                      color: (isReserved || isFrozen)
                          ? Colors.white24
                          : const Color(0xFFD49B2A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.contactless_rounded,
                    size: 18,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ],
              ),

              // Bottom Area: Masked PAN, Cardholder Name, Mastercard Logo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReserved ? '•••• •••• •••• ••••' : '•••• •••• •••• $cardLast4',
                    style: FlowPayTypography.amount(color: textColor).copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cardName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              cardHolderName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlowPayTypography.captionStyle(color: textColor).copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mastercard Interlocking Spheres
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEB001B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF79E1B).withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BMONI Status Type Enum
enum StatusType {
  warning,
  success,
  error,
  neutral,
  info,
}

extension StatusTypeX on StatusType {
  Color get color {
    switch (this) {
      case StatusType.warning:
        return FlowPayColors.warning; // #FFB300
      case StatusType.success:
        return FlowPayColors.accent;  // Electric brand accent / success
      case StatusType.error:
        return FlowPayColors.error;   // #FF5252
      case StatusType.neutral:
        return FlowPayColors.darkTextSecondary;
      case StatusType.info:
        return FlowPayColors.info;    // #2B88D1
    }
  }
}

/// Official BMoni UI Kit StatusText component
/// Renders a coloured status badge string adhering strictly to bkey_uikit standards:
/// StatusText('Pending',  status: StatusType.warning)
/// StatusText('Active',   status: StatusType.success)
/// StatusText('Failed',   status: StatusType.error)
/// StatusText('Archived', status: StatusType.neutral)
class StatusText extends StatelessWidget {
  final String text;
  final StatusType status;
  final bool showDot;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusText(
    this.text, {
    super.key,
    required this.status,
    this.showDot = true,
    this.fontSize,
    this.padding,
  });

  const StatusText.warning(
    this.text, {
    super.key,
    this.showDot = true,
    this.fontSize,
    this.padding,
  }) : status = StatusType.warning;

  const StatusText.success(
    this.text, {
    super.key,
    this.showDot = true,
    this.fontSize,
    this.padding,
  }) : status = StatusType.success;

  const StatusText.error(
    this.text, {
    super.key,
    this.showDot = true,
    this.fontSize,
    this.padding,
  }) : status = StatusType.error;

  const StatusText.neutral(
    this.text, {
    super.key,
    this.showDot = true,
    this.fontSize,
    this.padding,
  }) : status = StatusType.neutral;

  const StatusText.info(
    this.text, {
    super.key,
    this.showDot = true,
    this.fontSize,
    this.padding,
  }) : status = StatusType.info;

  /// Helper factory to map any string status to StatusText
  factory StatusText.fromStatusString(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) {
      return const StatusText('UNKNOWN', status: StatusType.neutral);
    }
    final s = rawStatus.toUpperCase().replaceAll(' ', '_');
    switch (s) {
      case 'COMPLETED':
      case 'SUCCESS':
      case 'PAID':
      case 'ACTIVE':
      case 'LINKED':
        return StatusText(rawStatus, status: StatusType.success);
      case 'PENDING':
      case 'PENDING_APPROVAL':
      case 'AWAITING_APPROVAL':
      case 'PARTIALLY_COMPLETED':
      case 'PROCESSING':
      case 'IN_PROGRESS':
        return StatusText(rawStatus, status: StatusType.warning);
      case 'FAILED':
      case 'ERROR':
      case 'DECLINED':
      case 'REJECTED':
        return StatusText(rawStatus, status: StatusType.error);
      case 'DRAFT':
      case 'ARCHIVED':
      case 'NOT_STARTED':
      default:
        return StatusText(rawStatus, status: StatusType.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = status.color;
    final textStyle = TextStyle(
      color: statusColor,
      fontSize: fontSize ?? 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text.toUpperCase(),
            style: textStyle,
          ),
        ],
      ),
    );
  }
}

/// Official BMoni UI Kit SectionHeader component
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? subtitle;
  final EdgeInsetsGeometry padding;
  final bool showBottomDivider;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.showBottomDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FlowPayTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FlowPayColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (showBottomDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: FlowPayColors.hairline,
          ),
      ],
    );
  }
}

/// Official BMoni UI Kit ActivitySectionCard container component
/// A card-shaped container with a structured SectionHeader, a content area,
/// and an optional footer. Designed for activity feeds, dashboards, and audit logs.
class ActivitySectionCard extends StatelessWidget {
  final SectionHeader header;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;

  const ActivitySectionCard({
    super.key,
    required this.header,
    required this.child,
    this.footer,
    this.contentPadding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: FlowPayColors.darkSurface,
        borderRadius: FlowPayRadii.card,
        border: Border.all(color: FlowPayColors.hairline, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Padding(
            padding: contentPadding ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
          if (footer != null) ...[
            const Divider(height: 1, thickness: 1, color: FlowPayColors.hairline),
            footer!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: FlowPayRadii.card,
        child: card,
      );
    }

    return card;
  }
}



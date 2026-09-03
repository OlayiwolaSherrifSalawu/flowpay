import 'package:flutter/material.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FlowPay Card Primitive
/// Conforms to design.md §3.4 & §3.5: 20dp radius, hairline border, zero drop shadow.
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
      borderRadius: FlowPayRadii.card,
      border: border ?? Border.all(color: FlowPayColors.hairline, width: 1),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: FlowPayRadii.card,
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

/// FlowPay Button Primitive
/// Conforms to design.md §3.4: Universal pill radius (9999px) on all buttons.
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
    final bg = isSecondary ? FlowPayColors.surfaceAlt : FlowPayColors.ink;
    final fg = isSecondary ? FlowPayColors.textPrimary : Colors.white;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: FlowPayRadii.button,
          side: BorderSide.none,
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: FlowPayTypography.label(color: fg).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Status Badge Primitive
/// Conforms to design.md §3.1 & §3.4: Pill radius (9999px), semantic state tokens.
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
      case 'ONBOARDED':
      case 'PROVISIONED':
        bg = FlowPayColors.signal.withOpacity(0.12);
        fg = FlowPayColors.signal;
        break;
      case 'PENDING':
      case 'INVITED':
      case 'PROCESSING':
        bg = FlowPayColors.amber.withOpacity(0.16);
        fg = const Color(0xFFB45309);
        break;
      case 'FROZEN':
      case 'SUSPENDED':
      case 'FAILED':
        bg = FlowPayColors.stateError.withOpacity(0.12);
        fg = FlowPayColors.stateError;
        break;
      default:
        bg = FlowPayColors.surfaceAlt;
        fg = FlowPayColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: FlowPayRadii.chip,
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

/// Demo Mode Indicator Pill
/// Conforms to design.md §4.6: FlowPay Amber fill, 12dp caption, pill radius.
class DemoPill extends StatelessWidget {
  const DemoPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: FlowPayColors.amber,
        borderRadius: FlowPayRadii.chip,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 12, color: FlowPayColors.ink),
          SizedBox(width: 4),
          Text(
            'DEMO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FlowPayColors.ink,
              letterSpacing: 0.5,
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
    Key? key,
    required this.isPersonal,
    required this.onRoleChanged,
  }) : super(key: key);

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
/// and soft physical shadow (0x1A0D2E2A, blur 24, offset (0, 8)).
class VirtualCardObject extends StatelessWidget {
  final String cardLast4;
  final String countryFlag;
  final String cardHolderName;
  final bool isFrozen;

  const VirtualCardObject({
    Key? key,
    required this.cardLast4,
    required this.countryFlag,
    required this.cardHolderName,
    this.isFrozen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isFrozen ? FlowPayColors.surfaceAlt : FlowPayColors.amber,
          borderRadius: FlowPayRadii.card,
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A0D2E2A),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FlowPay',
                  style: FlowPayTypography.title(color: FlowPayColors.ink).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(countryFlag, style: const TextStyle(fontSize: 22)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•••• •••• •••• $cardLast4',
                  style: FlowPayTypography.amount(color: FlowPayColors.ink).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cardHolderName.toUpperCase(),
                      style: FlowPayTypography.captionStyle(color: FlowPayColors.ink).copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEB001B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF79E1B).withOpacity(0.9),
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
    );
  }
}

/// Empty State Primitive
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
              decoration: const BoxDecoration(
                color: FlowPayColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: FlowPayColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: FlowPayTypography.title(color: FlowPayColors.textPrimary),
            ),
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

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
/// and soft physical shadow (0x1A0D2E2A, blur 24, offset (0, 8)).
class VirtualCardObject extends StatelessWidget {
  final String cardLast4;
  final String countryFlag;
  final String cardHolderName;
  final bool isFrozen;

  const VirtualCardObject({
    super.key,
    required this.cardLast4,
    required this.countryFlag,
    required this.cardHolderName,
    this.isFrozen = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isFrozen ? FlowPayColors.surfaceAlt : FlowPayColors.amber,
          borderRadius: FlowPayRadii.card,
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
                              color: const Color(0xFFF79E1B).withAlpha(230),
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

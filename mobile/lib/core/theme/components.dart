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


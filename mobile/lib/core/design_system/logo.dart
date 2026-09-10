import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

/// FlowPay Brand Logo Component
/// Renders the official FlowPay flowing 'F' ribbon brand mark with optional wordmark.
class FlowPayLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final double wordmarkSize;
  final Color? wordmarkColor;
  final VoidCallback? onTap;

  const FlowPayLogo({
    super.key,
    this.size = 36,
    this.showWordmark = false,
    this.wordmarkSize = 20,
    this.wordmarkColor,
    this.onTap,
  });

  /// Compact header badge icon
  const FlowPayLogo.compact({
    super.key,
    this.size = 28,
    this.showWordmark = false,
    this.wordmarkSize = 16,
    this.wordmarkColor,
    this.onTap,
  });

  /// Full brand lockup with wordmark
  const FlowPayLogo.horizontal({
    super.key,
    this.size = 32,
    this.showWordmark = true,
    this.wordmarkSize = 19,
    this.wordmarkColor,
    this.onTap,
  });

  String _resolveAssetPath() {
    if (size <= 64) {
      return 'assets/images/flowpay_logo_64.png';
    } else if (size <= 128) {
      return 'assets/images/flowpay_logo_128.png';
    } else if (size <= 256) {
      return 'assets/images/flowpay_logo_256.png';
    } else {
      return 'assets/images/flowpay_logo_512.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _resolveAssetPath();
    final effectiveWordmarkColor = wordmarkColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? FlowPayColors.darkTextPrimary
            : FlowPayColors.lightTextPrimary);

    Widget mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback if image asset is unavailable in test environment
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FlowPayColors.emerald700, FlowPayColors.emerald600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.24),
            ),
            child: Center(
              child: Text(
                'F',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.58,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
          );
        },
      ),
    );

    Widget content;
    if (showWordmark) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          SizedBox(width: size * 0.28),
          RichText(
            text: TextSpan(
              text: 'Flow',
              style: GoogleFonts.inter(
                fontSize: wordmarkSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: effectiveWordmarkColor,
              ),
              children: [
                TextSpan(
                  text: 'Pay',
                  style: GoogleFonts.inter(
                    fontSize: wordmarkSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: FlowPayColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = mark;
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.24),
        child: content,
      );
    }

    return content;
  }
}

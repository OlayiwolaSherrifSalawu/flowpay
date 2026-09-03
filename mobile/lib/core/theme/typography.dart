import 'package:flutter/material.dart';
import 'colors.dart';

class FlowPayTypography {
  static const headingLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: FlowPayColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const headingMd = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: FlowPayColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const headingSm = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: FlowPayColors.textPrimary,
  );

  static const bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: FlowPayColors.textPrimary,
    height: 1.5,
  );

  static const bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: FlowPayColors.textSecondary,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: FlowPayColors.textTertiary,
  );

  // Dedicated Financial Numbers (monospaced digits for perfect alignment)
  static const financialLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: FlowPayColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.5,
  );

  static const financialMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: FlowPayColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const financialSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: FlowPayColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

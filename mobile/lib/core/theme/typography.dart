import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// FlowPay Typography Hierarchy
/// Features monospaced tabular figures for all financial amounts to eliminate numerical drift.
class FlowPayTypography {
  static const TextStyle headlineLarge = headingLg;
  static const TextStyle headlineMedium = headingMd;
  static const TextStyle headlineSmall = headingSm;
  static const TextStyle titleMedium = headingSm;
  static const TextStyle bodyMedium = bodyMd;
  static const TextStyle bodySmall = bodySm;

  /// Display / balance — 40dp, weight 600, letterSpacing -0.8, height 1.05
  static TextStyle display({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.05,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Headline — 24dp, weight 600, letterSpacing -0.24, height 1.15
  static TextStyle headline({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.24,
        height: 1.15,
        color: color,
      );

  /// Title — 18dp, weight 600, letterSpacing 0, height 1.25
  static TextStyle title({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  /// Body — 16dp, weight 400, letterSpacing 0, height 1.45
  static TextStyle body({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
        color: color,
      );

  /// Body-emphasized — 16dp, weight 500, letterSpacing 0, height 1.45
  static TextStyle bodyEmphasized({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.45,
        color: color,
      );

  /// Amount (row) — 16dp, weight 500, letterSpacing 0, height 1.25
  static TextStyle amount({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.25,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Label — 14dp, weight 500, letterSpacing 0.28, height 1.3
  static TextStyle label({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.28,
        height: 1.3,
        color: color,
      );

  /// Caption — 12dp, weight 400, letterSpacing 0.36, height 1.3
  static TextStyle captionStyle({Color color = FlowPayColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.36,
        height: 1.3,
        color: color,
      );

  // ─── Static Getters for Design System Components ───────────
  static const TextStyle headingLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headingMd = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headingSm = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static const TextStyle financialLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle financialMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle financialSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle financialMicro = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Helpers with context brightness
  static TextStyle headingLgOf(BuildContext context) =>
      headingLg.copyWith(color: FlowPayColors.textPrimaryOf(context));

  static TextStyle headingMdOf(BuildContext context) =>
      headingMd.copyWith(color: FlowPayColors.textPrimaryOf(context));

  static TextStyle headingSmOf(BuildContext context) =>
      headingSm.copyWith(color: FlowPayColors.textPrimaryOf(context));

  static TextStyle bodyLgOf(BuildContext context) =>
      bodyLg.copyWith(color: FlowPayColors.textPrimaryOf(context));

  static TextStyle bodyMdOf(BuildContext context) =>
      bodyMd.copyWith(color: FlowPayColors.textSecondaryOf(context));

  static TextStyle captionOf(BuildContext context) =>
      caption.copyWith(color: FlowPayColors.textSecondaryOf(context));
}

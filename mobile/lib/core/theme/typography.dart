import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// FlowPay Typography Hierarchy
/// Derived strictly from .agents/skills/flowpay-core/design.md §3.2
/// Every style uses Inter with tabular figures enabled for monetary values.
class FlowPayTypography {
  /// Display / balance — 40dp, weight 600, letterSpacing -0.8, height 1.05
  /// For big balance numbers on wallet home. Tabular figures enabled.
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
  /// Screen titles, primary section headers.
  static TextStyle headline({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.24,
        height: 1.15,
        color: color,
      );

  /// Title — 18dp, weight 600, letterSpacing 0, height 1.25
  /// Card headers, prominent row labels.
  static TextStyle title({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  /// Body — 16dp, weight 400, letterSpacing 0, height 1.45
  /// Default paragraph text.
  static TextStyle body({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.45,
        color: color,
      );

  /// Body-emphasized — 16dp, weight 500, letterSpacing 0, height 1.45
  /// Highlighted body words.
  static TextStyle bodyEmphasized({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.45,
        color: color,
      );

  /// Amount (row) — 16dp, weight 500, letterSpacing 0, height 1.25
  /// Transaction row amounts with tabular figures.
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
  /// Field labels, chip labels, segment tabs.
  static TextStyle label({Color color = FlowPayColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.28,
        height: 1.3,
        color: color,
      );

  /// Caption — 12dp, weight 400, letterSpacing 0.36, height 1.3
  /// Timestamps, helper text, metadata.
  static TextStyle captionStyle({Color color = FlowPayColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.36,
        height: 1.3,
        color: color,
      );

  // ─── Backward Compatibility Static Getters ──────────────────
  static TextStyle get headingLg => headline();
  static TextStyle get headingMd => title();
  static TextStyle get headingSm => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: FlowPayColors.textPrimary,
      );
  static TextStyle get bodyLg => body();
  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: FlowPayColors.textSecondary,
        height: 1.4,
      );
  static TextStyle get caption => captionStyle();

  static TextStyle get financialLarge => display(color: FlowPayColors.textPrimary);
  static TextStyle get financialMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: FlowPayColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  static TextStyle get financialSmall => amount();
}

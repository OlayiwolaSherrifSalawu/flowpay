import 'package:flutter/material.dart';

/// FlowPay Design Tokens — Palette
/// Derived strictly from .agents/skills/flowpay-core/design.md §3.1
class FlowPayColors {
  // ─── FlowPay Core Brand Accents ───────────────────────────
  /// Primary accent — "FlowPay Ink" — #0D2E2A
  /// Used for: primary CTA fills (dark pill on light canvas), body text, dark sections.
  static const ink = Color(0xFF0D2E2A);

  /// Secondary accent — "Signal" — #00C48A
  /// Saturated calm green. Used for: success/credited states, positive deltas,
  /// money moving lines. NEVER on a button as a default state.
  static const signal = Color(0xFF00C48A);

  /// Object color — "FlowPay Amber" — #F4B740
  /// Warm amber. Used for: the virtual card face, the demo-mode pill,
  /// and pending/processing states.
  static const amber = Color(0xFFF4B740);

  // ─── Neutrals ─────────────────────────────────────────────
  /// App background (never pure #FFFFFF on large surfaces)
  static const canvas = Color(0xFFFAFAF7);

  /// Cards, sheets, elevated surfaces
  static const surface = Color(0xFFFFFFFF);

  /// Alternate/tinted background bands, disabled fills
  static const surfaceAlt = Color(0xFFF2F1EC);

  /// 1px borders and dividers
  static const hairline = Color(0xFFE6E4DE);

  /// Body text (same value as primary accent, intentional)
  static const textPrimary = Color(0xFF0D2E2A);

  /// Metadata, timestamps, secondary labels
  static const textSecondary = Color(0xFF5C6461);

  /// Disabled text, low-priority captions
  static const textTertiary = Color(0xFF8A918E);

  // ─── Semantic (State only, never brand) ────────────────────
  static const stateSuccess = Color(0xFF00C48A);
  static const statePending = Color(0xFFF4B740);
  static const stateError = Color(0xFFE5484D);
  static const stateInfo = Color(0xFF3E5CFB);

  // ─── Currency Badge Colors (Light Canvas Harmonized) ───────
  static const usdBadge = Color(0xFFE8ECEB);
  static const ngnBadge = Color(0xFFE0F5EE);
  static const mxnBadge = Color(0xFFF7EBF7);
  static const cadBadge = Color(0xFFFEECEB);

  // ─── Backward Compatibility Aliases ────────────────────────
  static const background = canvas;
  static const surfaceElevated = surface;
  static const surfaceSubtle = surfaceAlt;
  static const border = hairline;
  static const borderLight = hairline;
  static const primary = ink;
  static const primaryLight = Color(0xFF1B4D47);
  static const primaryDark = Color(0xFF071917);
  static const accent = signal;
  static const accentLight = Color(0xFF33D1A1);
  static const warning = amber;
  static const error = stateError;
  static const textMuted = textTertiary;
}

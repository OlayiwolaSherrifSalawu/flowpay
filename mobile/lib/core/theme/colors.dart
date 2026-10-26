import 'package:flutter/material.dart';

/// FlowPay Design System Colors — Stellar-inspired.
///
/// Built on the Stellar network, FlowPay borrows Stellar's design language:
/// off-black and paper neutrals, a single warm gold for primary actions, a deep
/// teal for interactive text/icons (readable on paper and on black), and thin
/// hairline borders. Brand identity (logo, name) remains FlowPay's own.
class FlowPayColors {
  // ─── FlowPay Brand Core ("Current" - flowing F mark · emerald) ─────────────
  /// Deep grounding emerald for borders, card gradients, and active dark surfaces
  static const Color emerald700 = Color(0xFF005F67); // deep teal

  /// Primary brand emerald (#128A63) — confident, liquid, trustworthy
  static const Color emerald600 = Color(0xFF00818B); // teal accent (4.5:1 on paper)
  static const Color primary = emerald600;
  static const Color brand = primary;
  static const Color brand500 = primary;

  /// Vibrant minty emerald highlight (#3FAE85) — chart peaks, pills, active highlights
  static const Color emerald400 = Color(0xFF00A7B5); // Stellar teal
  static const Color primaryLight = emerald400;
  static const Color brand400 = emerald400;
  static const Color primaryDark = emerald700;

  /// Soft mint tint (#D8F0E4) — card surfaces, squircle icon backgrounds
  static const Color mint100 = Color(0xFFFFF6CC); // soft gold tint
  static const Color mintSurface = mint100;
  static const Color mint200 = Color(0xFFFEEB8A);

  /// Deep Ink (#0F1712) — primary text on light mode, hero dark card base
  static const Color ink = Color(0xFF0F0F0F);

  /// Tactile Paper (#FAF9F6) — primary light mode canvas background
  static const Color paper = Color(0xFFF9F9F9);

  /// Primary action fill (pair with [onGold] text).
  static const Color gold = Color(0xFFFDDA24);
  static const Color onGold = Color(0xFF0F0F0F);

  /// Warm sand for quiet sections.
  static const Color sand = Color(0xFFD6D3C4);

  // ─── Secondary Accents ──────────────────────────────────────────────────
  static const Color accent = emerald600;
  static const Color accentLight = emerald400;
  static const Color accentDark = emerald700;

  // ─── Transaction States (Approved Palette) ───────────────────────────────
  /// Success (#12A150) — received funds, verified KYC, completed disbursements
  static const Color stateSuccess = Color(0xFF12A150);
  static const Color success = stateSuccess;
  static const Color successSubtle = Color(0x1F12A150);

  /// Pending (#D8A400) — in-flight transfers, pending approvals, settlement
  static const Color statePending = Color(0xFFD8A400);
  static const Color pending = statePending;
  static const Color warning = statePending;
  static const Color signalCaution = warning;
  static const Color warningLight = Color(0xFFEAB308);
  static const Color warningSubtle = Color(0x1FD8A400);
  static const Color amber = statePending;

  /// Error (#D14343) — execution failure, insufficient balance, network error
  static const Color stateError = Color(0xFFD14343);
  static const Color error = stateError;
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorSubtle = Color(0x1FD14343);

  /// Info / Link (#2E6FF2) — explorer links, documentation, web previews
  static const Color stateInfo = Color(0xFF2E6FF2);
  static const Color info = stateInfo;
  static const Color infoLight = Color(0xFF60A5FA);

  /// AI / Missions Violet
  static const Color purple = Color(0xFFB7ACE8); // Stellar lilac

  // ─── Upstream Fintech Design Aliases ────────────────────────────────────
  static const Color signal = emerald600;
  static const Color canvas = paper;
  static const Color surfaceAlt = Color(0xFFF2F2F2);
  static const Color hairline = Color(0xFFE6E6E6);

  // ─── Light Theme Palette (Paper & Ceramic System) ────────────────────────
  static const Color lightBackground = paper; // #FAF9F6
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF2F2F2);
  static const Color lightSurfaceSubtle = Color(0xFFEBEBEB);
  static const Color lightBorder = Color(0xFFE6E6E6);
  static const Color lightBorderLight = Color(0xFFD1D1D1);

  static const Color lightTextPrimary = ink; // #0F1712
  static const Color lightTextSecondary = Color(0xFF444444);
  static const Color lightTextTertiary = Color(0xFF6B6B6B);
  static const Color lightTextMuted = Color(0xFF969696);

  // ─── Dark Theme Palette (Obsidian-Emerald System from Palette HTML) ───────
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF191919);
  static const Color darkSurfaceElevated = Color(0xFF262626);
  static const Color darkSurfaceSubtle = Color(0xFF2E2E2E);
  static const Color darkBorder = Color(0xFF2B2B2B);
  static const Color darkBorderLight = Color(0xFF3A3A3A);

  static const Color darkTextPrimary = Color(0xFFF9F9F9);
  static const Color darkTextSecondary = Color(0xFFBFBFBF);
  static const Color darkTextTertiary = Color(0xFF969696);
  static const Color darkTextMuted = Color(0xFF6B6B6B);
  static const Color darkAccent = Color(0xFFFDDA24); // gold on black

  // ─── Default backward-compatible aliases ────────────────────────────────
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceElevated = darkSurfaceElevated;
  static const Color surfaceSubtle = darkSurfaceSubtle;
  static const Color border = darkBorder;
  static const Color borderLight = darkBorderLight;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkTextTertiary;
  static const Color textMuted = darkTextMuted;

  // ─── Currency Badge Colors ──────────────────────────────────────────────
  static const Color usdBadge = Color(0xFF1E293B);
  static const Color ngnBadge = Color(0xFF005F67);
  static const Color mxnBadge = Color(0xFF78350F);
  static const Color eurBadge = Color(0xFF1E1B4B);
  static const Color gbpBadge = Color(0xFF312E81);
  static const Color cadBadge = Color(0xFF7F1D1D);

  // ─── Context-aware color resolution ─────────────────────────────────────
  /// Selection / emphasis accent: gold on dark surfaces, ink on light ones.
  static Color selectedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gold : ink;

  /// Readable text on top of [selectedOf].
  static Color onSelectedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? onGold : Colors.white;

  /// Interactive accent text (links, taglines): teal on light, gold on dark.
  static Color accentTextOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gold : primary;

  static Color surfaceOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color surfaceElevatedOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurfaceElevated
        : lightSurfaceElevated;
  }

  static Color backgroundOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color borderOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  static Color textPrimaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
}

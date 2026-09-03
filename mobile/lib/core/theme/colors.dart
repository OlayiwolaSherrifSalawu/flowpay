import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';

/// FlowPay Design System Colors
/// Integrates the official BMoni UI Kit (`bkey_uikit`) color system
/// providing high-contrast, accessible palettes for both Dark and Light themes.
class FlowPayColors {
  // Brand Accents (Official BMoni Brand Magenta & Accents)
  static const Color primary = BMoniColors.brand500;       // BMoni Brand Magenta (#B001B0)
  static const Color primaryLight = BMoniColors.brand400;  // Vibrant Highlight (#C94CD7)
  static const Color primaryDark = BMoniColors.brand700;   // Deep Brand (#690669)

  static const Color accent = BMoniColors.accent400;       // Electric Accent Blue (#2B88D1)
  static const Color accentLight = BMoniColors.accent300;
  static const Color accentDark = BMoniColors.accent600;

  static const Color warning = BMoniColors.warning400;     // Amber
  static const Color warningLight = BMoniColors.warning300;

  static const Color error = BMoniColors.error400;         // Coral Red
  static const Color errorLight = BMoniColors.error300;

  static const Color info = BMoniColors.accent400;         // Info Ocean Blue
  static const Color infoLight = BMoniColors.accent300;

  static const Color purple = BMoniColors.brand400;        // AI / Missions Violet

  // Upstream Fintech Design Aliases
  static const Color ink = Color(0xFF0D2E2A);
  static const Color signal = BMoniColors.accent400;
  static const Color amber = BMoniColors.warning400;
  static const Color canvas = BMoniColors.offbrand950;
  static const Color surfaceAlt = BMoniColors.offbrand800;
  static const Color hairline = BMoniColors.offbrand700;

  static const Color stateSuccess = BMoniColors.success400;
  static const Color statePending = BMoniColors.warning400;
  static const Color stateError = BMoniColors.error400;
  static const Color stateInfo = BMoniColors.accent400;

  // Dark Theme Palette (BMoni Obsidian/Plum Dark System)
  static const Color darkBackground = BMoniColors.offbrand950;      // #1C0C1C
  static const Color darkSurface = BMoniColors.offbrand900;         // #240D24
  static const Color darkSurfaceElevated = BMoniColors.offbrand800; // #351835
  static const Color darkSurfaceSubtle = BMoniColors.offbrand700;   // #4C274C
  static const Color darkBorder = BMoniColors.offbrand700;          // #4C274C
  static const Color darkBorderLight = BMoniColors.offbrand600;     // #693C69

  static const Color darkTextPrimary = BMoniColors.grey50;          // #F9F9FA
  static const Color darkTextSecondary = BMoniColors.grey400;       // #9E9EA4
  static const Color darkTextTertiary = BMoniColors.grey600;        // #5E5E66
  static const Color darkTextMuted = BMoniColors.grey700;           // #45454C

  // Light Theme Palette
  static const Color lightBackground = BMoniColors.offbrand25;
  static const Color lightSurface = BMoniColors.offbrand50;
  static const Color lightSurfaceElevated = BMoniColors.offbrand100;
  static const Color lightSurfaceSubtle = BMoniColors.offbrand200;
  static const Color lightBorder = BMoniColors.offbrand200;
  static const Color lightBorderLight = BMoniColors.offbrand300;

  static const Color lightTextPrimary = BMoniColors.grey950;
  static const Color lightTextSecondary = BMoniColors.grey700;
  static const Color lightTextTertiary = BMoniColors.grey600;
  static const Color lightTextMuted = BMoniColors.grey400;

  // Default backward-compatible aliases (defaults to Dark Mode aesthetic)
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

  // Currency Badge Colors
  static const Color usdBadge = Color(0xFF1E293B);
  static const Color ngnBadge = Color(0xFF064E3B);
  static const Color mxnBadge = Color(0xFF701A75);
  static const Color eurBadge = Color(0xFF1E3A8A);
  static const Color gbpBadge = Color(0xFF312E81);
  static const Color cadBadge = Color(0xFF831843);

  // Context-aware color resolution
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

import 'package:flutter/material.dart';

/// FlowPay Design System Colors
/// Independent, premium fintech palette featuring obsidian slate surfaces,
/// FlowPay Electric Emerald brand accents, and high-contrast accessible typography.
class FlowPayColors {
  // Brand Accents — FlowPay Electric Emerald (#00E599) & Accents
  static const Color primary = Color(0xFF00E599);
  static const Color brand = primary;
  static const Color brand500 = primary;
  static const Color brand400 = Color(0xFF33EAB0);
  static const Color primaryLight = Color(0xFF33EAB0);
  static const Color primaryDark = Color(0xFF00B377);

  // Secondary Accents — Hyper Iris & Slate
  static const Color accent = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentDark = Color(0xFF4F46E5);

  // Semantic Colors
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color signalCaution = warning;
  static const Color warningLight = Color(0xFFFBBF24);

  static const Color error = Color(0xFFEF4444); // Crimson
  static const Color errorLight = Color(0xFFF87171);

  static const Color info = Color(0xFF38BDF8); // Ocean Cyan
  static const Color infoLight = Color(0xFF7DD3FC);

  static const Color purple = Color(0xFF8B5CF6); // AI / Missions Violet

  // Upstream Fintech Design Aliases
  static const Color ink = Color(0xFFF8FAFC); // Crisp high-contrast readable white
  static const Color signal = Color(0xFF00E599); // Electric Emerald execution indicator
  static const Color amber = Color(0xFFF59E0B);
  static const Color canvas = Color(0xFF090A0F);
  static const Color surfaceAlt = Color(0xFF181B26);
  static const Color hairline = Color(0xFF282D3D);

  static const Color stateSuccess = Color(0xFF00E599);
  static const Color success = stateSuccess;
  static const Color statePending = Color(0xFFF59E0B);
  static const Color stateError = Color(0xFFEF4444);
  static const Color stateInfo = Color(0xFF38BDF8);

  // Dark Theme Palette (Obsidian Slate System)
  static const Color darkBackground = Color(0xFF090A0F);
  static const Color darkSurface = Color(0xFF12141C);
  static const Color darkSurfaceElevated = Color(0xFF181B26);
  static const Color darkSurfaceSubtle = Color(0xFF1F2330);
  static const Color darkBorder = Color(0xFF282D3D);
  static const Color darkBorderLight = Color(0xFF383F54);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkTextMuted = Color(0xFF475569);

  // Light Theme Palette (Crisp Ceramic System)
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F3F5);
  static const Color lightSurfaceSubtle = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderLight = Color(0xFFCBD5E1);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

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
  static const Color mxnBadge = Color(0xFF451A03);
  static const Color eurBadge = Color(0xFF1E1B4B);
  static const Color gbpBadge = Color(0xFF312E81);
  static const Color cadBadge = Color(0xFF450A0A);

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

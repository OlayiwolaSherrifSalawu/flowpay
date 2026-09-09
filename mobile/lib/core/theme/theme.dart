import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FlowPay Theme Configuration
/// Source of Truth: Approved FlowPay "Current" Palette & Dribbble Smart Fintech Reference
/// Delivering an ultra-polished, trustworthy, and intelligent fintech atmosphere
/// in both Paper Light Mode and Obsidian-Emerald Dark Mode.
class FlowPayTheme {
  // ─── Dark Theme Definition (Obsidian-Emerald) ─────────────────────────────
  static ThemeData dark() {
    final baseTextTheme =
        GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FlowPayColors.darkBackground,
      primaryColor: FlowPayColors.primary,
      textTheme: baseTextTheme.copyWith(
        displayLarge: FlowPayTypography.headingLg
            .copyWith(color: FlowPayColors.darkTextPrimary),
        displayMedium: FlowPayTypography.headingMd
            .copyWith(color: FlowPayColors.darkTextPrimary),
        displaySmall: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.darkTextPrimary),
        headlineMedium: FlowPayTypography.headingMd
            .copyWith(color: FlowPayColors.darkTextPrimary),
        headlineSmall: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.darkTextPrimary),
        titleLarge: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.darkTextPrimary),
        titleMedium: FlowPayTypography.bodyLg.copyWith(
            color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: FlowPayTypography.bodyMd.copyWith(
            color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: FlowPayTypography.bodyLg
            .copyWith(color: FlowPayColors.darkTextPrimary),
        bodyMedium: FlowPayTypography.bodyMd
            .copyWith(color: FlowPayColors.darkTextSecondary),
        bodySmall: FlowPayTypography.bodySm
            .copyWith(color: FlowPayColors.darkTextSecondary),
        labelLarge: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        labelMedium: FlowPayTypography.caption
            .copyWith(color: FlowPayColors.darkTextSecondary),
        labelSmall: FlowPayTypography.overline
            .copyWith(color: FlowPayColors.darkTextMuted),
      ),
      colorScheme: const ColorScheme.dark(
        primary: FlowPayColors.primary,
        onPrimary: Color(0xFF0C1210),
        secondary: FlowPayColors.darkAccent,
        onSecondary: Color(0xFF0C1210),
        surface: FlowPayColors.darkSurface,
        onSurface: FlowPayColors.darkTextPrimary,
        error: FlowPayColors.error,
        onError: Colors.white,
        outline: FlowPayColors.darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FlowPayColors.darkBackground,
        foregroundColor: FlowPayColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: FlowPayTypography.headingSm,
      ),
      cardTheme: const CardThemeData(
        color: FlowPayColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.card,
          side: BorderSide(color: FlowPayColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        modalBackgroundColor: FlowPayColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.sheet,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.cardLarge,
          side: BorderSide(color: FlowPayColors.darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FlowPayColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowPayColors.darkSurface,
        indicatorColor: FlowPayColors.emerald700.withAlpha(80),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlowPayColors.darkAccent,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: FlowPayColors.darkTextSecondary,
          );
        }),
      ),
    );
  }

  // ─── Light Theme Definition (Paper Canvas & Crisp Typography) ──────────────
  static ThemeData light() {
    final baseTextTheme =
        GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FlowPayColors.lightBackground, // #FAF9F6 Paper
      primaryColor: FlowPayColors.primary, // #128A63 Emerald 600
      textTheme: baseTextTheme.copyWith(
        displayLarge: FlowPayTypography.headingLg
            .copyWith(color: FlowPayColors.lightTextPrimary),
        displayMedium: FlowPayTypography.headingMd
            .copyWith(color: FlowPayColors.lightTextPrimary),
        displaySmall: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.lightTextPrimary),
        headlineMedium: FlowPayTypography.headingMd
            .copyWith(color: FlowPayColors.lightTextPrimary),
        headlineSmall: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.lightTextPrimary),
        titleLarge: FlowPayTypography.headingSm
            .copyWith(color: FlowPayColors.lightTextPrimary),
        titleMedium: FlowPayTypography.bodyLg.copyWith(
            color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: FlowPayTypography.bodyMd.copyWith(
            color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: FlowPayTypography.bodyLg
            .copyWith(color: FlowPayColors.lightTextPrimary),
        bodyMedium: FlowPayTypography.bodyMd
            .copyWith(color: FlowPayColors.lightTextSecondary),
        bodySmall: FlowPayTypography.bodySm
            .copyWith(color: FlowPayColors.lightTextSecondary),
        labelLarge: FlowPayTypography.caption.copyWith(
            color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        labelMedium: FlowPayTypography.caption
            .copyWith(color: FlowPayColors.lightTextSecondary),
        labelSmall: FlowPayTypography.overline
            .copyWith(color: FlowPayColors.lightTextMuted),
      ),
      colorScheme: const ColorScheme.light(
        primary: FlowPayColors.primary, // #128A63
        onPrimary: Colors.white,
        secondary: FlowPayColors.emerald400,
        onSecondary: FlowPayColors.ink,
        surface: FlowPayColors.lightSurface,
        onSurface: FlowPayColors.lightTextPrimary,
        error: FlowPayColors.error,
        onError: Colors.white,
        outline: FlowPayColors.lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FlowPayColors.lightBackground,
        foregroundColor: FlowPayColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FlowPayColors.lightTextPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: FlowPayColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.card,
          side: BorderSide(color: FlowPayColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        modalBackgroundColor: FlowPayColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.sheet,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPayRadii.cardLarge,
          side: BorderSide(color: FlowPayColors.lightBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FlowPayColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        indicatorColor: FlowPayColors.mint100,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlowPayColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: FlowPayColors.lightTextSecondary,
          );
        }),
      ),
    );
  }
}

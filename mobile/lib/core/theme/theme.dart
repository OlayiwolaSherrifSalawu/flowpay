import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// FlowPay Theme Configuration
/// Independent, premium fintech design system and typography delivering
/// an ultra-polished, Linear-level aesthetic in both Dark and Light modes.
class FlowPayTheme {
  // Dark Theme Definition
  static ThemeData dark() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FlowPayColors.darkBackground,
      primaryColor: FlowPayColors.primary,
      textTheme: baseTextTheme.copyWith(
        displayLarge: FlowPayTypography.headingLg.copyWith(color: FlowPayColors.darkTextPrimary),
        displayMedium: FlowPayTypography.headingMd.copyWith(color: FlowPayColors.darkTextPrimary),
        displaySmall: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.darkTextPrimary),
        headlineMedium: FlowPayTypography.headingMd.copyWith(color: FlowPayColors.darkTextPrimary),
        headlineSmall: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.darkTextPrimary),
        titleLarge: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.darkTextPrimary),
        titleMedium: FlowPayTypography.bodyLg.copyWith(color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: FlowPayTypography.bodyMd.copyWith(color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: FlowPayTypography.bodyLg.copyWith(color: FlowPayColors.darkTextPrimary),
        bodyMedium: FlowPayTypography.bodyMd.copyWith(color: FlowPayColors.darkTextSecondary),
        bodySmall: FlowPayTypography.bodySm.copyWith(color: FlowPayColors.darkTextSecondary),
        labelLarge: FlowPayTypography.caption.copyWith(color: FlowPayColors.darkTextPrimary, fontWeight: FontWeight.w600),
        labelMedium: FlowPayTypography.caption.copyWith(color: FlowPayColors.darkTextSecondary),
        labelSmall: FlowPayTypography.overline.copyWith(color: FlowPayColors.darkTextMuted),
      ),
      colorScheme: const ColorScheme.dark(
        primary: FlowPayColors.primary,
        onPrimary: Color(0xFF090A0F),
        secondary: FlowPayColors.accent,
        onSecondary: Colors.white,
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
      cardTheme: CardThemeData(
        color: FlowPayColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPaySpacing.borderRadiusLg,
          side: const BorderSide(color: FlowPayColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        modalBackgroundColor: FlowPayColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(FlowPaySpacing.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FlowPayColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPaySpacing.borderRadiusXl,
          side: const BorderSide(color: FlowPayColors.darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FlowPayColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowPayColors.darkSurface,
        indicatorColor: FlowPayColors.primary.withAlpha(40),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlowPayColors.primaryLight,
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

  // Light Theme Definition
  static ThemeData light() {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FlowPayColors.lightBackground,
      primaryColor: FlowPayColors.primaryDark,
      textTheme: baseTextTheme.copyWith(
        displayLarge: FlowPayTypography.headingLg.copyWith(color: FlowPayColors.lightTextPrimary),
        displayMedium: FlowPayTypography.headingMd.copyWith(color: FlowPayColors.lightTextPrimary),
        displaySmall: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.lightTextPrimary),
        headlineMedium: FlowPayTypography.headingMd.copyWith(color: FlowPayColors.lightTextPrimary),
        headlineSmall: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.lightTextPrimary),
        titleLarge: FlowPayTypography.headingSm.copyWith(color: FlowPayColors.lightTextPrimary),
        titleMedium: FlowPayTypography.bodyLg.copyWith(color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: FlowPayTypography.bodyMd.copyWith(color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        bodyLarge: FlowPayTypography.bodyLg.copyWith(color: FlowPayColors.lightTextPrimary),
        bodyMedium: FlowPayTypography.bodyMd.copyWith(color: FlowPayColors.lightTextSecondary),
        bodySmall: FlowPayTypography.bodySm.copyWith(color: FlowPayColors.lightTextSecondary),
        labelLarge: FlowPayTypography.caption.copyWith(color: FlowPayColors.lightTextPrimary, fontWeight: FontWeight.w600),
        labelMedium: FlowPayTypography.caption.copyWith(color: FlowPayColors.lightTextSecondary),
        labelSmall: FlowPayTypography.overline.copyWith(color: FlowPayColors.lightTextMuted),
      ),
      colorScheme: const ColorScheme.light(
        primary: FlowPayColors.primaryDark,
        onPrimary: Colors.white,
        secondary: FlowPayColors.accent,
        onSecondary: Colors.white,
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
      cardTheme: CardThemeData(
        color: FlowPayColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPaySpacing.borderRadiusLg,
          side: const BorderSide(color: FlowPayColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        modalBackgroundColor: FlowPayColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(FlowPaySpacing.radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: FlowPaySpacing.borderRadiusXl,
          side: const BorderSide(color: FlowPayColors.lightBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FlowPayColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FlowPayColors.lightSurface,
        indicatorColor: FlowPayColors.primary.withAlpha(35),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlowPayColors.primaryDark,
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

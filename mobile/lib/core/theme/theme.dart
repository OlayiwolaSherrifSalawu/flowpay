import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// FlowPay Theme Configuration
/// Integrates the BMoni UI Kit (`bkey_uikit`) design system and typography,
/// delivering a high-polish, premium fintech aesthetic in both Dark and Light modes.
class FlowPayTheme {
  // Dark Theme Definition
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FlowPayColors.darkBackground,
      primaryColor: FlowPayColors.primary,
      textTheme: BMoniTheme.textTheme,
      colorScheme: const ColorScheme.dark(
        primary: FlowPayColors.primary,
        onPrimary: Colors.white,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(FlowPaySpacing.radiusXl)),
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
        indicatorColor: FlowPayColors.primary.withAlpha(50),
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FlowPayColors.lightBackground,
      primaryColor: FlowPayColors.primary,
      colorScheme: const ColorScheme.light(
        primary: FlowPayColors.primary,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(FlowPaySpacing.radiusXl)),
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

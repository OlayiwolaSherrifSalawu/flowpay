import 'package:flutter/material.dart';
import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// FlowPay Theme & Design Tokens Extension
/// Derived strictly from .agents/skills/flowpay-core/design.md
class FlowPayTokens extends ThemeExtension<FlowPayTokens> {
  final Color ink;
  final Color signal;
  final Color amber;
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  const FlowPayTokens({
    required this.ink,
    required this.signal,
    required this.amber,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  static const light = FlowPayTokens(
    ink: FlowPayColors.ink,
    signal: FlowPayColors.signal,
    amber: FlowPayColors.amber,
    canvas: FlowPayColors.canvas,
    surface: FlowPayColors.surface,
    surfaceAlt: FlowPayColors.surfaceAlt,
    hairline: FlowPayColors.hairline,
    textPrimary: FlowPayColors.textPrimary,
    textSecondary: FlowPayColors.textSecondary,
    textTertiary: FlowPayColors.textTertiary,
  );

  @override
  FlowPayTokens copyWith({
    Color? ink,
    Color? signal,
    Color? amber,
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return FlowPayTokens(
      ink: ink ?? this.ink,
      signal: signal ?? this.signal,
      amber: amber ?? this.amber,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  ThemeExtension<FlowPayTokens> lerp(
      ThemeExtension<FlowPayTokens>? other, double t) {
    if (other is! FlowPayTokens) return this;
    return FlowPayTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

class FlowPayTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FlowPayColors.canvas,
      cardColor: FlowPayColors.surface,
      dividerColor: FlowPayColors.hairline,
      primaryColor: FlowPayColors.ink,
      colorScheme: const ColorScheme.light(
        primary: FlowPayColors.ink,
        onPrimary: Colors.white,
        secondary: FlowPayColors.signal,
        onSecondary: Colors.white,
        surface: FlowPayColors.surface,
        onSurface: FlowPayColors.textPrimary,
        error: FlowPayColors.stateError,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FlowPayColors.canvas,
        foregroundColor: FlowPayColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle:
            FlowPayTypography.title(color: FlowPayColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlowPayColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: FlowPayRadii.button,
          ),
          textStyle: FlowPayTypography.label(color: Colors.white),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: FlowPayColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: FlowPayRadii.input,
          borderSide: BorderSide(color: FlowPayColors.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FlowPayRadii.input,
          borderSide: BorderSide(color: FlowPayColors.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FlowPayRadii.input,
          borderSide: BorderSide(color: FlowPayColors.ink, width: 1.5),
        ),
      ),
      extensions: const [FlowPayTokens.light],
    );
  }
}

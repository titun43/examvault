// =============================================================================
// ExamVault - App Fonts (Poppins + Assamese fallback)
// =============================================================================
// Poppins is the primary typeface (modern Latin look). When text contains
// Assamese/Bengali script characters (অসমীয়া) that Poppins lacks, Flutter
// automatically falls back through fontFamilyFallback to a system font that
// covers the Bengali-Assamese script block.
//
// On Android, "Noto Sans Bengali" is almost always present as a system font
// (it ships with Android 7+). For older devices, the generic "sans-serif"
// fallback still renders Assamese via the platform's default CJK/Indic font.
//
// The google_fonts package is also available (added in pubspec) for screens
// that want to explicitly load NotoSansBengali at runtime — e.g. for a
// dedicated Assamese banner where guaranteed rendering matters.
// =============================================================================

import 'package:flutter/material.dart';

class AppFonts {
  AppFonts._();

  static const String primary = 'Poppins';
  static const String display = 'Poppins';

  /// Fallback chain — tried in order for any glyph missing from Poppins.
  /// 'NotoSansBengali' covers Assamese (অসমীয়া) + Bengali (বাংলা) script.
  static const List<String> fallback = [
    'NotoSansBengali',
    'Noto Sans Bengali',
    'HindSiliguri',
    'sans-serif',
  ];

  /// Build a TextStyle with the full font fallback chain.
  static TextStyle style({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: primary,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      decoration: decoration,
    );
  }

  /// Material 3 TextTheme with Poppins + Assamese fallback on every style.
  /// Used as `textTheme` in AppTheme.lightTheme / darkTheme.
  static TextTheme get textTheme => TextTheme(
        // Display
        displayLarge: style(
            size: 57, weight: FontWeight.w400, height: 1.12),
        displayMedium: style(
            size: 45, weight: FontWeight.w400, height: 1.16),
        displaySmall: style(
            size: 36, weight: FontWeight.w400, height: 1.22),
        // Headline
        headlineLarge: style(
            size: 32, weight: FontWeight.w700, height: 1.25),
        headlineMedium: style(
            size: 28, weight: FontWeight.w700, height: 1.29),
        headlineSmall: style(
            size: 24, weight: FontWeight.w600, height: 1.33),
        // Title
        titleLarge: style(
            size: 22, weight: FontWeight.w600, height: 1.27),
        titleMedium: style(
            size: 16,
            weight: FontWeight.w500,
            height: 1.5,
            letterSpacing: 0.15),
        titleSmall: style(
            size: 14,
            weight: FontWeight.w500,
            height: 1.43,
            letterSpacing: 0.1),
        // Label
        labelLarge: style(
            size: 14,
            weight: FontWeight.w600,
            height: 1.43,
            letterSpacing: 0.1),
        labelMedium: style(
            size: 12,
            weight: FontWeight.w500,
            height: 1.33,
            letterSpacing: 0.5),
        labelSmall: style(
            size: 11,
            weight: FontWeight.w500,
            height: 1.45,
            letterSpacing: 0.5),
        // Body
        bodyLarge: style(
            size: 16,
            weight: FontWeight.w400,
            height: 1.5,
            letterSpacing: 0.5),
        bodyMedium: style(
            size: 14,
            weight: FontWeight.w400,
            height: 1.43,
            letterSpacing: 0.25),
        bodySmall: style(
            size: 12,
            weight: FontWeight.w400,
            height: 1.33,
            letterSpacing: 0.4),
      );

  /// Convenience: headline style for screen titles.
  static TextStyle get screenTitle => style(
        size: 22,
        weight: FontWeight.w700,
        height: 1.3,
      );

  /// Convenience: style for card titles.
  static TextStyle get cardTitle => style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.4,
      );

  /// Convenience: style for body text.
  static TextStyle get body => style(
        size: 14,
        weight: FontWeight.w400,
        height: 1.5,
      );

  /// Convenience: caption / metadata text.
  static TextStyle get caption => style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.4,
      );
}

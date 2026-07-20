// =============================================================================
// ExamVault - Theme Configuration (Modernized v2)
// =============================================================================
// Assam-inspired palette: Emerald (tea gardens / Brahmaputra) + Amber (gamocha).
// Material 3 tonal scheme with soft shadows, design tokens, and full dark mode.
// NO blue/indigo primary — respects project color guidelines.
//
// BACKWARD COMPATIBILITY: All legacy static color properties (primaryColor,
// accentColor, categoryColors, gradients, text styles, lightTheme, darkTheme)
// keep their names so existing screens compile unchanged. New tokens are
// additive (spacing, radius, elevation, softShadows, categoryGradients).
// =============================================================================

import 'package:flutter/material.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  // ==================== CORE PALETTE (Assam-inspired) ====================
  // Primary: Deep emerald/teal — অসমৰ চাহ-বাগিচা আৰু ব্ৰহ্মপুত্ৰ
  static const Color primaryColor = Color(0xFF0F766E);       // Teal 700
  static const Color primaryLightColor = Color(0xFF14B8A6);   // Teal 500
  static const Color primaryDarkColor = Color(0xFF115E59);    // Teal 800
  static const Color primaryUltraDarkColor = Color(0xFF042F2E); // Teal 950

  // Accent: Warm amber/saffron — গামোচা
  static const Color accentColor = Color(0xFFF59E0B);         // Amber 500
  static const Color accentLightColor = Color(0xFFFBBF24);    // Amber 400
  static const Color accentDarkColor = Color(0xFFD97706);     // Amber 600

  // Neutrals — warm stone (not cold blue-grey)
  static const Color backgroundColor = Color(0xFFFAFAF9);     // Stone 50
  static const Color surfaceColor = Color(0xFFF5F5F4);        // Stone 100
  static const Color errorColor = Color(0xFFDC2626);          // Red 600
  static const Color successColor = Color(0xFF16A34A);        // Green 600
  static const Color warningColor = Color(0xFFEA580C);        // Orange 600
  static const Color infoColor = Color(0xFF0F766E);           // Teal (brand)

  // ==================== DARK THEME COLORS ====================
  static const Color darkPrimaryColor = Color(0xFF2DD4BF);     // Teal 400
  static const Color darkPrimaryLightColor = Color(0xFF5EEAD4); // Teal 300
  static const Color darkBackgroundColor = Color(0xFF0C0A09);  // Stone 950
  static const Color darkSurfaceColor = Color(0xFF1C1917);     // Stone 900
  static const Color darkCardColor = Color(0xFF292524);        // Stone 800

  // ==================== EXAM CATEGORY COLORS ====================
  // Every Assam exam category now has its own distinct identity color.
  // Colors chosen to be visually distinct on the category grid.
  static const Map<String, Color> categoryColors = {
    // Assam-specific (priority)
    'ADRE': Color(0xFFEA580C),         // Orange 600 — flagship Assam exam
    'APSC': Color(0xFF7C3AED),         // Violet 600 — civil service
    'TET': Color(0xFFDB2777),          // Pink 600 — teacher eligibility
    'Assam Police': Color(0xFF334155), // Slate 700 — uniform
    'Police': Color(0xFF334155),       // alias
    'Secretariat': Color(0xFFCA8A04),  // Yellow 600 — bureaucratic
    'Assam Secretariat': Color(0xFFCA8A04), // alias
    // National (kept for legacy categories)
    'SSC': Color(0xFFBE123C),          // Rose 700
    'Railway': Color(0xFFDC2626),      // Red 600
    'UPSC': Color(0xFF9333EA),         // Purple 600
    'Banking': Color(0xFF16A34A),      // Green 600
    'State Exams': Color(0xFF0891B2),  // Cyan 600
  };

  // ==================== CATEGORY GRADIENTS (2-stop) ====================
  // For hero headers / banners — gives each category a signature look.
  static const Map<String, List<Color>> categoryGradients = {
    'ADRE': [Color(0xFFFB923C), Color(0xFFEA580C)],
    'APSC': [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    'TET': [Color(0xFFF472B6), Color(0xFFDB2777)],
    'Assam Police': [Color(0xFF64748B), Color(0xFF334155)],
    'Police': [Color(0xFF64748B), Color(0xFF334155)],
    'Secretariat': [Color(0xFFEAB308), Color(0xFFCA8A04)],
    'Assam Secretariat': [Color(0xFFEAB308), Color(0xFFCA8A04)],
    'SSC': [Color(0xFFFB7185), Color(0xFFBE123C)],
    'Railway': [Color(0xFFF87171), Color(0xFFDC2626)],
    'UPSC': [Color(0xFFC084FC), Color(0xFF9333EA)],
    'Banking': [Color(0xFF4ADE80), Color(0xFF16A34A)],
    'State Exams': [Color(0xFF22D3EE), Color(0xFF0891B2)],
  };

  /// Resolve a category's gradient (falls back to brand emerald gradient).
  static List<Color> gradientFor(String? categoryName) {
    if (categoryName == null) return brandGradient;
    return categoryGradients[categoryName] ??
        categoryGradients.entries
            .where((e) => categoryName.toLowerCase().contains(e.key.toLowerCase()))
            .map((e) => e.value)
            .firstWhere((_) => true, orElse: () => brandGradient);
  }

  /// Resolve a category's solid color (falls back to primary emerald).
  static Color colorFor(String? categoryName) {
    if (categoryName == null) return primaryColor;
    return categoryColors[categoryName] ??
        categoryColors.entries
            .where((e) => categoryName.toLowerCase().contains(e.key.toLowerCase()))
            .map((e) => e.value)
            .firstWhere((_) => true, orElse: () => primaryColor);
  }

  // ==================== DESIGN TOKENS ====================
  // Spacing scale — 4px base grid
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;
  static const double space3xl = 48;

  // Radius scale
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 28;
  static const double radiusFull = 9999;

  // Elevation as soft shadows (Material 3 style — diffuse, not harsh)
  static List<BoxShadow> get softShadow1 => [
        const BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get softShadow2 => [
        const BoxShadow(
          color: Color(0x10000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get softShadow3 => [
        const BoxShadow(
          color: Color(0x14000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
  static List<BoxShadow> get softShadow4 => [
        const BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];

  // ==================== FONT FAMILIES ====================
  // Primary: Poppins (Latin). Fallback: NotoSansBengali covers Assamese script
  // (অসমীয়া uses the Bengali-Assamese script family). Set via ThemeProvider
  // at runtime using google_fonts; the static list here is the fallback chain.
  static const List<String> fontFallback = [
    'Poppins',
    'NotoSansBengali',
    'Noto Sans Bengali',
    'sans-serif',
  ];

  // ==================== GRADIENTS ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryDarkColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, accentDarkColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Brand gradient — emerald → teal (used for hero headers, primary CTAs)
  static const List<Color> brandGradient = [
    Color(0xFF0F766E),
    Color(0xFF115E59),
  ];

  /// Accent gradient — amber → orange (used for premium, highlights)
  static const List<Color> accentGradientColors = [
    Color(0xFFF59E0B),
    Color(0xFFD97706),
  ];

  // Legacy cardGradient — keep name, update to brand emerald (was blue)
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== TEXT STYLES ====================
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFamily: 'Poppins',
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFamily: 'Poppins',
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: 'Poppins',
    height: 1.3,
  );

  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    height: 1.5,
  );

  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    height: 1.4,
  );

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: accentColor,
      surface: backgroundColor,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: 'Poppins',
      textTheme: AppFonts.textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Color(0xFF1C1917),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1C1917),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF9CA3AF),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor,
        labelStyle: const TextStyle(fontFamily: 'Poppins'),
        secondaryLabelStyle:
            const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        brightness: Brightness.light,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkPrimaryColor,
      brightness: Brightness.dark,
      primary: darkPrimaryColor,
      secondary: accentColor,
      surface: darkSurfaceColor,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackgroundColor,
      fontFamily: 'Poppins',
      textTheme: AppFonts.textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
      cardTheme: CardTheme(
        color: darkCardColor,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryColor,
          foregroundColor: darkBackgroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimaryColor,
          side: const BorderSide(color: darkPrimaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkPrimaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade400),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurfaceColor,
        selectedItemColor: darkPrimaryColor,
        unselectedItemColor: Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

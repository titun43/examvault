// =============================================================================
// ExamVault - Theme Configuration (Modernized v3 — Testbook-style blue)
// =============================================================================
// Primary: Vivid blue #0066FF (Testbook-style clean professional look).
// Accent: Warm amber (premium/buy highlights). Background: pure white so
// cards float on subtle shadows + a 1px #E5E7EB border.
// Category identity colors (ADRE/APSC/TET/...) are PRESERVED so each exam
// keeps its signature gradient on hero headers.
//
// BACKWARD COMPATIBILITY: All legacy static color properties (primaryColor,
// accentColor, categoryColors, gradients, text styles, lightTheme, darkTheme)
// keep their names so existing screens compile unchanged. New tokens are
// additive (spacing, radius, elevation, softShadows, categoryGradients,
// liveBadgeColor, cardBorderColor).
// =============================================================================

import 'package:flutter/material.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  // ==================== CORE PALETTE (Testbook-style blue) ====================
  // Primary: Vivid blue #0066FF — clean professional exam-prep look.
  static const Color primaryColor = Color(0xFF0066FF);         // Blue (brand)
  static const Color primaryLightColor = Color(0xFF3D8BFF);    // Lighter blue
  static const Color primaryDarkColor = Color(0xFF0052CC);     // Darker blue
  static const Color primaryUltraDarkColor = Color(0xFF003D99); // Deep blue

  // Accent: Warm amber (premium / buy highlights — kept from v2)
  static const Color accentColor = Color(0xFFF59E0B);         // Amber 500
  static const Color accentLightColor = Color(0xFFFBBF24);    // Amber 400
  static const Color accentDarkColor = Color(0xFFD97706);     // Amber 600

  // Neutrals — pure white background (cards float on shadow + subtle border)
  static const Color backgroundColor = Color(0xFFFFFFFF);     // Pure white
  static const Color surfaceColor = Color(0xFFFFFFFF);        // Pure white
  static const Color cardBorderColor = Color(0xFFE5E7EB);     // Light gray border
  static const Color errorColor = Color(0xFFDC2626);          // Red 600
  static const Color successColor = Color(0xFF16A34A);        // Green 600 (FREE badge)
  static const Color warningColor = Color(0xFFEA580C);        // Orange 600
  static const Color infoColor = Color(0xFF0066FF);           // Blue (brand)

  // Live badge — pink outlined, Testbook-style for live quizzes/tests
  static const Color liveBadgeColor = Color(0xFFEC4899);      // Pink 500

  // ==================== SEMANTIC TYPE COLORS ====================
  // Brand-aligned replacements for raw `Colors.purple/green/teal/...` that
  // used to scatter through the test, notification, and announcement screens.
  // All tokens harmonize with the emerald + amber brand palette so dark/light
  // themes stay consistent. Add new tokens here rather than reaching for raw
  // Material colors.

  // Test type chips — test_series_screen.dart `_getTypeColor(TestType)`.
  // Each TestType gets a distinct, harmonious hue (no raw Colors.xxx).
  static const Color typeMock = Color(0xFF0F766E);          // Teal 700 (brand primary)
  static const Color typePreviousYear = Color(0xFFD97706);  // Amber 600 (brand accent dark)
  static const Color typeDailyQuiz = Color(0xFF7C3AED);     // Violet 600 (matches APSC)
  static const Color typePractice = Color(0xFF059669);      // Emerald 600
  static const Color typeSubjectwise = Color(0xFF14B8A6);   // Teal 500 (brand primary light)

  // Notification type chips — notifications_screen.dart `_getTypeColor(NotificationType)`.
  static const Color notifColorCurrentAffair = Color(0xFF7C3AED);  // Violet 600
  static const Color notifColorPremium = Color(0xFFFBBF24);        // Amber 400
  static const Color notifColorAnnouncement = Color(0xFF0F766E);   // Teal 700 (brand)
  static const Color notifColorDailyQuiz = Color(0xFF14B8A6);      // Teal 500 (brand)
  static const Color notifColorDefault = Color(0xFF71717A);        // Zinc 500 (neutral)

  // "Mark for review" palette entry — test_instructions_screen.dart legend.
  // Distinct from success/error so users instantly recognize the review state.
  static const Color reviewMarkColor = Color(0xFF7C3AED);   // Violet 600

  // ==================== DARK THEME COLORS ====================
  static const Color darkPrimaryColor = Color(0xFF5A9CFF);     // Lighter blue (dark mode)
  static const Color darkPrimaryLightColor = Color(0xFF80B3FF); // Even lighter blue
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
  //
  // SINGLE SOURCE OF TRUTH: AppTheme.fontFallback is the same List as
  // AppFonts.fallback — defining it as a const reference (rather than a
  // second literal list) avoids the historical divergence bug where the
  // two lists drifted and Assamese glyphs (অসমীয়া) tofu'd on widgets that
  // used the legacy text-style constants (heading1/2/3, bodyText1/2,
  // caption) below. Do NOT redefine this list inline — always reference
  // AppFonts.fallback so the chain stays unified.
  static const List<String> fontFallback = AppFonts.fallback;

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

  /// Brand gradient — blue → deep blue (used for hero headers, primary CTAs)
  static const List<Color> brandGradient = [
    Color(0xFF0066FF),
    Color(0xFF0052CC),
  ];

  /// Accent gradient — amber → orange (used for premium, highlights)
  static const List<Color> accentGradientColors = [
    Color(0xFFF59E0B),
    Color(0xFFD97706),
  ];

  // Legacy cardGradient — keep name, updated to brand blue (Testbook v3)
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF3D8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== TEXT STYLES ====================
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
    height: 1.3,
  );

  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
    height: 1.5,
  );

  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: 'Poppins',
    fontFamilyFallback: AppTheme.fontFallback,
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontFamilyFallback: AppTheme.fontFallback,
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
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          fontFamilyFallback: AppTheme.fontFallback,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
          fontFamilyFallback: AppTheme.fontFallback,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCardColor,
        selectedColor: darkPrimaryColor,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontFamilyFallback: AppTheme.fontFallback,
        ),
        secondaryLabelStyle: const TextStyle(
          color: darkBackgroundColor,
          fontFamily: 'Poppins',
          fontFamilyFallback: AppTheme.fontFallback,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

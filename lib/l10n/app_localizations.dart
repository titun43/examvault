// =============================================================================
// ExamVault - App Localizations (Bilingual EN + অসমীয়া)
// =============================================================================
// Provides:
//   - LanguageMode enum: english | assamese | both
//   - LanguageProvider: persisted user preference (SharedPreferences)
//   - tr(context, key): translate a key → single string per current mode
//   - trBoth(context, key): returns "English / অসমীয়া" for the "both" mode
//   - L10nText widget: drop-in replacement for Text() that auto-translates
//
// Usage in screens:
//   Text(tr(context, 'subject_tests'))           // → "Tests" or "পৰীক্ষা"
//   L10nText('subject_tests')                    // same, as a widget
//   Text(trBoth(context, 'subject_tests'))       // → "Tests / পৰীক্ষা"
//
// When mode == both, tr() returns the "English / অসমীয়া" combined form so
// users who read both languages see everything at once.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

// ==================== LANGUAGE MODE ====================
enum LanguageMode {
  english,
  assamese,
  both,
}

// ==================== LANGUAGE PROVIDER ====================
class LanguageProvider extends ChangeNotifier {
  LanguageMode _mode = LanguageMode.english;

  LanguageMode get mode => _mode;

  /// True when the user wants to see Assamese (either alone or alongside English).
  bool get showsAssamese =>
      _mode == LanguageMode.assamese || _mode == LanguageMode.both;

  /// True when the user wants to see English (either alone or alongside Assamese).
  bool get showsEnglish =>
      _mode == LanguageMode.english || _mode == LanguageMode.both;

  LanguageProvider() {
    _loadMode();
  }

  Future<void> _loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt('languageMode') ?? 0;
      if (index >= 0 && index < LanguageMode.values.length) {
        _mode = LanguageMode.values[index];
      } else {
        _mode = LanguageMode.english;
      }
      if (!disposed) notifyListeners();
    } catch (_) {
      _mode = LanguageMode.english;
      if (!disposed) notifyListeners();
    }
  }

  void setMode(LanguageMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (!disposed) notifyListeners();
    _persistMode(mode);
  }

  Future<void> _persistMode(LanguageMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('languageMode', mode.index);
    } catch (_) {
      // Ignore prefs write errors.
    }
  }

  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ==================== HELPER FUNCTIONS ====================

/// Resolve a single string for the current language mode.
///
/// - english  → "Tests"
/// - assamese → "পৰীক্ষা"
/// - both     → "Tests / পৰীক্ষা"
///
/// Falls back to the key itself if not found (makes missing strings obvious
/// during development without crashing).
String tr(BuildContext context, String key) {
  final mode = Provider.of<LanguageProvider>(context, listen: false).mode;
  final en = AppStrings.english[key];
  final as = AppStrings.assamese[key];

  switch (mode) {
    case LanguageMode.english:
      return en ?? as ?? key;
    case LanguageMode.assamese:
      return as ?? en ?? key;
    case LanguageMode.both:
      if (en == null && as == null) return key;
      if (en == null) return as!;
      if (as == null) return en;
      return '$en / $as';
  }
}

/// Always returns the combined "English / অসমীয়া" form regardless of mode.
/// Use for critical labels that should always show both languages (e.g. exam
/// names, navigation items).
String trBoth(BuildContext context, String key) {
  final en = AppStrings.english[key];
  final as = AppStrings.assamese[key];
  if (en == null && as == null) return key;
  if (en == null) return as!;
  if (as == null) return en;
  return '$en / $as';
}

/// Resolve just the English form (useful for logging / analytics).
String trEn(String key) => AppStrings.english[key] ?? key;

/// Resolve just the Assamese form.
String trAs(String key) => AppStrings.assamese[key] ?? key;

// ==================== L10nText WIDGET ====================

/// Drop-in replacement for `Text()` that auto-translates a localization key.
///
/// Example:
///   L10nText('subject_tests', style: TextStyle(fontSize: 16))
/// instead of:
///   Text(tr(context, 'subject_tests'), style: TextStyle(fontSize: 16))
class L10nText extends StatelessWidget {
  final String l10nKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool both; // if true, always show "English / অসমীয়া"

  const L10nText(
    this.l10nKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.both = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = both ? trBoth(context, l10nKey) : tr(context, l10nKey);
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

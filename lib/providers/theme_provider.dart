// =============================================================================
// ExamVault - Theme Provider (Light/Dark mode toggle)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  void _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('themeMode') ?? 0;
      // Bound-check to avoid RangeError on corrupt prefs.
      if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeIndex];
      } else {
        _themeMode = ThemeMode.system;
      }
      if (!disposed) notifyListeners();
    } catch (_) {
      _themeMode = ThemeMode.system;
      if (!disposed) notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // Notify synchronously so the UI updates immediately, before the async
    // prefs write completes.
    if (!disposed) notifyListeners();
    _persistThemeMode(mode);
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', mode.index);
    } catch (_) {
      // Ignore prefs write errors — not critical.
    }
  }

  /// Toggles between light and dark based on the *actually rendered* brightness
  /// (resolving `ThemeMode.system` against the platform brightness), so the
  /// toggle always produces a visible change and never lands on a pure-white
  /// light theme when the user was already seeing light via system mode.
  void toggleTheme() {
    final currentlyDark = isDarkMode;
    setThemeMode(currentlyDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Returns true when the app is *currently rendering* the dark theme,
  /// resolving `ThemeMode.system` against the platform brightness.
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding
              .instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

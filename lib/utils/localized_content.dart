// =============================================================================
// ExamVault - Localized Content Helper
// =============================================================================
// Resolves which language form of a content field to show, based on the user's
// LanguageMode preference (english / assamese / both).
//
// Models expose both the English field (e.g. `name`) and the Assamese field
// (e.g. `nameAs`, nullable). Screens call these helpers instead of reading the
// raw fields directly so the user's language preference is honored everywhere.
//
// Behavior:
//   english  → always English field
//   assamese → Assamese field if non-empty, else English fallback
//   both     → "English / অসমীয়া" combined form (Assamese only if non-empty)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

/// Resolve a single string field for the current language mode.
String lc(
  BuildContext context,
  String english,
  String? assamese,
) {
  // listen:true so widgets rebuild when the user changes language in Settings.
  // (All call sites are in build() — audited; none in callback bodies.)
  final mode = Provider.of<LanguageProvider>(context, listen: true).mode;
  final hasAs = assamese != null && assamese.isNotEmpty;
  switch (mode) {
    case LanguageMode.assamese:
      return hasAs ? assamese! : english;
    case LanguageMode.both:
      return hasAs ? '$english / $assamese' : english;
    case LanguageMode.english:
      return english;
  }
}

/// Resolve a list field (e.g. question options) for the current language mode.
/// Falls back to the English list when the Assamese list is empty or has a
/// different length (defensive: avoids index mismatch if admin only partially
/// translated the options).
List<String> lcList(
  BuildContext context,
  List<String> english,
  List<String> assamese,
) {
  if (assamese.isEmpty || assamese.length != english.length) {
    return english;
  }
  final mode = Provider.of<LanguageProvider>(context, listen: true).mode;
  switch (mode) {
    case LanguageMode.assamese:
      return assamese;
    case LanguageMode.both:
    case LanguageMode.english:
      return english;
  }
}

/// True when the user wants Assamese (either alone or in "both" mode).
bool lcShowsAssamese(BuildContext context) {
  return Provider.of<LanguageProvider>(context, listen: true).showsAssamese;
}

// =============================================================================
// ExamVault - Share Helper
// Centralizes sharing of individual exams / current affairs so the full-list
// screens and the per-item detail screens use identical logic. Every shared
// message ends with the ExamVault Play Store link so recipients can download
// the app — the owner specifically requested that shared content always
// carry the app link.
// =============================================================================

import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/upcoming_exam_model.dart';
import '../models/current_affair_model.dart';

class ShareHelper {
  ShareHelper._();

  /// Builds the canonical ExamVault Play Store URL from the running app's
  /// package name. Falls back to the known package if PackageInfo is
  /// unavailable (extremely unlikely).
  static Future<String> _storeUrl() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final pkg = info.packageName.isEmpty
          ? 'com.examvault.education'
          : info.packageName;
      return 'https://play.google.com/store/apps/details?id=$pkg';
    } catch (_) {
      return 'https://play.google.com/store/apps/details?id=com.examvault.education';
    }
  }

  /// A short app-promo footer used on every shared message.
  static Future<String> _appFooter() async {
    final url = await _storeUrl();
    return '\n\nDownload ExamVault for more mock tests, daily quizzes & current '
        'affairs:\n$url';
  }

  static String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m - 1];
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  /// Shares a single upcoming exam. Includes name, organization, exam date,
  /// a short description (truncated to keep WhatsApp/SMS previews readable),
  /// apply URL when present, and the app download footer.
  static Future<void> shareExam(UpcomingExamModel exam) async {
    final lines = <String>[];
    lines.add('🔥 ${exam.name}');
    final meta = <String>[];
    if (exam.organization != null && exam.organization!.isNotEmpty) {
      meta.add(exam.organization!);
    }
    meta.add('Exam Date: ${_fmtDate(exam.examDate)}');
    lines.add(meta.join(' • '));

    if (exam.description.isNotEmpty) {
      // Keep the description short so the overall share text stays
      // share-friendly (long messages get truncated by some apps).
      final desc = exam.description.length > 200
          ? '${exam.description.substring(0, 200)}…'
          : exam.description;
      lines.add(desc);
    }

    if (exam.applyUrl != null && exam.applyUrl!.isNotEmpty) {
      lines.add('Apply here: ${exam.applyUrl}');
    }

    final footer = await _appFooter();
    // Append the footer so the app download link is always in the body.
    final body = '${lines.join('\n')}$footer';
    await Share.share(
      body,
      subject: 'ExamVault — ${exam.name}',
    );
  }

  /// Shares a single current affair. Includes title, date, category, summary,
  /// PDF URL when present, and the app download footer.
  static Future<void> shareCurrentAffair(CurrentAffairModel affair) async {
    final lines = <String>[];
    lines.add('📰 ${affair.title}');

    final meta = <String>[];
    meta.add(_fmtDate(affair.date));
    if (affair.category.isNotEmpty) meta.add(affair.category);
    if (affair.source.isNotEmpty) meta.add('Source: ${affair.source}');
    lines.add(meta.join(' • '));

    if (affair.summary.isNotEmpty) {
      final summary = affair.summary.length > 280
          ? '${affair.summary.substring(0, 280)}…'
          : affair.summary;
      lines.add(summary);
    } else if (affair.content.isNotEmpty) {
      final content = affair.content.length > 280
          ? '${affair.content.substring(0, 280)}…'
          : affair.content;
      lines.add(content);
    }

    if (affair.pdfUrl != null && affair.pdfUrl!.isNotEmpty) {
      lines.add('PDF: ${affair.pdfUrl}');
    }

    final footer = await _appFooter();
    // Build the final body with the footer so it's always included.
    final body = '${lines.join('\n')}$footer';
    await Share.share(
      body,
      subject: 'ExamVault — ${affair.title}',
    );
  }
}

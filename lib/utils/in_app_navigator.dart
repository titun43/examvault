// =============================================================================
// ExamVault - In-App Navigator
// Resolves an in-app [screen] identifier (+ optional [params]) to a concrete
// Navigator.push call. Used by Banner + Announcement action buttons so the
// admin can make a button navigate INSIDE the app (e.g. "Start Test" → opens
// a specific test, "Browse Subject" → opens a subject's test list).
//
// Supported screen identifiers:
//   - testSeries      → TestSeriesScreen
//   - dailyQuiz       → DailyQuizScreen
//   - upcomingExams   → UpcomingExamsScreen
//   - currentAffairs  → CurrentAffairsScreen
//   - announcements   → AnnouncementsScreen
//   - leaderboard     → LeaderboardScreen
//   - premium         → PremiumScreen
//   - category        → CategoryDetailScreen      (params: categoryId)
//   - subject         → TestListScreen            (params: subjectId)
//   - test            → TakeTestScreen            (params: testId)
//
// For category / subject / test, the helper fetches the corresponding doc
// from Firestore by id before navigating. If the doc doesn't exist or the
// fetch fails, a SnackBar is shown and no navigation happens (so the user
// isn't dumped on a blank screen).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/action_button.dart';
import '../services/firestore_service.dart';
import '../screens/tests/test_series_screen.dart';
import '../screens/tests/daily_quiz_screen.dart';
import '../screens/tests/test_list_screen.dart';
import '../screens/tests/take_test_screen.dart';
import '../screens/home/category_detail_screen.dart';
import '../screens/upcoming_exams/upcoming_exams_screen.dart';
import '../screens/current_affairs/current_affairs_screen.dart';
import '../screens/announcements/announcements_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/premium/premium_screen.dart';

/// Executes an [ActionButton] — opens the external URL in the browser for
/// `ActionType.external`, or navigates to the in-app screen for
/// `ActionType.inApp`. Shows a SnackBar on failure (missing/invalid url,
/// unknown screen, doc not found).
///
/// Used by the Home banner card and the Announcements screen card so both
/// surfaces share identical action-handling logic.
Future<void> runActionButton(BuildContext context, ActionButton button) async {
  if (button.type == ActionType.external) {
    final raw = button.url ?? '';
    if (raw.isEmpty) {
      _toast(context, 'This button has no link set.');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      _toast(context, 'Invalid link: $raw');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {
        _toast(context, 'Could not open link.');
      }
    }
    return;
  }
  // ActionType.inApp
  await InAppNavigator.navigate(context, button);
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

class InAppNavigator {
  InAppNavigator._();

  /// The list of supported in-app screen identifiers, in the order they
  /// should appear in the admin dropdown.
  static const List<String> supportedScreens = [
    'testSeries',
    'dailyQuiz',
    'upcomingExams',
    'currentAffairs',
    'announcements',
    'leaderboard',
    'premium',
    'category',
    'subject',
    'test',
  ];

  /// Human-readable labels for each screen, for the admin dropdown.
  static const Map<String, String> screenLabels = {
    'testSeries': 'Test Series',
    'dailyQuiz': 'Daily Quiz',
    'upcomingExams': 'Upcoming Exams',
    'currentAffairs': 'Current Affairs',
    'announcements': 'Announcements',
    'leaderboard': 'Leaderboard (Ranks)',
    'premium': 'Premium / Upgrade',
    'category': 'Specific Category',
    'subject': "Specific Subject's Tests",
    'test': 'Specific Test (start directly)',
  };

  /// Returns true if [screen] requires extra params (a doc id).
  static bool requiresParams(String? screen) {
    return screen == 'category' || screen == 'subject' || screen == 'test';
  }

  /// Navigates to the in-app screen described by [button]. Shows a SnackBar
  /// on failure (unknown screen, missing params, doc not found).
  static Future<void> navigate(BuildContext context, ActionButton button) async {
    final screen = button.screen;
    final params = button.params;
    if (screen == null || screen.isEmpty) {
      _toast(context, 'This button has no screen set.');
      return;
    }

    switch (screen) {
      case 'testSeries':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TestSeriesScreen()));
        return;
      case 'dailyQuiz':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailyQuizScreen()));
        return;
      case 'upcomingExams':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UpcomingExamsScreen()));
        return;
      case 'currentAffairs':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()));
        return;
      case 'announcements':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
        return;
      case 'leaderboard':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        return;
      case 'premium':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PremiumScreen()));
        return;
      case 'category':
        await _navigateToCategory(context, params);
        return;
      case 'subject':
        await _navigateToSubject(context, params);
        return;
      case 'test':
        await _navigateToTest(context, params);
        return;
      default:
        _toast(context, 'Unknown screen: $screen');
    }
  }

  static Future<void> _navigateToCategory(
      BuildContext context, Map<String, dynamic> params) async {
    final id = params['categoryId']?.toString() ?? '';
    if (id.isEmpty) {
      _toast(context, 'This button is missing a category id.');
      return;
    }
    final cat = await FirestoreService.getCategoryById(id);
    if (cat == null) {
      _toast(context, 'Category not found.');
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: cat)),
    );
  }

  static Future<void> _navigateToSubject(
      BuildContext context, Map<String, dynamic> params) async {
    final id = params['subjectId']?.toString() ?? '';
    if (id.isEmpty) {
      _toast(context, 'This button is missing a subject id.');
      return;
    }
    final subj = await FirestoreService.getSubjectById(id);
    if (subj == null) {
      _toast(context, 'Subject not found.');
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TestListScreen(subject: subj)),
    );
  }

  static Future<void> _navigateToTest(
      BuildContext context, Map<String, dynamic> params) async {
    final id = params['testId']?.toString() ?? '';
    if (id.isEmpty) {
      _toast(context, 'This button is missing a test id.');
      return;
    }
    final test = await FirestoreService.getTest(id);
    if (test == null) {
      _toast(context, 'Test not found.');
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
    );
  }
}

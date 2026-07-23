// =============================================================================
// ExamVault - Test Series Screen (All Tests)
// =============================================================================
// Bottom-nav "Tests" tab. Previously showed every published test/subject
// across ALL categories regardless of what the user picked during
// onboarding (Home screen category picker). Now filters down to the
// user's selected categories, same as Home — falls back to showing
// everything if nothing is selected/skipped.
//
// Also shows a "Completed · X%" badge on each test card using the user's
// LATEST attempt for that test (see FirestoreService.getLatestResultsByTestId),
// so users browsing a category with many tests can see at a glance which
// ones they've already taken.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../models/test_result_model.dart';
import '../../services/firestore_service.dart';
import '../../services/category_preference_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/localized_content.dart';
import '../../l10n/app_localizations.dart';
import '../search/search_screen.dart';
import '../onboarding/category_selection_screen.dart';
import 'test_instructions_screen.dart';

class TestSeriesScreen extends StatefulWidget {
  const TestSeriesScreen({super.key});

  @override
  State<TestSeriesScreen> createState() => _TestSeriesScreenState();
}

class _TestSeriesScreenState extends State<TestSeriesScreen> {
  List<String> _selectedCategoryIds = [];
  // subjectId -> resolved categoryId (subject.categoryId may hold a name/slug
  // instead of the real doc id — same resolution FirestoreService already
  // uses elsewhere, see resolveCategoryId).
  Map<String, String> _subjectCategoryMap = {};
  Map<String, TestResultModel> _latestResults = {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final selectedIds =
        await CategoryPreferenceService.getSelectedCategoryIds(auth.user);

    // Build subjectId -> resolved categoryId map (only needed if the user
    // actually has a category filter active — skip the extra reads otherwise).
    Map<String, String> subjectCategoryMap = {};
    if (selectedIds.isNotEmpty) {
      final subjects = await FirestoreService.getSubjects();
      final refs = subjects.map((s) => s.categoryId).toSet();
      final resolved = <String, String>{};
      await Future.wait(refs.map((ref) async {
        final id = await FirestoreService.resolveCategoryId(ref);
        if (id != null) resolved[ref] = id;
      }));
      for (final s in subjects) {
        final resolvedId = resolved[s.categoryId];
        if (resolvedId != null) subjectCategoryMap[s.id] = resolvedId;
      }
    }

    Map<String, TestResultModel> latestResults = {};
    if (auth.user != null) {
      latestResults =
          await FirestoreService.getLatestResultsByTestId(auth.user!.id);
    }

    if (!mounted) return;
    setState(() {
      _selectedCategoryIds = selectedIds;
      _subjectCategoryMap = subjectCategoryMap;
      _latestResults = latestResults;
      _ready = true;
    });
  }

  Future<void> _openManageCategories() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectionScreen(isOnboarding: false),
      ),
    );
    if (changed == true) _load();
  }

  /// True when this test belongs to (or can't be matched against, in which
  /// case we don't hide it) the user's selected categories.
  bool _matchesFilter(TestModel test) {
    if (_selectedCategoryIds.isEmpty) return true; // no filter active
    final categoryId = _subjectCategoryMap[test.subjectId];
    if (categoryId == null) return true; // unresolved — don't hide, be safe
    return _selectedCategoryIds.contains(categoryId);
  }

  @override
  Widget build(BuildContext context) {
    // Consolidated from 6 tabs to 4 (Issue #15):
    //  - "All"          → all tests
    //  - "Mock"         → mock + practice (practice is a subset of mock-style tests)
    //  - "Previous Year"→ previousYear only
    //  - "Subject-wise" → subjectwise + dailyQuiz (daily quizzes are subject-tagged)
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'test_series_title')),
          actions: [
            // Lets the user revisit/change which categories they're focused
            // on, same picker used during onboarding and on Home.
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: tr(context, 'my_categories'),
              onPressed: _openManageCategories,
            ),
            // Global search — available on every bottom-nav tab, not just Home.
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: tr(context, 'search'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr(context, 'test_all')),
              Tab(text: tr(context, 'test_mock')),
              Tab(text: tr(context, 'test_previousYear')),
              Tab(text: tr(context, 'test_series_tab_subjectwise')),
            ],
          ),
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildTestList(context, null),
                  _buildTestList(context, const [TestType.mock, TestType.practice]),
                  _buildTestList(context, const [TestType.previousYear]),
                  _buildTestList(context, const [TestType.subjectwise, TestType.dailyQuiz]),
                ],
              ),
      ),
    );
  }

  Widget _buildTestList(BuildContext context, List<TestType>? types) {
    // Optimization: when only one type is requested, push the filter down to
    // Firestore (single-field `type ==` query — no composite index needed).
    // When 2+ types are requested (Mock, Subject-wise consolidation) we
    // fetch all published tests and filter client-side, because
    // FirestoreService.getTestsStream only supports a single `type` and we
    // deliberately avoid composite indexes.
    final TestType? firestoreType =
        (types != null && types.length == 1) ? types.first : null;
    return StreamBuilder<List<TestModel>>(
      stream: FirestoreService.getTestsStream(
          type: firestoreType, isPublished: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(tr(context, 'test_noTests')),
              ],
            ),
          );
        }
        final tests = snapshot.data!
            .where((t) =>
                _matchesFilter(t) &&
                (types == null || types.contains(t.type)))
            .toList();
        if (tests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(tr(context, 'test_series_no_tests_in_categories')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openManageCategories,
                  child: Text(tr(context, 'test_series_edit_categories')),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tests.length,
          itemBuilder: (context, index) {
            final test = tests[index];
            return _buildTestCard(context, test);
          },
        );
      },
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
    final latest = _latestResults[test.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(test.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getTypeName(context, test.type),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getTypeColor(test.type),
                    ),
                  ),
                ),
                const Spacer(),
                if (latest != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 12, color: AppTheme.successColor),
                        const SizedBox(width: 4),
                        Text(
                          '${tr(context, 'test_series_completed')} · ${latest.percentage.round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (test.isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium, size: 12, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          tr(context, 'premium'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lc(context, test.title, test.titleAs),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Test meta info — wraps cleanly on small screens (was a Row that
            // overflowed/truncated the marks text on narrow devices).
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.help_outline,
                    '${test.questionCount} ${tr(context, 'test_series_qs_suffix')}'),
                _buildInfoChip(Icons.timer_outlined,
                    '${test.duration} ${tr(context, 'test_duration')}'),
                _buildInfoChip(Icons.star_outline,
                    '${test.totalMarks} ${tr(context, 'test_marks')}'),
                _buildInfoChip(Icons.trending_up,
                    '${test.attemptCount} ${tr(context, 'test_attempts')}'),
                _buildDifficultyChip(test.difficulty),
              ],
            ),
            const SizedBox(height: 16),
            // Full-width Start button — no truncation, easy to tap.
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate directly to TakeTestScreen so categoryId is
                  // resolved inside TakeTestScreen via getSubjectById +
                  // resolveCategoryId — fixing the "Go Premium" bug for
                  // exam-pack holders who arrive through Test Series.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TestInstructionsScreen(test: test),
                    ),
                  );
                },
                icon: Icon(latest != null ? Icons.refresh : Icons.play_arrow,
                    size: 20),
                label: Text(latest != null
                    ? tr(context, 'result_retake')
                    : tr(context, 'test_startTest')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(TestDifficulty difficulty) {
    final color = difficulty == TestDifficulty.easy
        ? AppTheme.successColor
        : difficulty == TestDifficulty.medium
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _difficultyLabel(context, difficulty),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getTypeColor(TestType type) {
    switch (type) {
      case TestType.mock:
        return AppTheme.typeMock;
      case TestType.previousYear:
        return AppTheme.typePreviousYear;
      case TestType.dailyQuiz:
        return AppTheme.typeDailyQuiz;
      case TestType.practice:
        return AppTheme.typePractice;
      case TestType.subjectwise:
        return AppTheme.typeSubjectwise;
    }
  }

  String _getTypeName(BuildContext context, TestType type) {
    switch (type) {
      case TestType.mock:
        return tr(context, 'test_type_mock');
      case TestType.previousYear:
        return tr(context, 'test_type_previous_year');
      case TestType.dailyQuiz:
        return tr(context, 'test_type_daily_quiz');
      case TestType.practice:
        return tr(context, 'test_type_practice');
      case TestType.subjectwise:
        return tr(context, 'test_type_subjectwise');
    }
  }

  String _difficultyLabel(BuildContext context, TestDifficulty difficulty) {
    switch (difficulty) {
      case TestDifficulty.easy:
        return tr(context, 'test_difficulty_easy');
      case TestDifficulty.medium:
        return tr(context, 'test_difficulty_medium');
      case TestDifficulty.hard:
        return tr(context, 'test_difficulty_hard');
    }
  }
}

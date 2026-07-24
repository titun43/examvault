// =============================================================================
// ExamVault - Test Series Screen (All Tests)
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../search/search_screen.dart';
import 'take_test_screen.dart';
import 'test_list_screen.dart';

class TestSeriesScreen extends StatelessWidget {
  const TestSeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Series'),
          actions: [
            // Global search — available on every bottom-nav tab, not just Home.
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Mock'),
              Tab(text: 'Previous Year'),
              Tab(text: 'Daily Quiz'),
              Tab(text: 'Practice'),
              Tab(text: 'Subject-wise'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTestList(context, null),
            _buildTestList(context, TestType.mock),
            _buildTestList(context, TestType.previousYear),
            _buildTestList(context, TestType.dailyQuiz),
            _buildTestList(context, TestType.practice),
            _buildSubjectList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTestList(BuildContext context, TestType? type) {
    return StreamBuilder<List<TestModel>>(
      stream: FirestoreService.getTestsStream(type: type, isPublished: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tests available'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final test = snapshot.data![index];
            return _buildTestCard(context, test);
          },
        );
      },
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
    final subtleTextColor = const Color(0xFF6B7280);
    final borderColor = AppTheme.cardBorderColor;
    final footerBgColor = const Color(0xFFFAFAFA);

    // Access badge label + color (Row 1 left).
    final String accessLabel;
    final Color accessColor;
    final bool accessIsGradient;
    if (!test.isPaid) {
      accessLabel = 'FREE';
      accessColor = AppTheme.successColor;
      accessIsGradient = false;
    } else if (test.isPremium && test.price <= 0) {
      accessLabel = 'Premium';
      accessColor = AppTheme.accentColor;
      accessIsGradient = true;
    } else {
      accessLabel = '\u20b9${test.price}';
      accessColor = AppTheme.accentColor;
      accessIsGradient = false;
    }

    // CTA link label (Row 3 right).
    final String ctaLabel = !test.isPaid
        ? 'Start Now'
        : (test.isPremium && test.price <= 0
            ? 'Unlock'
            : 'Buy \u20b9${test.price}');
    final Color ctaColor = !test.isPaid
        ? AppTheme.primaryColor
        : AppTheme.accentColor;
    final IconData ctaIcon = !test.isPaid
        ? Icons.arrow_forward_rounded
        : (test.isPremium && test.price <= 0
            ? Icons.workspace_premium_rounded
            : Icons.shopping_cart_outlined);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TakeTestScreen(test: test),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Top content block =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceMd,
                    AppTheme.spaceLg,
                    AppTheme.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== ROW 1: Badges (left) + type tag (right) =====
                      Row(
                        children: [
                          // Access badge pill.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              gradient: accessIsGradient
                                  ? LinearGradient(
                                      colors:
                                          AppTheme.accentGradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: accessIsGradient
                                  ? null
                                  : accessColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                            ),
                            child: Text(
                              accessLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accessIsGradient
                                    ? Colors.white
                                    : accessColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          // Type pill (outlined, primary).
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _getTypeName(test.type),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Difficulty chip (right).
                          _buildDifficultyChip(test.difficulty),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 2: Title =====
                      Text(
                        test.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1917),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 3: Stats (left) + Start Now link (right) =====
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment:
                                  WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${test.questionCount} Qs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.duration} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.totalMarks} marks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          // "Start Now →" link.
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TakeTestScreen(test: test),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSm,
                                vertical: AppTheme.spaceXs,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctaLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ctaColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(ctaIcon, size: 16, color: ctaColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===== ROW 4: Footer bar =====
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                    vertical: AppTheme.spaceSm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: footerBgColor,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        '${test.attemptCount} attempts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Icon(Icons.people_alt_outlined,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        'All users',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.share_outlined,
                        size: 13,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gray dot separator between stats.
  Widget _dotSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '\u00b7',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(TestDifficulty difficulty) {
    final color = difficulty == TestDifficulty.easy
        ? Colors.green
        : difficulty == TestDifficulty.medium
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getTypeName(TestType type) {
    switch (type) {
      case TestType.mock:
        return 'MOCK TEST';
      case TestType.previousYear:
        return 'PREVIOUS YEAR';
      case TestType.dailyQuiz:
        return 'DAILY QUIZ';
      case TestType.practice:
        return 'PRACTICE';
      case TestType.subjectwise:
        return 'SUBJECT WISE';
    }
  }

  /// Subject-wise tab: shows ALL subjects (not tests of type=subjectwise).
  /// Tapping a subject opens its test list. This makes the tab genuinely
  /// "subject-wise" browsing and ensures it's never empty as long as
  /// subjects exist. The previous implementation filtered tests by
  /// type=='subjectwise' which no test ever had (seed uses mock/practice),
  /// so the tab always showed "No tests available".
  Widget _buildSubjectList(BuildContext context) {
    return StreamBuilder<List<SubjectModel>>(
      stream: FirestoreService.getSubjectsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No subjects available'),
              ],
            ),
          );
        }
        // Sort by name for easy scanning.
        final subjects = List<SubjectModel>.from(snapshot.data!)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    subject.icon ?? '📘',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${subject.testCount} ${subject.testCount == 1 ? 'Test' : 'Tests'}'
                  '${subject.description != null && subject.description!.isNotEmpty ? ' · ${subject.description}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Navigate DIRECTLY to TestListScreen (no intermediate
                      // hub). The old SubjectDetailScreen content hub was
                      // removed — after tapping a subject, users go straight
                      // to its tests. The subject's categoryId is used as the
                      // authoritative category id (may be name/slug in edge
                      // cases — acceptable here since this tab is not the
                      // primary exam-pack purchase entry point).
                      builder: (_) => TestListScreen(
                        subject: subject,
                        categoryId: subject.categoryId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

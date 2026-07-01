// =============================================================================
// ExamVault - Global Search Screen
// Fetches all categories, subjects, tests, and current affairs once via
// FirestoreService, then filters client-side by the query string. Shows
// grouped results with tappable items that navigate to the right screen.
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../models/current_affair_model.dart';
import '../../services/firestore_service.dart';
import '../home/category_detail_screen.dart';
import '../tests/test_list_screen.dart';
import '../tests/take_test_screen.dart';
import '../current_affairs/current_affairs_screen.dart';

/// Bundle of all searchable content, loaded once on screen open.
class _SearchIndex {
  final List<CategoryModel> categories;
  final List<SubjectModel> subjects;
  final List<TestModel> tests;
  final List<CurrentAffairModel> currentAffairs;

  const _SearchIndex({
    this.categories = const [],
    this.subjects = const [],
    this.tests = const [],
    this.currentAffairs = const [],
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Future<_SearchIndex> _indexFuture = _loadIndex();
  String _query = '';

  /// Loads all searchable content in parallel. Each call has its own
  /// try/catch in FirestoreService, so a failure on one collection returns
  /// an empty list instead of breaking the whole search.
  static Future<_SearchIndex> _loadIndex() async {
    final results = await Future.wait([
      FirestoreService.getCategories(),
      FirestoreService.getSubjects(),
      FirestoreService.getTests(isPublished: true),
      FirestoreService.getCurrentAffairs(limit: 100),
    ]);
    return _SearchIndex(
      categories: results[0] as List<CategoryModel>,
      subjects: results[1] as List<SubjectModel>,
      tests: results[2] as List<TestModel>,
      currentAffairs: results[3] as List<CurrentAffairModel>,
    );
  }

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _matches(String? text, String q) {
    if (text == null || text.isEmpty) return false;
    return text.toLowerCase().contains(q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).cardColor,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search categories, subjects, tests...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
              ),
              onChanged: (value) {
                setState(() => _query = value.trim());
              },
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(
            child: FutureBuilder<_SearchIndex>(
              future: _indexFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildMessageState(
                    icon: Icons.cloud_off,
                    message: 'Could not load search data. Try again later.',
                  );
                }
                final index = snapshot.data ?? const _SearchIndex();

                // Empty query → prompt the user to start typing.
                if (_query.isEmpty) {
                  return _buildMessageState(
                    icon: Icons.search,
                    message: 'Start typing to search...',
                  );
                }

                final q = _query.toLowerCase();
                final matchedCategories = index.categories
                    .where((c) =>
                        _matches(c.name, q) || _matches(c.slug, q))
                    .toList();
                final matchedSubjects = index.subjects
                    .where((s) =>
                        _matches(s.name, q) || _matches(s.slug, q))
                    .toList();
                final matchedTests = index.tests
                    .where((t) =>
                        _matches(t.title, q) || _matches(t.slug, q))
                    .toList();
                final matchedAffairs = index.currentAffairs
                    .where((a) =>
                        _matches(a.title, q) ||
                        _matches(a.summary, q) ||
                        _matches(a.category, q))
                    .toList();

                final hasAny = matchedCategories.isNotEmpty ||
                    matchedSubjects.isNotEmpty ||
                    matchedTests.isNotEmpty ||
                    matchedAffairs.isNotEmpty;
                if (!hasAny) {
                  return _buildMessageState(
                    icon: Icons.sentiment_dissatisfied,
                    message: 'No results found for "$_query"',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (matchedCategories.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Categories',
                        icon: Icons.category,
                        count: matchedCategories.length,
                        children: matchedCategories
                            .map((c) => _buildCategoryTile(context, c))
                            .toList(),
                      ),
                    if (matchedSubjects.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Subjects',
                        icon: Icons.menu_book,
                        count: matchedSubjects.length,
                        children: matchedSubjects
                            .map((s) => _buildSubjectTile(context, s))
                            .toList(),
                      ),
                    if (matchedTests.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Tests',
                        icon: Icons.assignment,
                        count: matchedTests.length,
                        children: matchedTests
                            .map((t) => _buildTestTile(context, t))
                            .toList(),
                      ),
                    if (matchedAffairs.isNotEmpty)
                      _buildSection(
                        context,
                        title: 'Current Affairs',
                        icon: Icons.newspaper,
                        count: matchedAffairs.length,
                        children: matchedAffairs
                            .map((a) => _buildAffairTile(context, a))
                            .toList(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int count,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                '$title ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Theme.of(context).cardColor,
          child: Column(children: children),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCategoryTile(BuildContext context, CategoryModel c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppTheme.categoryColors[c.name] ?? AppTheme.primaryColor;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Text(c.icon ?? '📚', style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        c.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: c.description != null && c.description!.isNotEmpty
          ? Text(
              c.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: c),
          ),
        );
      },
    );
  }

  Widget _buildSubjectTile(BuildContext context, SubjectModel s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
        child: Text(s.icon ?? '📘', style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        s.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${s.testCount} Tests',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestListScreen(subject: s)),
        );
      },
    );
  }

  Widget _buildTestTile(BuildContext context, TestModel t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.accentColor.withOpacity(0.12),
        child: const Icon(Icons.assignment, color: AppTheme.accentColor),
      ),
      title: Text(
        t.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${t.duration} min • ${t.totalMarks} marks'
        '${t.isPremium ? ' • Premium' : ''}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: t)),
        );
      },
    );
  }

  Widget _buildAffairTile(BuildContext context, CurrentAffairModel a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.successColor.withOpacity(0.12),
        child: const Icon(Icons.newspaper, color: AppTheme.successColor),
      ),
      title: Text(
        a.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${a.date.day}/${a.date.month}/${a.date.year}'
        '${a.category.isNotEmpty ? ' • ${a.category}' : ''}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()),
        );
      },
    );
  }
}

// =============================================================================
// ExamVault - Global Search Screen
// Subscribes to live Firestore streams for categories, subjects, tests, and
// current affairs, then filters client-side by the query string. Shows
// grouped results with tappable items that navigate to the right screen.
//
// REAL-TIME: because we use streams (not one-shot Futures), admin changes
// (premium toggle, rename, add/remove) reflect here immediately without
// needing to close & reopen the screen.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../models/current_affair_model.dart';
import '../../services/firestore_service.dart';
import '../home/category_detail_screen.dart';
import '../tests/test_list_screen.dart';
import '../tests/test_instructions_screen.dart';
import '../current_affairs/current_affairs_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  // Live data from Firestore streams — updates in real-time when admin
  // toggles premium, renames items, adds/removes content, etc.
  List<CategoryModel> _categories = const [];
  List<SubjectModel> _subjects = const [];
  List<TestModel> _tests = const [];
  List<CurrentAffairModel> _currentAffairs = const [];

  // Track which streams have emitted their first snapshot so we can show a
  // loading spinner only until ALL four are ready.
  bool _categoriesReady = false;
  bool _subjectsReady = false;
  bool _testsReady = false;
  bool _affairsReady = false;

  StreamSubscription? _categoriesSub;
  StreamSubscription? _subjectsSub;
  StreamSubscription? _testsSub;
  StreamSubscription? _affairsSub;

  bool get _isLoading =>
      !(_categoriesReady && _subjectsReady && _testsReady && _affairsReady);

  @override
  void initState() {
    super.initState();
    _initStreams();
    // Auto-focus the search field on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _initStreams() {
    _categoriesSub = FirestoreService.getCategoriesStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _categories = data;
          _categoriesReady = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _categoriesReady = true);
      },
    );
    _subjectsSub = FirestoreService.getSubjectsStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _subjects = data;
          _subjectsReady = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _subjectsReady = true;
        });
      },
    );
    _testsSub = FirestoreService.getTestsStream(isPublished: true).listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _tests = data;
          _testsReady = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _testsReady = true;
        });
      },
    );
    _affairsSub =
        FirestoreService.getCurrentAffairsStream(limit: 100).listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _currentAffairs = data;
          _affairsReady = true;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _affairsReady = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _subjectsSub?.cancel();
    _testsSub?.cancel();
    _affairsSub?.cancel();
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
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  /// Builds the results area from the live stream state. Re-runs the
  /// client-side filter on every stream update AND every query keystroke.
  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Empty query → prompt the user to start typing.
    if (_query.isEmpty) {
      return _buildMessageState(
        icon: Icons.search,
        message: 'Start typing to search...',
      );
    }

    final q = _query.toLowerCase();
    final matchedCategories = _categories
        .where((c) => _matches(c.name, q) || _matches(c.slug, q))
        .toList();
    final matchedSubjects = _subjects
        .where((s) => _matches(s.name, q) || _matches(s.slug, q))
        .toList();
    final matchedTests = _tests
        .where((t) => _matches(t.title, q) || _matches(t.slug, q))
        .toList();
    final matchedAffairs = _currentAffairs
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
          MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: t)),
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

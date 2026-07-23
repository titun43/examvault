// =============================================================================
// ExamVault - All Subjects Screen
// Shows every subject in a searchable grid. Tapping a subject opens its test
// list. This is the destination for the "Popular Subjects > View All" button
// on the home screen (previously it wrongly opened the Upcoming Exams screen).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../models/subject_model.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/category_preference_service.dart';
import '../../utils/localized_content.dart';
import 'subject_detail_screen.dart';

class AllSubjectsScreen extends StatefulWidget {
  const AllSubjectsScreen({super.key});

  @override
  State<AllSubjectsScreen> createState() => _AllSubjectsScreenState();
}

class _AllSubjectsScreenState extends State<AllSubjectsScreen> {
  List<SubjectModel> _allSubjects = const [];
  List<CategoryModel> _categories = [];
  List<SubjectModel> _filtered = [];
  bool _subjectsReady = false;
  bool _categoriesReady = false;
  String _query = '';
  String? _selectedCategoryId;
  // Categories the user picked during onboarding/Profile > My Categories.
  // When set (and the user hasn't tapped a specific chip or "All"), the grid
  // defaults to just these — fixes "View All" showing every category's
  // subjects instead of the ones the user actually selected.
  List<String> _preferredCategoryIds = [];
  bool _explicitAll = false;

  StreamSubscription? _subjectsSub;
  StreamSubscription? _categoriesSub;

  bool get _isLoading => !(_subjectsReady && _categoriesReady);

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadPreferredCategoryIds();
  }

  Future<void> _loadPreferredCategoryIds() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ids = await CategoryPreferenceService.getSelectedCategoryIds(auth.user);
    if (!mounted) return;
    setState(() {
      _preferredCategoryIds = ids;
      _applyFilter();
    });
  }

  void _initStreams() {
    // LIVE streams: admin changes (add/rename/remove subjects & categories,
    // change testCount) reflect here immediately without pull-to-refresh.
    _subjectsSub = FirestoreService.getSubjectsStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _allSubjects = data;
          _subjectsReady = true;
          _applyFilter();
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _subjectsReady = true;
          _applyFilter();
        });
      },
    );
    _categoriesSub = FirestoreService.getCategoriesStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _categories = data;
          _categoriesReady = true;
          _applyFilter();
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _categoriesReady = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _subjectsSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }

  void _applyFilter() {
    var list = _allSubjects;
    if (_selectedCategoryId != null) {
      // Match by category id, name, or slug (same robust matching as
      // FirestoreService.getSubjects).
      final cat = _categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => CategoryModel(
          id: '',
          name: '',
          slug: '',
          icon: '📚',
          order: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final candidates = <String>{
        _selectedCategoryId!,
        if (cat.name.isNotEmpty) cat.name,
        if (cat.slug.isNotEmpty) cat.slug,
      };
      list = list
          .where((s) =>
              candidates.contains(s.categoryId) ||
              candidates.any((c) => s.categoryId == c))
          .toList();
    } else if (!_explicitAll && _preferredCategoryIds.isNotEmpty) {
      // No manual chip tap yet — default to the user's onboarding selection.
      final candidates = <String>{};
      for (final id in _preferredCategoryIds) {
        candidates.add(id);
        final cat = _categories.firstWhere(
          (c) => c.id == id,
          orElse: () => CategoryModel.empty(),
        );
        if (cat.name.isNotEmpty) candidates.add(cat.name);
        if (cat.slug.isNotEmpty) candidates.add(cat.slug);
      }
      final preferredMatches =
          list.where((s) => candidates.contains(s.categoryId)).toList();
      // Safety fallback: if nothing matches (e.g. stale ids), don't show an
      // empty grid — fall back to everything.
      if (preferredMatches.isNotEmpty) list = preferredMatches;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              (s.description ?? '').toLowerCase().contains(q))
          .toList();
    }
    _filtered = list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Subjects'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + category filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search subjects...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _query = '';
                                _applyFilter();
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v.trim();
                      _applyFilter();
                    });
                  },
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip(null, 'All'),
                        ..._categories.map((c) => _buildCategoryChip(c.id, lc(context, c.name, c.nameAs))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Subjects grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) =>
                            _buildSubjectCard(_filtered[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? id, String label) {
    // "All" chip appears selected either when the user explicitly tapped it,
    // or (default state) when there's no onboarding preference to fall back
    // to — so it doesn't look selected while a preferred-category filter is
    // silently active.
    final selected = id == null
        ? (_selectedCategoryId == null &&
            (_explicitAll || _preferredCategoryIds.isEmpty))
        : _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (id == null) {
              _selectedCategoryId = null;
              _explicitAll = true;
            } else {
              _selectedCategoryId = _selectedCategoryId == id ? null : id;
              _explicitAll = _selectedCategoryId == null;
            }
            _applyFilter();
          });
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    // Localized display strings (computed once to avoid repeated Provider
    // lookups inside this build).
    final localizedName = lc(context, subject.name, subject.nameAs);
    final localizedDescription =
        lc(context, subject.description ?? '', subject.descriptionAs);
    // FIXED: resolve the authoritative Firestore category id from the loaded
    // _categories list. subject.categoryId may hold a slug/name due to
    // getSubjectsStream fallback matching — using that slug as categoryId
    // would silently fail the exam-pack tier in /api/payments/access-check
    // because ExamPackPurchase always stores the real Firestore category id.
    final matchedCategory = _categories.firstWhere(
      (c) =>
          c.id == subject.categoryId ||
          c.name == subject.categoryId ||
          c.slug == subject.categoryId,
      orElse: () => CategoryModel.empty(),
    );
    final authCategoryId = matchedCategory.id.isNotEmpty
        ? matchedCategory.id
        : subject.categoryId;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // Issue #24: navigate to SubjectDetailScreen (content hub)
            // instead of TestListScreen, so users can access Previous Papers,
            // Study Notes, and Syllabus in addition to Tests. Pass the
            // resolved authoritative categoryId + matched category name so
            // the hero gradient and exam-pack access check work correctly.
            builder: (_) => SubjectDetailScreen(
              subject: subject,
              categoryId: authCategoryId,
              categoryName: matchedCategory.id.isNotEmpty
                  ? matchedCategory.name
                  : null,
              categoryNameAs: matchedCategory.id.isNotEmpty
                  ? matchedCategory.nameAs
                  : null,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subject.icon ?? '📚',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subject.testCount} Tests',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subject.description != null &&
                    subject.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    localizedDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty
                  ? 'No subjects available yet'
                  : 'No subjects match "$_query"',
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
}

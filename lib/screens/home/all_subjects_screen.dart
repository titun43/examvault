// =============================================================================
// ExamVault - All Subjects Screen
// Shows every subject in a searchable grid. Tapping a subject opens its test
// list. This is the destination for the "Popular Subjects > View All" button
// on the home screen (previously it wrongly opened the Upcoming Exams screen).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/subject_model.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../tests/test_list_screen.dart';

class AllSubjectsScreen extends StatefulWidget {
  const AllSubjectsScreen({super.key});

  @override
  State<AllSubjectsScreen> createState() => _AllSubjectsScreenState();
}

class _AllSubjectsScreenState extends State<AllSubjectsScreen> {
  List<SubjectModel> _allSubjects = [];
  List<CategoryModel> _categories = [];
  List<SubjectModel> _filtered = [];
  bool _isLoading = true;
  String _query = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        FirestoreService.getSubjects(),
        FirestoreService.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _allSubjects = results[0] as List<SubjectModel>;
        _categories = results[1] as List<CategoryModel>;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
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
                        ..._categories.map((c) => _buildCategoryChip(c.id, c.name)),
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
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = selected ? null : id;
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestListScreen(subject: subject)),
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
                    color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.2),
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
                  subject.name,
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
                    subject.description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
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
                color: Colors.white.withOpacity(0.25),
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

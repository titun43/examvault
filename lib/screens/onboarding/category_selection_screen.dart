// =============================================================================
// ExamVault - Category Selection Screen
// =============================================================================
// Shown once on first app open (right after splash) so the user can pick the
// exam categories they're preparing for (SSC, Banking, Railway, etc.).
// Multi-select — a user can pick as many as they want. Home screen then
// filters its category grid down to this selection.
//
// Also reusable later from Profile > "My Categories" to edit the selection
// (pass isOnboarding: false), in which case it pops with `true` if the
// selection changed so the caller can refresh.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../services/category_preference_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../home/main_navigation.dart';

class CategorySelectionScreen extends StatefulWidget {
  /// True when this is the first-run flow (splash -> picker -> MainNavigation).
  /// False when opened later from Profile to edit an existing selection.
  final bool isOnboarding;

  const CategorySelectionScreen({super.key, this.isOnboarding = true});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  List<CategoryModel> _categories = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final results = await Future.wait([
      FirestoreService.getCategories(),
      CategoryPreferenceService.getSelectedCategoryIds(auth.user),
    ]);
    if (!mounted) return;
    final cats = results[0] as List<CategoryModel>;
    final existing = results[1] as List<String>;
    setState(() {
      _categories = cats;
      _selected.addAll(existing);
      _loading = false;
    });
  }

  Future<void> _save({required bool skip}) async {
    setState(() => _saving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      // "Skip" saves an empty selection, which the Home screen treats as
      // "show everything" — same as never having filtered at all.
      await CategoryPreferenceService.saveSelectedCategoryIds(
        skip ? const [] : _selected.toList(),
        user: auth.user,
      );
    } catch (_) {
      // Non-fatal — worst case the picker shows again next launch.
    }
    if (!mounted) return;
    if (widget.isOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              title: Text(
                'My Categories',
                style: AppFonts.style(size: 18, weight: FontWeight.w700),
              ),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceXl, AppTheme.spaceLg, AppTheme.spaceXl, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isOnboarding)
                          Text(
                            'Welcome to ExamVault!',
                            style: AppFonts.style(
                              size: 24,
                              weight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'Which exams are you preparing for? Pick as many as you like — your Home screen will focus on these.',
                          style: AppFonts.style(
                            size: 14,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: AppTheme.spaceLg),
                  Expanded(
                    child: _categories.isEmpty
                        ? Center(
                            child: Text(
                              'No categories available yet.',
                              style: AppFonts.style(
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceXl),
                            child: Wrap(
                              spacing: AppTheme.spaceSm,
                              runSpacing: AppTheme.spaceSm,
                              children: _categories.map((category) {
                                final isSelected =
                                    _selected.contains(category.id);
                                final color =
                                    AppTheme.colorFor(category.name);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selected.remove(category.id);
                                      } else {
                                        _selected.add(category.id);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spaceLg,
                                      vertical: AppTheme.spaceSm + 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withOpacity(isDark ? 0.28 : 0.14)
                                          : (isDark
                                              ? AppTheme.darkSurfaceColor
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull),
                                      border: Border.all(
                                        color: isSelected
                                            ? color
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.15),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(category.icon ?? '📚',
                                            style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: AppTheme.spaceSm),
                                        Text(
                                          category.name,
                                          style: AppFonts.style(
                                            size: 14,
                                            weight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? color
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: AppTheme.spaceXs),
                                          Icon(Icons.check_circle,
                                              size: 16, color: color),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceXl),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            onPressed: (_saving || _selected.isEmpty)
                                ? null
                                : () => _save(skip: false),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    widget.isOnboarding
                                        ? 'Continue (${_selected.length} selected)'
                                        : 'Save',
                                    style: AppFonts.style(
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                        if (widget.isOnboarding) ...[
                          const SizedBox(height: AppTheme.spaceSm),
                          TextButton(
                            onPressed: _saving ? null : () => _save(skip: true),
                            child: Text(
                              'Skip for now',
                              style: AppFonts.style(
                                size: 14,
                                weight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

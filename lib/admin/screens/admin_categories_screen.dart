// =============================================================================
// ExamVault - Admin Categories CRUD Screen
// =============================================================================
// Includes:
//  - Premium toggle + premiumPrice + premiumDurationMonths in the Add/Edit
//    dialog (so the admin can mark a category as premium from THIS app, not
//    only from the web admin).
//  - Premium propagation: when a category's isPremium flag changes, every test
//    inside that category (resolved through subjects) is updated to match.
//    This is THE fix for "category premium but inner tests accessible".
//  - "Re-sync premium" button in the AppBar: re-runs propagation for ALL
//    categories in one tap — repairs legacy tests that were left
//    isPremium=false by the old buggy propagation.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  bool _resyncing = false;

  Future<void> _showResyncConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.refresh, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Re-sync premium flags?')),
          ],
        ),
        content: const Text(
          'This re-marks every test inside premium categories as premium, '
          'and every test inside free categories as free. Use this to repair '
          'tests that were left unlocked by a previous bug.\n\n'
          'This may take a few seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Re-sync all'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _resyncing = true);
    try {
      final total = await FirestoreService.resyncAllCategoriesPremium();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            total > 0
                ? 'Re-synced $total test${total == 1 ? '' : 's'} across all categories.'
                : 'No tests needed updating.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        automaticallyImplyLeading: false,
        actions: [
          // Re-sync premium — repairs legacy broken data in one tap.
          IconButton(
            icon: _resyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Re-sync premium flags',
            onPressed: _resyncing ? null : _showResyncConfirm,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: FirestoreService.getCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No categories. Add one!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final category = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (AppTheme.categoryColors[category.name] ??
                            AppTheme.primaryColor)
                        .withOpacity(0.1),
                    child: Text(category.icon ?? '📚',
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(category.name)),
                      if (category.isPremium) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.accentColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            category.premiumPrice > 0
                                ? 'PREMIUM ₹${category.premiumPrice}'
                                : 'PREMIUM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('${category.subjectCount} subjects'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditDialog(context, category: category);
                      } else if (value == 'delete') {
                        _confirmDelete(context, category);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {CategoryModel? category}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditCategoryDialog(category: category),
    );
  }

  void _confirmDelete(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text(
              'Are you sure you want to delete "${category.name}"? This will also delete all subjects and tests under it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                try {
                  // Unlock tests inside this category before deleting, so
                  // they don't stay locked forever after the category (and
                  // its subjects) are gone.
                  await FirestoreService.propagateCategoryPremiumToTests(
                      category.id, false);
                  await FirestoreService.deleteCategory(category.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category deleted')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Add/Edit Category dialog — with premium fields + propagation on save.
// =============================================================================
class _AddEditCategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  const _AddEditCategoryDialog({this.category});

  @override
  State<_AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<_AddEditCategoryDialog> {
  final _nameCtrl = TextEditingController();
  final _iconCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  bool _isPremium = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameCtrl.text = c.name;
      _iconCtrl.text = c.icon ?? '📚';
      _descCtrl.text = c.description ?? '';
      _orderCtrl.text = c.order.toString();
      _priceCtrl.text = c.premiumPrice > 0 ? c.premiumPrice.toString() : '';
      _durationCtrl.text = c.premiumDurationMonths > 0
          ? c.premiumDurationMonths.toString()
          : '';
      _isPremium = c.isPremium;
    } else {
      _iconCtrl.text = '📚';
      _orderCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    _orderCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'Railway, SSC, etc.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iconCtrl,
              decoration: const InputDecoration(
                  labelText: 'Icon (emoji)', hintText: '🚂'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orderCtrl,
              decoration: const InputDecoration(labelText: 'Order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Premium category'),
              subtitle: const Text(
                  'Locks all tests inside this category behind a purchase.'),
              value: _isPremium,
              onChanged: (v) => setState(() => _isPremium = v),
            ),
            if (_isPremium) ...[
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Premium price (₹)',
                  hintText: '99',
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (months)',
                  hintText: '12',
                  suffixText: 'months',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final wasPremium = widget.category?.isPremium ?? false;
    final newCategory = CategoryModel(
      id: widget.category?.id ?? '',
      name: name,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      icon: _iconCtrl.text.trim().isEmpty ? null : _iconCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      order: int.tryParse(_orderCtrl.text) ?? 0,
      subjectCount: widget.category?.subjectCount ?? 0,
      isPremium: _isPremium,
      premiumPrice: int.tryParse(_priceCtrl.text) ?? 0,
      premiumDurationMonths: int.tryParse(_durationCtrl.text) ?? 0,
      createdAt: widget.category?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      String categoryId;
      if (widget.category == null) {
        categoryId =
            await FirestoreService.addCategory(newCategory) ?? '';
      } else {
        await FirestoreService.updateCategory(newCategory);
        categoryId = newCategory.id;
      }

      // Propagate premium flag to all tests inside this category.
      // Only propagate if we have an id AND the flag actually changed
      // (or it's a new premium category). This avoids unnecessary writes
      // but still catches the case where the admin toggles premium on.
      int? propagated;
      if (categoryId.isNotEmpty &&
          (wasPremium != _isPremium || _isPremium)) {
        try {
          propagated = await FirestoreService.propagateCategoryPremiumToTests(
            categoryId,
            _isPremium,
          );
        } catch (e) {
          print('propagate on save error: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            propagated != null && propagated > 0
                ? '${widget.category == null ? "Category added" : "Category saved"}. '
                    '$propagate test${propagated == 1 ? "" : "s"} '
                    '${_isPremium ? "locked" : "unlocked"}.'
                : widget.category == null
                    ? 'Category added'
                    : 'Category saved',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

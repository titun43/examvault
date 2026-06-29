// =============================================================================
// ExamVault - Admin Categories CRUD Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  late List<LocalCategory> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = LocalDataService.getCategories();
  }

  Color _parseColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No categories. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final c = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _parseColor(c.color).withOpacity(0.15),
                      child: const Icon(Icons.category, size: 20),
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                        '${c.testCount} tests • ${c.description.isEmpty ? "—" : c.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddEditDialog(context, category: c);
                        } else if (value == 'delete') {
                          _confirmDelete(context, c);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddEditDialog(BuildContext context, {LocalCategory? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? 'school');
    final colorController =
        TextEditingController(text: category?.color ?? '#1565C0');
    final descController =
        TextEditingController(text: category?.description ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Name', hintText: 'Railway, SSC, etc.'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(
                      labelText: 'Icon (Material name)',
                      hintText: 'school, train, work...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                      labelText: 'Color (hex)', hintText: '#1565C0'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newCat = LocalCategory(
                  id: category?.id ?? '',
                  name: nameController.text.trim(),
                  icon: iconController.text.trim().isEmpty
                      ? 'school'
                      : iconController.text.trim(),
                  color: colorController.text.trim().isEmpty
                      ? '#1565C0'
                      : colorController.text.trim(),
                  description: descController.text.trim(),
                  testCount: category?.testCount ?? 0,
                );
                if (category == null) {
                  await LocalDataService.addCategory(newCat);
                } else {
                  await LocalDataService.updateCategory(newCat);
                }
                if (!mounted) return;
                Navigator.pop(context);
                setState(_reload);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, LocalCategory category) {
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
                await LocalDataService.deleteCategory(category.id);
                if (!mounted) return;
                Navigator.pop(context);
                setState(_reload);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

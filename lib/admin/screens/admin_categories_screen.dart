// =============================================================================
// ExamVault - Admin Categories CRUD Screen
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';

class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

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
                    backgroundColor: (AppTheme.categoryColors[category.name] ?? AppTheme.primaryColor).withOpacity(0.1),
                    child: Text(category.icon ?? '📚', style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(category.name),
                  subtitle: Text('${category.subjectCount} subjects'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    final nameController = TextEditingController(text: category?.name ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '📚');
    final descController = TextEditingController(text: category?.description ?? '');
    final orderController = TextEditingController(text: (category?.order ?? 0).toString());

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
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'Railway, SSC, etc.'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(labelText: 'Icon (emoji)', hintText: '🚂'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderController,
                  decoration: const InputDecoration(labelText: 'Order'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final newCategory = CategoryModel(
                  id: category?.id ?? '',
                  name: nameController.text,
                  slug: nameController.text.toLowerCase().replaceAll(' ', '-'),
                  icon: iconController.text,
                  description: descController.text,
                  order: int.tryParse(orderController.text) ?? 0,
                  createdAt: category?.createdAt ?? now,
                  updatedAt: now,
                );
                if (category == null) {
                  await FirestoreService.addCategory(newCategory);
                } else {
                  await FirestoreService.updateCategory(newCategory);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text('Are you sure you want to delete "${category.name}"? This will also delete all subjects and tests under it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                await FirestoreService.deleteCategory(category.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

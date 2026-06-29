// =============================================================================
// ExamVault - Admin Tests CRUD Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminTestsScreen extends StatefulWidget {
  const AdminTestsScreen({super.key});

  @override
  State<AdminTestsScreen> createState() => _AdminTestsScreenState();
}

class _AdminTestsScreenState extends State<AdminTestsScreen> {
  late List<LocalTest> _items;
  late List<LocalCategory> _categories;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = LocalDataService.getTests();
    _categories = LocalDataService.getCategories();
  }

  String _categoryName(String id) {
    final i = _categories.indexWhere((c) => c.id == id);
    return i >= 0 ? _categories[i].name : '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No tests. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final t = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title),
                    subtitle: Text(
                        '${_categoryName(t.categoryId)} • ${t.totalQuestions} Qs • ${t.durationMinutes} min • ${t.totalMarks} marks • ${t.isFree ? "Free" : "Premium"}'),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) async {
                        if (value == 'delete') {
                          await LocalDataService.deleteTest(t.id);
                          setState(_reload);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddEditDialog(BuildContext context) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one category first.')),
      );
      return;
    }
    String? selectedCategoryId = _categories.first.id;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final durationController =
        TextEditingController(text: '30');
    final totalQsController = TextEditingController(text: '20');
    final marksController = TextEditingController(text: '20');
    bool isFree = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSt) {
          return AlertDialog(
            title: const Text('Add Test'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setSt(() => selectedCategoryId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                        labelText: 'Duration (minutes)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalQsController,
                    decoration: const InputDecoration(
                        labelText: 'Total Questions'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: marksController,
                    decoration:
                        const InputDecoration(labelText: 'Total Marks'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isFree,
                    title: const Text('Free Test'),
                    onChanged: (v) => setSt(() => isFree = v),
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
                  if (titleController.text.trim().isEmpty ||
                      selectedCategoryId == null) {
                    return;
                  }
                  await LocalDataService.addTest(LocalTest(
                    id: '',
                    categoryId: selectedCategoryId!,
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    durationMinutes:
                        int.tryParse(durationController.text) ?? 30,
                    totalQuestions:
                        int.tryParse(totalQsController.text) ?? 20,
                    totalMarks: int.tryParse(marksController.text) ?? 20,
                    isFree: isFree,
                    isActive: true,
                  ));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(_reload);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }
}

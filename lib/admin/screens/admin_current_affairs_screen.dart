// =============================================================================
// ExamVault - Admin Current Affairs Screen (offline CRUD)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminCurrentAffairsScreen extends StatefulWidget {
  const AdminCurrentAffairsScreen({super.key});

  @override
  State<AdminCurrentAffairsScreen> createState() =>
      _AdminCurrentAffairsScreenState();
}

class _AdminCurrentAffairsScreenState extends State<AdminCurrentAffairsScreen> {
  late List<LocalCurrentAffair> _items;

  @override
  void initState() {
    super.initState();
    _items = LocalDataService.getCurrentAffairs();
  }

  void _reload() {
    setState(() {
      _items = LocalDataService.getCurrentAffairs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Affairs'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No current affairs. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final c = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text(
                        '${c.category} • ${c.date.day}/${c.date.month}/${c.date.year}\n${c.summary}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.errorColor),
                      onPressed: () async {
                        await LocalDataService.deleteCurrentAffair(c.id);
                        _reload();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Current Affair'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'National, Sports, Tech...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: 'Summary'),
                  maxLines: 4,
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
                if (titleController.text.trim().isEmpty) return;
                await LocalDataService.addCurrentAffair(LocalCurrentAffair(
                  id: '',
                  title: titleController.text.trim(),
                  summary: summaryController.text.trim(),
                  category: categoryController.text.trim().isEmpty
                      ? 'General'
                      : categoryController.text.trim(),
                  date: DateTime.now(),
                ));
                if (!context.mounted) return;
                Navigator.pop(context);
                _reload();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

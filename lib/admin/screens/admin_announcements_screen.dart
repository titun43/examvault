// =============================================================================
// ExamVault - Admin Announcements Screen (offline CRUD)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  late List<LocalAnnouncement> _items;

  @override
  void initState() {
    super.initState();
    _items = LocalDataService.getAnnouncements();
  }

  void _reload() {
    setState(() {
      _items = LocalDataService.getAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No announcements. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final a = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Text(
                        '${a.body}\n${a.date.day}/${a.date.month}/${a.date.year}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.errorColor),
                      onPressed: () async {
                        await LocalDataService.deleteAnnouncement(a.id);
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
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Announcement'),
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
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body'),
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
                await LocalDataService.addAnnouncement(LocalAnnouncement(
                  id: '',
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
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

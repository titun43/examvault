// =============================================================================
// ExamVault - Admin Upcoming Exams Screen (offline CRUD)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminUpcomingExamsScreen extends StatefulWidget {
  const AdminUpcomingExamsScreen({super.key});

  @override
  State<AdminUpcomingExamsScreen> createState() =>
      _AdminUpcomingExamsScreenState();
}

class _AdminUpcomingExamsScreenState extends State<AdminUpcomingExamsScreen> {
  late List<LocalUpcomingExam> _items;

  @override
  void initState() {
    super.initState();
    _items = LocalDataService.getUpcomingExams();
  }

  void _reload() {
    setState(() {
      _items = LocalDataService.getUpcomingExams();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No upcoming exams. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final e = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.name),
                    subtitle: Text(
                        '${e.organization}\n${e.examDate.day}/${e.examDate.month}/${e.examDate.year} • ${e.status}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.errorColor),
                      onPressed: () async {
                        await LocalDataService.deleteUpcomingExam(e.id);
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
    final nameController = TextEditingController();
    final orgController = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSt) {
          return AlertDialog(
            title: const Text('Add Upcoming Exam'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Exam Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orgController,
                    decoration: const InputDecoration(
                        labelText: 'Organization'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${selected.day}/${selected.month}/${selected.year}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selected,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (d != null) {
                            setSt(() => selected = d);
                          }
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
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
                  if (nameController.text.trim().isEmpty) return;
                  await LocalDataService.addUpcomingExam(LocalUpcomingExam(
                    id: '',
                    name: nameController.text.trim(),
                    organization: orgController.text.trim().isEmpty
                        ? '—'
                        : orgController.text.trim(),
                    examDate: selected,
                    status: 'upcoming',
                  ));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _reload();
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

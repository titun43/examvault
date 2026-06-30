// =============================================================================
// ExamVault - Admin Upcoming Exams CRUD Screen
// Admin adds upcoming exams (RRB, SSC, UPSC etc.) → users see countdown + apply link
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/upcoming_exam_model.dart';
import '../../services/firestore_service.dart';

class AdminUpcomingExamsScreen extends StatelessWidget {
  const AdminUpcomingExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<UpcomingExamModel>>(
        stream: FirestoreService.getAllUpcomingExamsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No upcoming exams yet.\nTap + to add one.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final e = snapshot.data![index];
              final days = e.daysRemaining;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (days < 0
                        ? Colors.grey
                        : days < 30
                            ? Colors.red
                            : days < 90
                                ? Colors.orange
                                : AppTheme.primaryColor).withOpacity(0.15),
                    child: Icon(Icons.event, color: days < 0 ? Colors.grey : AppTheme.primaryColor),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(e.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (!e.isPublished)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Draft', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.organization != null && e.organization!.isNotEmpty)
                        Text(e.organization!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(
                        'Exam: ${_fmtDate(e.examDate)} • ${days < 0 ? '${-days}d ago' : 'in $days days'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: days < 0 ? Colors.grey : AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'publish', child: Text('Toggle Publish')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showAddEditDialog(context, exam: e);
                      } else if (value == 'publish') {
                        await FirestoreService.updateUpcomingExam(UpcomingExamModel(
                          id: e.id,
                          name: e.name,
                          organization: e.organization,
                          categoryId: e.categoryId,
                          examDate: e.examDate,
                          applicationStartDate: e.applicationStartDate,
                          applicationEndDate: e.applicationEndDate,
                          notificationUrl: e.notificationUrl,
                          syllabusUrl: e.syllabusUrl,
                          imageUrl: e.imageUrl,
                          description: e.description,
                          tags: e.tags,
                          isPublished: !e.isPublished,
                          order: e.order,
                          createdAt: e.createdAt,
                          updatedAt: DateTime.now(),
                        ));
                      } else if (value == 'delete') {
                        _confirmDelete(context, e);
                      }
                    },
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showAddEditDialog(BuildContext context, {UpcomingExamModel? exam}) {
    final nameCtrl = TextEditingController(text: exam?.name ?? '');
    final orgCtrl = TextEditingController(text: exam?.organization ?? '');
    final notifUrlCtrl = TextEditingController(text: exam?.notificationUrl ?? '');
    final syllabusUrlCtrl = TextEditingController(text: exam?.syllabusUrl ?? '');
    final descCtrl = TextEditingController(text: exam?.description ?? '');
    final tagsCtrl = TextEditingController(text: exam?.tags.join(', ') ?? '');
    final orderCtrl = TextEditingController(text: (exam?.order ?? 0).toString());

    DateTime examDate = exam?.examDate ?? DateTime.now().add(const Duration(days: 30));
    DateTime? appStart = exam?.applicationStartDate;
    DateTime? appEnd = exam?.applicationEndDate;
    bool isPublished = exam?.isPublished ?? true;

    Future<void> pickDate(BuildContext ctx, DateTime initial, ValueChanged<DateTime> onPicked) async {
      final d = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (d != null) onPicked(d);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(exam == null ? 'Add Upcoming Exam' : 'Edit Upcoming Exam'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Exam Name *', hintText: 'RRB NTPC 2026'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orgCtrl,
                    decoration: const InputDecoration(labelText: 'Organization', hintText: 'RRB / SSC / UPSC'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exam Date *'),
                    subtitle: Text(_fmtDate(examDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => pickDate(context, examDate, (d) => setState(() => examDate = d)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Application Start'),
                    subtitle: Text(appStart == null ? 'Not set' : _fmtDate(appStart!)),
                    trailing: appStart == null
                        ? const Icon(Icons.add_circle_outline)
                        : const Icon(Icons.edit),
                    onTap: () => pickDate(
                      context,
                      appStart ?? DateTime.now(),
                      (d) => setState(() => appStart = d),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Application End'),
                    subtitle: Text(appEnd == null ? 'Not set' : _fmtDate(appEnd!)),
                    trailing: appEnd == null
                        ? const Icon(Icons.add_circle_outline)
                        : const Icon(Icons.edit),
                    onTap: () => pickDate(
                      context,
                      appEnd ?? DateTime.now().add(const Duration(days: 30)),
                      (d) => setState(() => appEnd = d),
                    ),
                  ),
                  TextField(
                    controller: notifUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Notification URL (PDF link)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: syllabusUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Syllabus URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma-separated)',
                      hintText: 'govt, railway, graduate',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(labelText: 'Order (lower = first)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Published'),
                    value: isPublished,
                    onChanged: (v) => setState(() => isPublished = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exam name is required')),
                    );
                    return;
                  }
                  final now = DateTime.now();
                  final model = UpcomingExamModel(
                    id: exam?.id ?? '',
                    name: nameCtrl.text.trim(),
                    organization: orgCtrl.text.trim().isEmpty ? null : orgCtrl.text.trim(),
                    categoryId: exam?.categoryId,
                    examDate: examDate,
                    applicationStartDate: appStart,
                    applicationEndDate: appEnd,
                    notificationUrl: notifUrlCtrl.text.trim().isEmpty ? null : notifUrlCtrl.text.trim(),
                    syllabusUrl: syllabusUrlCtrl.text.trim().isEmpty ? null : syllabusUrlCtrl.text.trim(),
                    imageUrl: exam?.imageUrl,
                    description: descCtrl.text.trim(),
                    tags: tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList(),
                    isPublished: isPublished,
                    order: int.tryParse(orderCtrl.text) ?? 0,
                    createdAt: exam?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (exam == null) {
                    await FirestoreService.addUpcomingExam(model);
                  } else {
                    await FirestoreService.updateUpcomingExam(model);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, UpcomingExamModel e) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Exam?'),
          content: Text('Are you sure you want to delete "${e.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                await FirestoreService.deleteUpcomingExam(e.id);
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

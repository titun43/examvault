// =============================================================================
// ExamVault - Admin Previous Papers Screen
// Lists tests where type=previousYear. Admin can add/edit/delete directly.
// "Previous papers" are just Tests tagged with type=previousYear — so they
// automatically appear in the user's Previous Papers section.
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';

class AdminPreviousPapersScreen extends StatelessWidget {
  const AdminPreviousPapersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Papers'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getPreviousPapersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 56, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500),
                    const SizedBox(height: 12),
                    const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No previous papers yet.\nTap + to add one (e.g. "SSC CGL 2023").',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final t = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                    child: Text(
                      t.year != null ? "'${(t.year! % 100).toString().padLeft(2, '0')}" : 'PP',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${t.questionCount} Qs • ${t.duration} min • ${t.totalMarks} marks'
                    '${t.isPremium ? ' • Premium' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditDialog(context, test: t);
                      } else if (value == 'delete') {
                        _confirmDelete(context, t);
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

  void _showAddEditDialog(BuildContext context, {TestModel? test}) {
    final titleCtrl = TextEditingController(text: test?.title ?? '');
    final yearCtrl = TextEditingController(text: test?.year?.toString() ?? DateTime.now().year.toString());
    final durationCtrl = TextEditingController(text: (test?.duration ?? 60).toString());
    final totalMarksCtrl = TextEditingController(text: (test?.totalMarks ?? 100).toString());
    final passingMarksCtrl = TextEditingController(text: (test?.passingMarks ?? 40).toString());
    final instructionsCtrl = TextEditingController(text: test?.instructions ?? '');
    String? selectedSubjectId = test?.subjectId;
    bool isPremium = test?.isPremium ?? false;
    TestDifficulty difficulty = test?.difficulty ?? TestDifficulty.medium;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(test == null ? 'Add Previous Paper' : 'Edit Previous Paper'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'SSC CGL 2023 Tier 1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<SubjectModel>>(
                    stream: FirestoreService.getSubjectsStream(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Failed to load subjects. Please retry.',
                              style: TextStyle(color: Colors.red, fontSize: 12)),
                        );
                      }
                      final subjects = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject *'),
                        items: subjects
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => selectedSubjectId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yearCtrl,
                    decoration: const InputDecoration(labelText: 'Year *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationCtrl,
                          decoration: const InputDecoration(labelText: 'Duration (min)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<TestDifficulty>(
                          value: difficulty,
                          decoration: const InputDecoration(labelText: 'Difficulty'),
                          items: const [
                            DropdownMenuItem(value: TestDifficulty.easy, child: Text('Easy')),
                            DropdownMenuItem(value: TestDifficulty.medium, child: Text('Medium')),
                            DropdownMenuItem(value: TestDifficulty.hard, child: Text('Hard')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => difficulty = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: totalMarksCtrl,
                          decoration: const InputDecoration(labelText: 'Total Marks'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passingMarksCtrl,
                          decoration: const InputDecoration(labelText: 'Passing Marks'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsCtrl,
                    decoration: const InputDecoration(labelText: 'Instructions (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Premium only'),
                    value: isPremium,
                    onChanged: (v) => setState(() => isPremium = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title is required')),
                    );
                    return;
                  }
                  if (selectedSubjectId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a subject')),
                    );
                    return;
                  }
                  final now = DateTime.now();
                  final model = TestModel(
                    id: test?.id ?? '',
                    subjectId: selectedSubjectId!,
                    title: titleCtrl.text.trim(),
                    slug: titleCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
                    type: TestType.previousYear, // ← always previousYear here
                    duration: int.tryParse(durationCtrl.text) ?? 60,
                    totalMarks: int.tryParse(totalMarksCtrl.text) ?? 100,
                    passingMarks: int.tryParse(passingMarksCtrl.text) ?? 40,
                    isPublished: test?.isPublished ?? true,
                    difficulty: difficulty,
                    negativeMarking: test?.negativeMarking ?? false,
                    negativeMarks: test?.negativeMarks ?? 0.25,
                    instructions: instructionsCtrl.text.trim().isEmpty
                        ? null
                        : instructionsCtrl.text.trim(),
                    year: int.tryParse(yearCtrl.text),
                    examSession: test?.examSession,
                    isPremium: isPremium,
                    questionCount: test?.questionCount ?? 0,
                    attemptCount: test?.attemptCount ?? 0,
                    createdAt: test?.createdAt ?? now,
                    updatedAt: now,
                  );
                  try {
                    if (test == null) {
                      await FirestoreService.addTest(model);
                    } else {
                      await FirestoreService.updateTest(model);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(test == null ? 'Previous paper added' : 'Previous paper updated')),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Save failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, TestModel t) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Previous Paper?'),
          content: Text('Are you sure you want to delete "${t.title}"? This also deletes its questions.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                try {
                  await FirestoreService.deleteTest(t.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Previous paper deleted')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
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

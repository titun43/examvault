// =============================================================================
// ExamVault - Admin Tests CRUD Screen (full Add/Edit/Delete form)
// The Type dropdown is the KEY field for managing Daily Quizzes — admin
// selects "Daily Quiz" when creating a test to make it appear in the user
// app's Daily Quiz screen.
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';

class AdminTestsScreen extends StatefulWidget {
  const AdminTestsScreen({super.key});

  @override
  State<AdminTestsScreen> createState() => _AdminTestsScreenState();
}

class _AdminTestsScreenState extends State<AdminTestsScreen> {
  TestType? _filterType; // null = all types

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
      body: Column(
        children: [
          // Type filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<TestType?>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Filter by type',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<TestType?>(
                  value: null,
                  child: Text('All types'),
                ),
                ...TestType.values.map(
                  (t) => DropdownMenuItem<TestType?>(
                    value: t,
                    child: Text(_typeLabel(t)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _filterType = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TestModel>>(
              stream: FirestoreService.getTestsStream(type: _filterType),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load tests. Check your connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final tests = snapshot.data ?? [];
                if (tests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filterType == null
                            ? 'No tests yet. Tap + to add one.'
                            : 'No ${_typeLabel(_filterType!)} tests yet. Tap + to add one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    return _TestCard(
                      test: test,
                      onEdit: () => _showAddEditDialog(context, test: test),
                      onDelete: () => _confirmDelete(context, test),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(TestType t) {
    switch (t) {
      case TestType.mock:
        return 'Mock Test';
      case TestType.previousYear:
        return 'Previous Year';
      case TestType.dailyQuiz:
        return 'Daily Quiz';
      case TestType.practice:
        return 'Practice';
      case TestType.subjectwise:
        return 'Subject-wise';
    }
  }

  Color _typeColor(TestType t) {
    switch (t) {
      case TestType.mock:
        return Colors.green;
      case TestType.previousYear:
        return Colors.orange;
      case TestType.dailyQuiz:
        return Colors.purple;
      case TestType.practice:
        return Colors.cyan;
      case TestType.subjectwise:
        return Colors.pink;
    }
  }

  void _showAddEditDialog(BuildContext context, {TestModel? test}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditTestDialog(test: test),
    );
  }

  void _confirmDelete(BuildContext context, TestModel test) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Test?'),
          content: Text(
              'Are you sure you want to delete "${test.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                try {
                  await FirestoreService.deleteTest(test.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test deleted')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
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
// Test card — shows a rich summary of the test with Edit/Delete actions.
// =============================================================================
class _TestCard extends StatelessWidget {
  final TestModel test;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TestCard({
    required this.test,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final chipBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);

    Color typeColor(TestType t) {
      switch (t) {
        case TestType.mock:
          return Colors.green;
        case TestType.previousYear:
          return Colors.orange;
        case TestType.dailyQuiz:
          return Colors.purple;
        case TestType.practice:
          return Colors.cyan;
        case TestType.subjectwise:
          return Colors.pink;
      }
    }

    String typeLabel(TestType t) {
      switch (t) {
        case TestType.mock:
          return 'Mock';
        case TestType.previousYear:
          return 'Previous Year';
        case TestType.dailyQuiz:
          return 'Daily Quiz';
        case TestType.practice:
          return 'Practice';
        case TestType.subjectwise:
          return 'Subject-wise';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (test.slug.isNotEmpty)
                        Text(
                          test.slug,
                          style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                              fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(typeLabel(test.type), typeColor(test.type)),
                _chip('${test.questionCount} Qs', null, bg: chipBg),
                _chip('${test.duration} min', null, bg: chipBg),
                _chip('${test.totalMarks} marks', null, bg: chipBg),
                if (test.isPublished)
                  _chip('Published', Colors.green)
                else
                  _chip('Draft', Colors.amber),
                if (test.isPremium)
                  _chip('Premium', AppTheme.accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color? color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color != null ? color.withValues(alpha: 0.12) : (bg ?? Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: color != null
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// Add/Edit Test dialog — full form with all 13 fields.
// =============================================================================
class _AddEditTestDialog extends StatefulWidget {
  final TestModel? test; // null = Add mode
  const _AddEditTestDialog({this.test});

  @override
  State<_AddEditTestDialog> createState() => _AddEditTestDialogState();
}

class _AddEditTestDialogState extends State<_AddEditTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _totalMarksCtrl = TextEditingController();
  final _passingMarksCtrl = TextEditingController();
  final _negMarksCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  String _subjectId = '';
  TestType _type = TestType.mock;
  TestDifficulty _difficulty = TestDifficulty.medium;
  bool _negativeMarking = false;
  bool _isPublished = true;
  bool _isPremium = false;
  bool _saving = false;
  bool _slugTouched = false;

  List<SubjectModel> _subjects = [];

  @override
  void initState() {
    super.initState();
    if (widget.test != null) {
      final t = widget.test!;
      _titleCtrl.text = t.title;
      _slugCtrl.text = t.slug;
      _durationCtrl.text = t.duration.toString();
      _totalMarksCtrl.text = t.totalMarks.toString();
      _passingMarksCtrl.text = t.passingMarks.toString();
      _negMarksCtrl.text = t.negativeMarks.toString();
      _instructionsCtrl.text = t.instructions ?? '';
      _subjectId = t.subjectId;
      _type = t.type;
      _difficulty = t.difficulty;
      _negativeMarking = t.negativeMarking;
      _isPublished = t.isPublished;
      _isPremium = t.isPremium;
      _slugTouched = true;
    } else {
      _durationCtrl.text = '60';
      _totalMarksCtrl.text = '100';
      _passingMarksCtrl.text = '40';
      _negMarksCtrl.text = '0.25';
    }
    _loadSubjects();
  }

  void _loadSubjects() async {
    try {
      final subs = await FirestoreService.getSubjects();
      if (!mounted) return;
      setState(() => _subjects = subs);
      // If editing and the existing subjectId isn't in the loaded list yet
      // (race condition), don't override _subjectId — let the user re-pick.
      if (_subjectId.isNotEmpty &&
          !_subjects.any((s) => s.id == _subjectId)) {
        // leave _subjectId as-is; dropdown will show nothing selected until
        // the list refreshes. This guards against the assertion error when
        // dropdown value isn't in items.
      }
    } catch (e) {
      print('AdminTests: load subjects error: $e');
    }
  }

  String _slugify(String s) {
    return s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.test == null ? 'Add Test' : 'Edit Test'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onChanged: (v) {
                    if (!_slugTouched) {
                      _slugCtrl.text = _slugify(v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Slug', hintText: 'auto-generated'),
                  onChanged: (_) => _slugTouched = true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _subjects.any((s) => s.id == _subjectId)
                      ? _subjectId
                      : null,
                  decoration: const InputDecoration(labelText: 'Subject *'),
                  items: _subjects
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _subjectId = v ?? ''),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select a subject' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TestType>(
                  value: _type,
                  decoration: const InputDecoration(
                      labelText: 'Type * (select Daily Quiz for daily quizzes)'),
                  items: [
                    DropdownMenuItem(
                        value: TestType.mock, child: Text('Mock Test')),
                    DropdownMenuItem(
                        value: TestType.previousYear,
                        child: Text('Previous Year')),
                    DropdownMenuItem(
                        value: TestType.dailyQuiz, child: Text('Daily Quiz')),
                    DropdownMenuItem(
                        value: TestType.practice, child: Text('Practice')),
                    DropdownMenuItem(
                        value: TestType.subjectwise,
                        child: Text('Subject-wise')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? TestType.mock),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Duration (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _totalMarksCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Total Marks'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _passingMarksCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Passing Marks'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TestDifficulty>(
                        value: _difficulty,
                        decoration:
                            const InputDecoration(labelText: 'Difficulty'),
                        items: [
                          DropdownMenuItem(
                              value: TestDifficulty.easy, child: Text('Easy')),
                          DropdownMenuItem(
                              value: TestDifficulty.medium,
                              child: Text('Medium')),
                          DropdownMenuItem(
                              value: TestDifficulty.hard, child: Text('Hard')),
                        ],
                        onChanged: (v) => setState(
                            () => _difficulty = v ?? TestDifficulty.medium),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _negMarksCtrl,
                        decoration: InputDecoration(
                          labelText: 'Neg. Marks',
                          enabled: _negativeMarking,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Negative Marking'),
                  value: _negativeMarking,
                  onChanged: (v) => setState(() => _negativeMarking = v),
                ),
                SwitchListTile(
                  title: const Text('Published'),
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                ),
                SwitchListTile(
                  title: const Text('Premium (paid users only)'),
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instructionsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Instructions (optional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final model = TestModel(
      id: widget.test?.id ?? '',
      subjectId: _subjectId,
      title: _titleCtrl.text.trim(),
      slug: _slugCtrl.text.trim().isNotEmpty
          ? _slugify(_slugCtrl.text.trim())
          : _slugify(_titleCtrl.text.trim()),
      type: _type,
      duration: int.tryParse(_durationCtrl.text) ?? 60,
      totalMarks: int.tryParse(_totalMarksCtrl.text) ?? 100,
      passingMarks: int.tryParse(_passingMarksCtrl.text) ?? 40,
      isPublished: _isPublished,
      difficulty: _difficulty,
      negativeMarking: _negativeMarking,
      negativeMarks: double.tryParse(_negMarksCtrl.text) ?? 0.25,
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      isPremium: _isPremium,
      questionCount: widget.test?.questionCount ?? 0,
      attemptCount: widget.test?.attemptCount ?? 0,
      createdAt: widget.test?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      if (widget.test == null) {
        await FirestoreService.addTest(model);
      } else {
        await FirestoreService.updateTest(model);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.test == null
            ? 'Test added'
            : 'Test updated')),
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

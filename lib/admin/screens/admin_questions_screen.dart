// =============================================================================
// ExamVault - Admin Questions CRUD Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminQuestionsScreen extends StatefulWidget {
  const AdminQuestionsScreen({super.key});

  @override
  State<AdminQuestionsScreen> createState() => _AdminQuestionsScreenState();
}

class _AdminQuestionsScreenState extends State<AdminQuestionsScreen> {
  late List<LocalQuestion> _items;
  late List<LocalTest> _tests;
  String? _filterTestId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = LocalDataService.getQuestions();
    _tests = LocalDataService.getTests();
  }

  List<LocalQuestion> get _filtered => _filterTestId == null
      ? _items
      : _items.where((q) => q.testId == _filterTestId).toList();

  String _testTitle(String id) {
    final i = _tests.indexWhere((t) => t.id == id);
    return i >= 0 ? _tests[i].title : '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter dropdown
          Container(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _filterTestId,
              decoration: const InputDecoration(labelText: 'Filter by Test'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Tests')),
                ..._tests
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))),
              ],
              onChanged: (v) => setState(() => _filterTestId = v),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No questions. Add one!'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final q = _filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            q.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                              '${_testTitle(q.testId)} • Correct: ${String.fromCharCode(65 + q.correctIndex)}. ${q.options[q.correctIndex]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.errorColor),
                            onPressed: () async {
                              await LocalDataService.deleteQuestion(q.id);
                              setState(_reload);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    if (_tests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one test first.')),
      );
      return;
    }
    String? selectedTestId = _tests.first.id;
    final qController = TextEditingController();
    final optControllers =
        List.generate(4, (_) => TextEditingController());
    final explanationController = TextEditingController();
    int correctIndex = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSt) {
          return AlertDialog(
            title: const Text('Add Question'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedTestId,
                    decoration: const InputDecoration(labelText: 'Test'),
                    items: _tests
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.title),
                            ))
                        .toList(),
                    onChanged: (v) => setSt(() => selectedTestId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qController,
                    decoration: const InputDecoration(
                        labelText: 'Question'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(4, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: correctIndex,
                            onChanged: (v) => setSt(() => correctIndex = v ?? 0),
                          ),
                          Expanded(
                            child: TextField(
                              controller: optControllers[i],
                              decoration: InputDecoration(
                                  labelText:
                                      'Option ${String.fromCharCode(65 + i)}'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(
                        labelText: 'Explanation (optional)'),
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
                  if (qController.text.trim().isEmpty ||
                      selectedTestId == null ||
                      optControllers.any((c) => c.text.trim().isEmpty)) {
                    return;
                  }
                  await LocalDataService.addQuestion(LocalQuestion(
                    id: '',
                    testId: selectedTestId!,
                    question: qController.text.trim(),
                    options: optControllers
                        .map((c) => c.text.trim())
                        .toList(),
                    correctIndex: correctIndex,
                    explanation: explanationController.text.trim(),
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

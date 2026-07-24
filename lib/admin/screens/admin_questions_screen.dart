// =============================================================================
// ExamVault - Admin Questions CRUD Screen
// =============================================================================
// Admin picks a test from the dropdown, then manages that test's questions
// (add / edit / delete). Each question has: question text, an optional
// Assamese translation, 4 options (with optional Assamese translations),
// the correct-answer index, an optional explanation, marks, and a premium
// flag. Uses FirestoreService.getQuestionsStream / addQuestion /
// updateQuestion / deleteQuestion.
//
// Dark-mode aware (isDark ternary throughout) so it matches the rest of the
// admin app after the v3 theme migration.
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/question_model.dart';
import '../../models/test_model.dart';
import '../../services/firestore_service.dart';

class AdminQuestionsScreen extends StatefulWidget {
  const AdminQuestionsScreen({super.key});

  @override
  State<AdminQuestionsScreen> createState() => _AdminQuestionsScreenState();
}

class _AdminQuestionsScreenState extends State<AdminQuestionsScreen> {
  List<TestModel> _tests = [];
  TestModel? _selectedTest;
  bool _loadingTests = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    try {
      final tests = await FirestoreService.getTests();
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loadingTests = false;
        // Auto-select the first test so the question list isn't empty.
        if (_selectedTest == null && tests.isNotEmpty) {
          _selectedTest = tests.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingTests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            // Disable until a test is selected — questions belong to a test.
            onPressed: _selectedTest == null
                ? null
                : () => _showAddEditDialog(context, testId: _selectedTest!.id),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== Test picker =====
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
            color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 20,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: _loadingTests
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DropdownButtonFormField<TestModel>(
                          value: _selectedTest,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          hint: const Text('Select a test'),
                          items: _tests
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedTest = v),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ===== Question list =====
          Expanded(child: _buildQuestionList(isDark)),
        ],
      ),
    );
  }

  Widget _buildQuestionList(bool isDark) {
    if (_loadingTests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load tests:\n$_loadError',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.errorColor)),
        ),
      );
    }
    if (_tests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined,
                  size: 64,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No tests yet.\nCreate a test first, then add questions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    if (_selectedTest == null) {
      return Center(
        child: Text('Select a test above to manage its questions.',
            style: TextStyle(
                color:
                    isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
      );
    }
    return StreamBuilder<List<QuestionModel>>(
      stream: FirestoreService.getQuestionsStream(_selectedTest!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off,
                      size: 56,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500),
                  const SizedBox(height: 12),
                  Text('Failed to load questions',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade200
                              : Colors.grey.shade800)),
                  const SizedBox(height: 4),
                  Text(snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)),
                ],
              ),
            ),
          );
        }
        final questions = snapshot.data ?? [];
        if (questions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.question_answer_outlined,
                      size: 64,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No questions in "${_selectedTest!.title}" yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final q = questions[index];
            return _QuestionCard(
              question: q,
              index: index,
              onEdit: () => _showAddEditDialog(context,
                  testId: _selectedTest!.id, question: q),
              onDelete: () => _confirmDelete(context, q),
            );
          },
        );
      },
    );
  }

  // ==================== ADD / EDIT DIALOG ====================
  void _showAddEditDialog(BuildContext context,
      {required String testId, QuestionModel? question}) {
    final qCtrl = TextEditingController(text: question?.question ?? '');
    final qAsCtrl = TextEditingController(text: question?.questionAs ?? '');
    final explCtrl = TextEditingController(text: question?.explanation ?? '');
    final explAsCtrl =
        TextEditingController(text: question?.explanationAs ?? '');
    final topicCtrl =
        TextEditingController(text: question?.subjectTopic ?? '');
    final marksCtrl =
        TextEditingController(text: (question?.marks ?? 1).toString());

    // Options — support 2 to 6 options, default 4. Seed from existing or 4 blanks.
    final List<TextEditingController> optCtrls = (question?.options ??
            ['', '', '', ''])
        .map((o) => TextEditingController(text: o))
        .toList();
    final List<TextEditingController> optAsCtrls = (question?.optionsAs.isEmpty ?? true
            ? List<String>.filled(optCtrls.length, '')
            : question!.optionsAs)
        .map((o) => TextEditingController(text: o))
        .toList();
    // Pad optionsAs to match options length.
    while (optAsCtrls.length < optCtrls.length) {
      optAsCtrls.add(TextEditingController());
    }
    int correctIndex = question?.correctAnswerIndex ?? 0;
    if (correctIndex >= optCtrls.length) correctIndex = 0;
    bool isPremium = question?.isPremium ?? false;
    bool showAs = question?.questionAs != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(question == null ? 'Add Question' : 'Edit Question'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: qCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Question *',
                          alignLabelWithHint: true),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Add Assamese translation',
                          style: TextStyle(fontSize: 13)),
                      value: showAs,
                      onChanged: (v) =>
                          setState(() => showAs = v ?? false),
                    ),
                    if (showAs) ...[
                      TextField(
                        controller: qAsCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Question (Assamese)',
                            alignLabelWithHint: true),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Options (tap the circle to mark correct)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    for (int i = 0; i < optCtrls.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(
                                correctIndex == i
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: correctIndex == i
                                    ? AppTheme.successColor
                                    : Colors.grey,
                              ),
                              onPressed: () =>
                                  setState(() => correctIndex = i),
                              tooltip: 'Mark as correct',
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: optCtrls[i],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: 'Option ${i + 1}',
                                      border: const OutlineInputBorder(),
                                      suffixText: '${i + 1}',
                                    ),
                                    maxLines: 2,
                                  ),
                                  if (showAs)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: TextField(
                                        controller: optAsCtrls[i],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Assamese option ${i + 1}',
                                          border: const OutlineInputBorder(),
                                        ),
                                        maxLines: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (optCtrls.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: AppTheme.errorColor, size: 20),
                                onPressed: () {
                                  setState(() {
                                    optCtrls[i].dispose();
                                    optAsCtrls[i].dispose();
                                    optCtrls.removeAt(i);
                                    optAsCtrls.removeAt(i);
                                    if (correctIndex >= optCtrls.length) {
                                      correctIndex = optCtrls.length - 1;
                                    }
                                  });
                                },
                                tooltip: 'Remove option',
                              ),
                          ],
                        ),
                      ),
                    if (optCtrls.length < 6)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            optCtrls.add(TextEditingController());
                            optAsCtrls.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add option'),
                      ),
                    const Divider(),
                    TextField(
                      controller: explCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Explanation (optional)',
                          alignLabelWithHint: true),
                      maxLines: 2,
                    ),
                    if (showAs) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: explAsCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Explanation (Assamese, optional)',
                            alignLabelWithHint: true),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: topicCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Subject / Topic (optional)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: marksCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Marks',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Premium',
                                style: TextStyle(fontSize: 13)),
                            value: isPremium,
                            onChanged: (v) =>
                                setState(() => isPremium = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  // Validate.
                  if (qCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Question text is required')));
                    return;
                  }
                  final options = optCtrls
                      .map((c) => c.text.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();
                  if (options.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('At least 2 non-empty options required')));
                    return;
                  }
                  if (correctIndex >= options.length) correctIndex = 0;

                  final now = DateTime.now();
                  final model = QuestionModel(
                    id: question?.id ?? '',
                    testId: testId,
                    question: qCtrl.text.trim(),
                    questionAs:
                        showAs && qAsCtrl.text.trim().isNotEmpty
                            ? qAsCtrl.text.trim()
                            : null,
                    options: options,
                    optionsAs: showAs
                        ? optAsCtrls
                            .map((c) => c.text.trim())
                            .where((t) => t.isNotEmpty)
                            .toList()
                        : const [],
                    explanation: explCtrl.text.trim().isEmpty
                        ? null
                        : explCtrl.text.trim(),
                    explanationAs: showAs && explAsCtrl.text.trim().isNotEmpty
                        ? explAsCtrl.text.trim()
                        : null,
                    correctAnswerIndex: correctIndex,
                    subjectTopic: topicCtrl.text.trim().isEmpty
                        ? null
                        : topicCtrl.text.trim(),
                    marks: int.tryParse(marksCtrl.text) ?? 1,
                    isPremium: isPremium,
                    imageUrl: question?.imageUrl,
                    createdAt: question?.createdAt ?? now,
                    updatedAt: now,
                  );
                  Navigator.pop(context); // close dialog
                  try {
                    if (question == null) {
                      await FirestoreService.addQuestion(model);
                    } else {
                      await FirestoreService.updateQuestion(model);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(question == null
                              ? 'Question added'
                              : 'Question updated')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save: $e')));
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

  void _confirmDelete(BuildContext context, QuestionModel q) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Question?'),
          content: Text(
              'Delete this question?\n\n"${q.question}"',
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                Navigator.pop(context); // close confirm
                try {
                  await FirestoreService.deleteQuestion(q.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Question deleted')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')));
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

// ==================== QUESTION CARD ====================
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final QuestionModel question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.question,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade100
                          : Colors.grey.shade900,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (question.isPremium)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert,
                      size: 20,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Options list — correct one highlighted.
            for (int i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i == question.correctAnswerIndex
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: i == question.correctAnswerIndex
                          ? AppTheme.successColor
                          : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: i == question.correctAnswerIndex
                              ? (isDark
                                  ? AppTheme.successColor
                                  : AppTheme.successColor)
                              : (isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700),
                          fontWeight: i == question.correctAnswerIndex
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (question.explanation != null &&
                question.explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.primaryColor : AppTheme.primaryColor)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        question.explanation!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (question.subjectTopic != null &&
                    question.subjectTopic!.isNotEmpty)
                  _miniChip(question.subjectTopic!, isDark),
                if (question.marks != 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _miniChip('${question.marks} marks', isDark),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade700.withOpacity(0.4)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade600)),
    );
  }
}

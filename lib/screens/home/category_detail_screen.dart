// =============================================================================
// ExamVault - Category Detail Screen (shows tests in a category) — offline
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../tests/take_test_screen.dart';

class CategoryDetailScreen extends StatelessWidget {
  final LocalCategory category;

  const CategoryDetailScreen({super.key, required this.category});

  Color get _color => _parseColor(category.color);

  @override
  Widget build(BuildContext context) {
    final tests = LocalDataService.testsByCategory(category.id);
    final subjects = LocalDataService.subjectsByCategory(category.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color, _color.withOpacity(0.7)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(category.icon),
                        color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tests.length} Tests • ${subjects.length} Subjects',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (category.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    category.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Tests list
          Expanded(
            child: tests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.quiz_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No tests available in this category yet.'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tests.length,
                    itemBuilder: (context, index) =>
                        _buildTestCard(context, tests[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, LocalTest test) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.quiz, color: _color),
        ),
        title: Text(
          test.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${test.totalQuestions} Qs • ${test.durationMinutes} min • ${test.totalMarks} marks',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
          );
        },
      ),
    );
  }

  // ---------------------- helpers ----------------------
  Color _parseColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  IconData _iconFor(String name) {
    const map = <String, IconData>{
      'school': Icons.school,
      'train': Icons.train,
      'work': Icons.work,
      'account_balance': Icons.account_balance,
      'savings': Icons.savings,
      'public': Icons.public,
      'book': Icons.book,
      'calculate': Icons.calculate,
      'psychology': Icons.psychology,
      'menu_book': Icons.menu_book,
      'library_books': Icons.library_books,
      'timeline': Icons.timeline,
    };
    return map[name] ?? Icons.school;
  }
}

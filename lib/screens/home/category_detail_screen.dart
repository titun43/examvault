// =============================================================================
// ExamVault - Category Detail Screen (shows subjects in a category)
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../tests/test_list_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  /// Bumped on pull-to-refresh to force the StreamBuilder to re-subscribe.
  int _reloadKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.categoryColors[widget.category.name] ?? AppTheme.primaryColor,
                  (AppTheme.categoryColors[widget.category.name] ?? AppTheme.primaryColor)
                      .withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.category.icon ?? '📚',
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.category.subjectCount} Subjects Available',
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
                if (widget.category.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.category.description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Subjects List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _reloadKey++);
                // Give the new stream a moment to emit.
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: StreamBuilder<List<SubjectModel>>(
                key: ValueKey('subjects-${_reloadKey}'),
                // Pass the category's doc id, name AND slug so the stream can
                // match subjects regardless of whether the admin wrote
                // categoryId as the doc id, the category name, or the slug.
                // This is what fixes "no subject available" under Indian
                // Railways when subjects were created via the Firestore
                // console with a name/slug instead of the doc id.
                stream: FirestoreService.getSubjectsStream(
                  categoryId: widget.category.id,
                  categoryName: widget.category.name,
                  categorySlug: widget.category.slug,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Surface stream errors instead of silently showing "No
                  // subjects available" — this is the root cause of the user
                  // seeing "no subject available" even when subjects exist.
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final subject = snapshot.data![index];
                      return _buildSubjectCard(context, subject);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'Couldn\'t load subjects',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => setState(() => _reloadKey++),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'No subjects available yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Subjects for ${widget.category.name} will appear here. Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => setState(() => _reloadKey++),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectModel subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              subject.icon ?? '📚',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subject.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subject.testCount} Tests',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestListScreen(subject: subject),
            ),
          );
        },
      ),
    );
  }
}

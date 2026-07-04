// =============================================================================
// ExamVault - Bookmarks Screen
// =============================================================================
// Shows the current user's bookmarked tests, streamed from
// users/{uid}/bookmarks. Tapping a bookmark opens its TestListScreen so the
// user can start the test immediately.
//
// Guests see a "Sign in to use bookmarks" prompt so they know what they're
// missing without crashing.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../tests/test_list_screen.dart';
import '../../models/test_model.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    // Guest mode — no uid, can't read bookmarks.
    if (auth.isGuest || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookmarks')),
        body: _buildGuestState(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        actions: [
          // Clear-all option (long-press safety via confirm dialog).
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClearAll(context, user.id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear all bookmarks'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.getBookmarksStream(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load bookmarks.\nCheck your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          final bookmarks = snapshot.data ?? [];
          if (bookmarks.isEmpty) {
            return _buildEmpty(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              return _buildBookmarkCard(context, bookmarks[index], user.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookmarkCard(
      BuildContext context, Map<String, dynamic> bm, String uid) {
    final testId = bm['testId'] as String? ?? bm['id'] as String? ?? '';
    final title = bm['testTitle'] as String? ?? 'Test';
    final subjectId = bm['subjectId'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bookmark, color: AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Remove bookmark button.
            IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined,
                  color: Colors.red),
              tooltip: 'Remove bookmark',
              onPressed: () =>
                  FirestoreService.removeBookmark(uid, testId),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () {
          if (testId.isEmpty) return;
          // Navigate to TestListScreen in "single test" mode.
          // TestListScreen + TakeTestScreen will do their own access checks.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestListScreen(
                testId: testId,
                subject: null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border,
                  size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'No bookmarks yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark tests while taking them.\nThey\'ll appear here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border,
                  size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sign in to use Bookmarks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a free account to bookmark tests\nand access them anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Sign In / Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content:
            const Text('This will remove all your bookmarks. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Get current bookmarks from stream is difficult without a state var.
      // Use a direct Firestore read instead.
      try {
        final snap = await FirestoreService.getBookmarksOnce(uid);
        for (final id in snap) {
          await FirestoreService.removeBookmark(uid, id);
        }
      } catch (_) {}
    }
  }
}

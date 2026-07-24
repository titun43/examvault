// =============================================================================
// ExamVault - Admin Users Management Screen
// =============================================================================
// Lists all users with a premium badge + block/unblock toggle. "View Details"
// opens a dialog showing the user's stats. "Block/Unblock" flips the
// `isActive` field on the user's Firestore doc.
//
// Dark-mode aware + try/catch on writes + snapshot.hasError handling.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder(
        stream: FirebaseService.usersRef.snapshots(),
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
                    Icon(Icons.cloud_off,
                        size: 56,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500),
                    const SizedBox(height: 12),
                    Text('Failed to load users',
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No users yet.',
                  style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = UserModel.fromFirestore(docs[index]);
              return _UserCard(user: user);
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isPremium
              ? AppTheme.accentColor.withOpacity(0.1)
              : AppTheme.primaryColor.withOpacity(0.1),
          child: user.photoUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                      imageUrl: user.photoUrl!, fit: BoxFit.cover),
                )
              : const Icon(Icons.person),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(user.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (user.role == UserRole.admin)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ADMIN',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            if (!user.isActive)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('BLOCKED',
                      style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        subtitle: Text(
          user.email ?? user.phoneNumber ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.isPremium)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'view', child: Text('View Details')),
                PopupMenuItem(
                  value: 'block',
                  child: Text(user.isActive ? 'Block User' : 'Unblock User'),
                ),
              ],
              onSelected: (value) {
                if (value == 'view') {
                  _showDetails(context, user);
                } else if (value == 'block') {
                  _toggleBlock(context, user);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, UserModel u) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('User Details'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Name', u.name, isDark),
                  _detailRow('Email', u.email ?? '—', isDark),
                  _detailRow('Phone', u.phoneNumber ?? '—', isDark),
                  _detailRow('Role', u.role.name, isDark),
                  _detailRow('Status', u.isActive ? 'Active' : 'Blocked',
                      isDark),
                  _detailRow('Subscription', u.subscriptionStatus.name,
                      isDark),
                  if (u.subscriptionExpiry != null)
                    _detailRow(
                        'Sub. expiry',
                        '${u.subscriptionExpiry!.day}/${u.subscriptionExpiry!.month}/${u.subscriptionExpiry!.year}',
                        isDark),
                  _detailRow('Tests attempted',
                      u.totalTestsAttempted.toString(), isDark),
                  _detailRow('Average score',
                      '${u.averageScore.toStringAsFixed(1)}%', isDark),
                  _detailRow('Streak', '${u.streak} days', isDark),
                  _detailRow('Level / XP', 'Lv ${u.level} · ${u.totalXp} XP',
                      isDark),
                  _detailRow(
                      'Joined',
                      '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}',
                      isDark),
                  if (u.lastActiveAt != null)
                    _detailRow(
                        'Last active',
                        '${u.lastActiveAt!.day}/${u.lastActiveAt!.month}/${u.lastActiveAt!.year}',
                        isDark),
                  _detailRow('Purchased tests',
                      u.purchasedTests.length.toString(), isDark),
                  _detailRow('Unlocked categories',
                      u.purchasedCategoryIds.length.toString(), isDark),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.grey.shade100
                        : Colors.grey.shade900)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlock(BuildContext context, UserModel u) async {
    // Confirm before blocking (unblocking is safe, no confirm needed).
    if (u.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Block User?'),
          content: Text(
              'Block "${u.name}"? They will be signed out and unable to use the app until unblocked.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await FirebaseService.usersRef.doc(u.id).update({
        'isActive': !u.isActive,
        'updatedAt': DateTime.now(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(u.isActive
                  ? '${u.name} blocked'
                  : '${u.name} unblocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

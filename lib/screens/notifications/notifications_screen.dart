// ExamVault - Notifications Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../services/firestore_service.dart';
import '../../l10n/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'notifications_title')),
        actions: [
          TextButton(
            onPressed: () {
              FirestoreService.markAllNotificationsRead(userId);
            },
            child: Text(tr(context, 'notifications_mark_all_read'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: FirestoreService.getNotificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(tr(context, 'notifications_empty')),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: notification.isRead ? null : AppTheme.primaryColor.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTypeColor(notification.type).withOpacity(0.1),
                    child: Icon(_getTypeIcon(notification.type), color: _getTypeColor(notification.type)),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    FirestoreService.markNotificationRead(notification.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.testResult: return AppTheme.primaryColor;
      case NotificationType.newTest: return AppTheme.successColor;
      case NotificationType.currentAffair: return AppTheme.notifColorCurrentAffair;
      case NotificationType.leaderboard: return AppTheme.accentColor;
      case NotificationType.premium: return AppTheme.notifColorPremium;
      case NotificationType.announcement: return AppTheme.notifColorAnnouncement;
      case NotificationType.dailyQuiz: return AppTheme.notifColorDailyQuiz;
      default: return AppTheme.notifColorDefault;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.testResult: return Icons.assessment;
      case NotificationType.newTest: return Icons.quiz;
      case NotificationType.currentAffair: return Icons.newspaper;
      case NotificationType.leaderboard: return Icons.leaderboard;
      case NotificationType.premium: return Icons.workspace_premium;
      case NotificationType.announcement: return Icons.campaign;
      case NotificationType.dailyQuiz: return Icons.today;
      default: return Icons.notifications;
    }
  }
}

// ExamVault - Notifications Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../services/firestore_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              FirestoreService.markAllNotificationsRead(userId);
            },
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet'),
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
      case NotificationType.currentAffair: return Colors.purple;
      case NotificationType.leaderboard: return AppTheme.accentColor;
      case NotificationType.premium: return Colors.amber;
      case NotificationType.announcement: return Colors.blue;
      case NotificationType.dailyQuiz: return Colors.teal;
      default: return Colors.grey;
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

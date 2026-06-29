// =============================================================================
// ExamVault - Notification Service (Push Notifications)
// =============================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_service.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'examvault_notifications',
    'ExamVault Notifications',
    description: 'Notifications for tests, results, and updates',
    importance: Importance.high,
  );

  // ==================== INITIALIZE ====================
  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    // Request permission
    await FirebaseService.messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Setup local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Get FCM token
    final token = await FirebaseService.messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Listen for token refresh
    FirebaseService.messaging.onTokenRefresh.listen(_saveFcmToken);
  }

  // ==================== HANDLE FOREGROUND MESSAGE ====================
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }
  }

  // ==================== BACKGROUND MESSAGE HANDLER ====================
  @pragma('vm:entry-point')
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    // Handle background messages
  }

  // ==================== SAVE FCM TOKEN ====================
  static Future<void> _saveFcmToken(String token) async {
    final userId = FirebaseService.auth.currentUser?.uid;
    if (userId == null) return;

    await FirebaseService.usersRef.doc(userId).update({
      'fcmToken': token,
    });
  }

  // ==================== SUBSCRIBE TO TOPICS ====================
  static Future<void> subscribeToAllTopics() async {
    await FirebaseService.messaging.subscribeToTopic('all_users');
    await FirebaseService.messaging.subscribeToTopic('daily_quiz');
    await FirebaseService.messaging.subscribeToTopic('current_affairs');
  }

  static Future<void> subscribeToCategory(String categoryId) async {
    await FirebaseService.messaging.subscribeToTopic('category_$categoryId');
  }

  static Future<void> unsubscribeFromCategory(String categoryId) async {
    await FirebaseService.messaging.unsubscribeFromTopic('category_$categoryId');
  }

  // ==================== LOCAL NOTIFICATION ====================
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _localNotifications.show(
      title.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: data?.toString(),
    );
  }

  // ==================== SCHEDULE NOTIFICATION ====================
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _localNotifications.zonedSchedule(
      title.hashCode,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

// =============================================================================
// ExamVault - Notification Service (Push Notifications)
// CRASH-SAFETY (v1.14+): EVERY native call (FCM + local notifications) is
// wrapped in its own try/catch. FCM getToken/requestPermission can crash
// natively if Google Play Services is missing/outdated. The background
// message handler is now a TOP-LEVEL function (required by firebase_messaging
// — a static method crashes the background isolate in release mode).
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_service.dart';

// =============================================================================
// TOP-LEVEL BACKGROUND MESSAGE HANDLER
// =============================================================================
// firebase_messaging REQUIRES the background handler to be a TOP-LEVEL
// function (not a static method or a class method). In release mode, the
// background isolate runs in a separate entry point and can only resolve
// top-level functions annotated with @pragma('vm:entry-point'). Using a
// static method here was causing the "ExamVault keeps stopping" crash.
@pragma('vm:entry-point')
Future<void> examVaultBackgroundMessageHandler(RemoteMessage message) async {
  // Best-effort: handle background messages. We do NOT do any Firestore or
  // FCM operations here because this runs in a separate isolate where
  // Firebase may not be initialised. Just print and return.
  try {
    print('BG message received: ${message.messageId}');
  } catch (_) {}
}

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

  static bool _initialized = false;

  // ==================== INITIALIZE ====================
  static Future<void> initialize() async {
    if (_initialized) return;

    // ---- timezone init (pure Dart, but wrap anyway) ----
    try {
      tz.initializeTimeZones();
    } catch (e) {
      print('tz.initializeTimeZones failed (non-fatal): $e');
    }

    // ---- FCM permission (can crash natively if Play Services missing) ----
    try {
      await FirebaseService.messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print('FCM requestPermission failed (non-fatal): $e');
    }

    // ---- local notifications init ----
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      await _localNotifications.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
      );
    } catch (e) {
      print('localNotifications.initialize failed (non-fatal): $e');
    }

    // ---- create Android notification channel ----
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      print('createNotificationChannel failed (non-fatal): $e');
    }

    // ---- foreground message handler ----
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      print('FCM onMessage listen failed (non-fatal): $e');
    }

    // ---- background message handler (TOP-LEVEL function) ----
    try {
      FirebaseMessaging.onBackgroundMessage(
          examVaultBackgroundMessageHandler);
    } catch (e) {
      print('FCM onBackgroundMessage register failed (non-fatal): $e');
    }

    // ---- get FCM token (can crash natively if Play Services missing) ----
    try {
      final token = await FirebaseService.messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }
    } catch (e) {
      print('FCM getToken failed (non-fatal): $e');
    }

    // ---- listen for token refresh ----
    try {
      FirebaseService.messaging.onTokenRefresh.listen((token) {
        _saveFcmToken(token);
      });
    } catch (e) {
      print('FCM onTokenRefresh listen failed (non-fatal): $e');
    }

    _initialized = true;
  }

  // ==================== HANDLE FOREGROUND MESSAGE ====================
  static void _handleForegroundMessage(RemoteMessage message) {
    try {
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
    } catch (e) {
      print('_handleForegroundMessage error (non-fatal): $e');
    }
  }

  // ==================== SAVE FCM TOKEN ====================
  // Uses set(merge:true) instead of update() because update() THROWS if the
  // user doc doesn't exist yet (race condition: token refresh fires before
  // the auth flow creates the users/{uid} doc). set(merge:true) creates the
  // doc if missing and never throws.
  static Future<void> _saveFcmToken(String token) async {
    final userId = FirebaseService.auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await FirebaseService.usersRef.doc(userId).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Best-effort — never crash the app on FCM token save failure.
      print('_saveFcmToken error (non-fatal): $e');
    }
  }

  // ==================== SUBSCRIBE TO TOPICS ====================
  static Future<void> subscribeToAllTopics() async {
    try {
      await FirebaseService.messaging.subscribeToTopic('all_users');
      await FirebaseService.messaging.subscribeToTopic('daily_quiz');
      await FirebaseService.messaging.subscribeToTopic('current_affairs');
    } catch (e) {
      print('subscribeToAllTopics error (non-fatal): $e');
    }
  }

  static Future<void> subscribeToCategory(String categoryId) async {
    try {
      await FirebaseService.messaging.subscribeToTopic('category_$categoryId');
    } catch (e) {
      print('subscribeToCategory error (non-fatal): $e');
    }
  }

  static Future<void> unsubscribeFromCategory(String categoryId) async {
    try {
      await FirebaseService.messaging
          .unsubscribeFromTopic('category_$categoryId');
    } catch (e) {
      print('unsubscribeFromCategory error (non-fatal): $e');
    }
  }

  // ==================== LOCAL NOTIFICATION ====================
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
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
    } catch (e) {
      print('showLocalNotification error (non-fatal): $e');
    }
  }

  // ==================== SCHEDULE NOTIFICATION ====================
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
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
    } catch (e) {
      print('scheduleNotification error (non-fatal): $e');
    }
  }
}

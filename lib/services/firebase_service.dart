// =============================================================================
// ExamVault - Firebase Service (Core)
// =============================================================================
// On Android, Firebase is auto-initialized from google-services.json
// (placed at android/app/google-services.json). The FirebaseOptions below
// are used as a fallback / for non-Android platforms.
// =============================================================================

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  /// Initializes Firebase. On Android this is driven by google-services.json.
  /// On platforms without a native config we pass explicit options.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
          storageBucket: AppConfig.firebaseStorageBucket,
          authDomain: AppConfig.firebaseAuthDomain,
        ),
      );
    } catch (_) {
      // Fall back to default (auto) initialization from google-services.json
      await Firebase.initializeApp();
    }

    // Crashlytics: catch all framework errors (best-effort — won't crash if
    // Crashlytics isn't configured)
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
        return true;
      };
    } catch (_) {}

    _initialized = true;
  }

  // ==================== INSTANCES ====================
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;
  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get crashlytics => FirebaseCrashlytics.instance;

  // ==================== COLLECTION REFERENCES ====================
  static CollectionReference get usersRef =>
      firestore.collection('users');
  static CollectionReference get categoriesRef =>
      firestore.collection('categories');
  static CollectionReference get subjectsRef =>
      firestore.collection('subjects');
  static CollectionReference get testsRef =>
      firestore.collection('tests');
  static CollectionReference get questionsRef =>
      firestore.collection('questions');
  static CollectionReference get resultsRef =>
      firestore.collection('results');
  static CollectionReference get subscriptionsRef =>
      firestore.collection('subscriptions');
  static CollectionReference get paymentsRef =>
      firestore.collection('payments');
  static CollectionReference get currentAffairsRef =>
      firestore.collection('current_affairs');
  static CollectionReference get notificationsRef =>
      firestore.collection('notifications');
  static CollectionReference get leaderboardRef =>
      firestore.collection('leaderboard');
  static CollectionReference get adminsRef =>
      firestore.collection('admins');
  // New collections (v1.5.0) — admin-managed content that flows to users
  static CollectionReference get announcementsRef =>
      firestore.collection('announcements');
  static CollectionReference get upcomingExamsRef =>
      firestore.collection('upcoming_exams');
  static CollectionReference get bannersRef =>
      firestore.collection('banners');
}

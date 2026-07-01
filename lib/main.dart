// =============================================================================
// ExamVault - main.dart
// Entry point of the application
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/admob_service.dart';
import 'services/razorpay_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Run the app inside a zoned error handler so that any uncaught async
  // exception (Firestore, AdMob, etc.) is logged instead of crashing the
  // app. This is the global safety net that prevents the "app closes after
  // test" bug even when an individual screen's try/catch misses something.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors (build, layout, paint) so a render
    // bug in one screen doesn't kill the whole app in release mode.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print('FlutterError: ${details.exceptionAsString()}');
    };

    // Initialize Firebase
    await FirebaseService.initialize();

    // Initialize AdMob
    await AdMobService.initialize();

    // Initialize Razorpay
    RazorpayService.initialize();

    // Initialize Notifications
    await NotificationService.initialize();

    runApp(const ExamVaultApp());
  }, (error, stackTrace) {
    // Any uncaught async error lands here. We log it but DO NOT rethrow —
    // rethrowing would crash the app, which is exactly what we're preventing.
    print('Uncaught async error (suppressed): $error');
    print(stackTrace);
  });
}

class ExamVaultApp extends StatelessWidget {
  const ExamVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

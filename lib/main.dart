// =============================================================================
// ExamVault - main.dart
// Entry point of the application
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'services/firebase_service.dart';
import 'services/admob_service.dart';
import 'services/razorpay_service.dart';
import 'services/notification_service.dart';
import 'services/local_data_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local data (auth + admin-editable content) — REQUIRED, offline-first
  await LocalDataService.initialize();

  // Initialize Firebase (best-effort; app works without it)
  try {
    await FirebaseService.initialize();
  } catch (_) {
    // Firebase optional in this build
  }

  // Initialize AdMob
  try {
    await AdMobService.initialize();
  } catch (_) {}

  // Initialize Razorpay
  try {
    RazorpayService.initialize();
  } catch (_) {}

  // Initialize Notifications
  try {
    await NotificationService.initialize();
  } catch (_) {}

  runApp(const ExamVaultApp());
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

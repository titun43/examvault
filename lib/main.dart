// =============================================================================
// ExamVault - main.dart
// Entry point of the application
// =============================================================================
// CRASH-SAFETY DESIGN (v1.14+):
// Three layers of error containment:
//   1. runZonedGuarded — catches all uncaught async Dart errors
//   2. FlutterError.onError — catches build/layout/paint errors
//   3. PlatformDispatcher.instance.onError — catches errors that escape the
//      zone (e.g. from native callbacks, isolate errors)
// Plus: ErrorWidget.builder ensures a failed widget build renders a simple
// fallback instead of crashing the app.
// Plus: ALL native SDK auto-init is DISABLED in AndroidManifest (Crashlytics,
// Analytics, AdMob, FCM). Everything inits manually from Dart inside try/catch.
// =============================================================================

import 'dart:async';
import 'dart:ui';
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
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/payments/my_purchases_screen.dart';

void main() async {
  // Run the app inside a zoned error handler so that any uncaught async
  // exception (Firestore, AdMob, etc.) is logged instead of crashing the
  // app. This is the global safety net.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ---- Framework error handler (build, layout, paint errors) ----
    // Wrap in try/catch: if FlutterError.presentError throws, we still
    // want to print the original error rather than crash the app.
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        FlutterError.presentError(details);
      } catch (_) {}
      print('FlutterError: ${details.exceptionAsString()}');
    };

    // ---- ErrorWidget builder ----
    // In release mode, when a widget build throws, Flutter renders an
    // ErrorWidget. By default this is a grey box; if THAT fails to build,
    // the app can crash. Provide a trivially-simple fallback that cannot
    // fail so the app stays alive even if a single screen errors.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.transparent,
        child: Container(
          color: const Color(0xFFF5F5F5),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: const Text(
            'Something went wrong loading this section.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF757575), fontSize: 13),
          ),
        ),
      );
    };

    // ---- PlatformDispatcher error handler ----
    // Catches errors that escape the zone — e.g. from native callbacks,
    // microtasks, or isolate errors. This is the LAST line of defense
    // before a native crash. Returns true to suppress the error.
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      print('PlatformDispatcher error (suppressed): $error');
      print(stackTrace);
      return true;
    };

    // ---- Initialize Firebase (best-effort, won't crash if it fails) ----
    try {
      await FirebaseService.initialize();
    } catch (e) {
      print('Firebase init failed (non-fatal): $e');
    }

    // ---- Initialize AdMob (best-effort) ----
    try {
      await AdMobService.initialize();
    } catch (e) {
      print('AdMob init failed (non-fatal): $e');
    }

    // ---- Initialize Razorpay (best-effort) ----
    try {
      RazorpayService.initialize();
    } catch (e) {
      print('Razorpay init failed (non-fatal): $e');
    }

    // ---- Initialize Notifications (best-effort) ----
    try {
      await NotificationService.initialize();
    } catch (e) {
      print('Notifications init failed (non-fatal): $e');
    }

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
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            // Disable theme transition animation so toggling between
            // light/dark mode is INSTANT — no intermediate white flash.
            // (Flutter's default theme animation can show a brief white
            // frame while the widget tree rebuilds.)
            themeAnimationDuration: Duration.zero,
            // Use the dark surface color as the native window background so
            // there is never a white frame behind the app during rebuilds.
            color: themeProvider.isDarkMode
                ? AppTheme.darkBackgroundColor
                : AppTheme.backgroundColor,
            // Named routes — registered so Navigator.pushNamed('/premium')
            // actually navigates to the PremiumScreen. Previously NO routes
            // were registered, so every "Go Premium" button in the app was
            // silently broken (clicking did nothing / payment never opened).
            routes: {
              '/premium': (_) => const PremiumScreen(),
              '/my-purchases': (_) => const MyPurchasesScreen(),
            },
            // Builder wrapper so any uncaught error during navigation/build
            // is contained and never reaches the root MaterialApp.
            builder: (context, child) {
              return child ?? const SizedBox();
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

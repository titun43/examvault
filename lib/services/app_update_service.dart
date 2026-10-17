// =============================================================================
// ExamVault - App Update Service
// =============================================================================
// Hybrid in-app update flow:
//   1. On app start, check Play Store for update availability
//   2. If update available:
//      a) Force update? (config from Firestore) → Immediate mode (full screen, can't skip)
//      b) Otherwise → Flexible mode (background download + user prompt)
//   3. Fallback: if in_app_update fails, open Play Store page directly
//
// Industry-standard approach used by Adda247, Testbook, Unacademy, etc.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import '../theme/app_theme.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService _instance = AppUpdateService._();
  factory AppUpdateService() => _instance;

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.examvault.education';

  // Track last check time to avoid spamming the API on every screen rebuild.
  // We check at most once per app session.
  bool _checkedThisSession = false;

  /// Check for update and show appropriate UI.
  /// Call this from main.dart after the first frame.
  ///
  /// [forceMinVersion] — if set (e.g. from Firestore config), versions BELOW
  /// this number trigger a force update. Use semantic version code (int).
  /// e.g. forceMinVersion = 95 → all builds with versionCode < 95 must update.
  Future<void> checkForUpdate({
    BuildContext? context,
    int? forceMinVersion,
    int currentVersionCode = 0,
  }) async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    try {
      debugPrint('AppUpdateService: checking for update...');
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        debugPrint('AppUpdateService: no update available (state=${info.updateAvailability})');
        return;
      }

      debugPrint('AppUpdateService: update available! '
          'immediateAllowed=${info.immediateUpdateAllowed}, '
          'flexibleAllowed=${info.flexibleUpdateAllowed}');

      // Decide mode: force (immediate) vs flexible
      final bool shouldForceUpdate = forceMinVersion != null &&
          currentVersionCode > 0 &&
          currentVersionCode < forceMinVersion;

      if (context == null || !context.mounted) {
        // No context — try to start update silently (flexible)
        if (info.flexibleUpdateAllowed) {
          await _startFlexibleUpdate();
        }
        return;
      }

      if (shouldForceUpdate) {
        await _showForceUpdateDialog(context);
      } else {
        await _showFlexibleUpdateDialog(context, info);
      }
    } catch (e) {
      debugPrint('AppUpdateService: in_app_update failed (non-fatal): $e');
      // Fallback is handled lazily — user can manually check via Settings
    }
  }

  /// Start flexible (background) update. Download happens silently.
  /// User is notified when download completes.
  Future<void> _startFlexibleUpdate() async {
    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        // Download complete — install & restart
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('AppUpdateService: flexible update failed: $e');
    }
  }

  /// Flexible update dialog — user can skip or update now.
  /// Background download → install → restart.
  Future<void> _showFlexibleUpdateDialog(
      BuildContext context, AppUpdateInfo info) async {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must choose
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.system_update,
                  color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A new version of ExamVault is available with improvements and new mock tests.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // What's new (optional — could be fetched from Firestore)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.successColor.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppTheme.successColor),
                      SizedBox(width: 6),
                      Text('Bug fixes & improvements',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppTheme.successColor),
                      SizedBox(width: 6),
                      Text('New mock tests added',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: AppTheme.successColor),
                      SizedBox(width: 6),
                      Text('Better performance',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The update will download in the background and the app will restart automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Skip for now',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _performFlexibleUpdateWithProgress(context);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update Now'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Perform flexible update with a progress dialog.
  Future<void> _performFlexibleUpdateWithProgress(BuildContext context) async {
    // Show a progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Downloading update...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please keep the app open. The app will restart automatically when ready.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (context.mounted) Navigator.of(context).pop(); // close progress dialog

      if (result == AppUpdateResult.success) {
        // Download complete — install and restart
        await InAppUpdate.completeFlexibleUpdate();
        // App will restart at this point
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        // User denied — silent
      } else if (result == AppUpdateResult.inAppUpdateFailed) {
        // Fallback: open Play Store
        if (context.mounted) {
          _showFallbackPlayStoreOption(context);
        }
      }
    } catch (e) {
      debugPrint('Flexible update with progress failed: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // close progress
        _showFallbackPlayStoreOption(context);
      }
    }
  }

  /// Force update dialog — user cannot skip. Only "Update Now" button.
  Future<void> _showForceUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warningColor, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This version of ExamVault is no longer supported.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Please update to the latest version to continue using the app. Your account and progress will be preserved.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _performImmediateUpdate(context);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update Now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Immediate (full-screen) update — used for force update.
  Future<void> _performImmediateUpdate(BuildContext context) async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Immediate update failed: $e');
      if (context.mounted) {
        _showFallbackPlayStoreOption(context);
      }
    }
  }

  /// Fallback: open Play Store page directly.
  /// Used when in_app_update API fails for any reason.
  void _showFallbackPlayStoreOption(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Play Store?'),
        content: const Text(
            'In-app update is temporarily unavailable. Open Play Store to update ExamVault manually?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openPlayStore();
            },
            child: const Text('Open Play Store'),
          ),
        ],
      ),
    );
  }

  /// Open Play Store page for ExamVault.
  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Open Play Store failed: $e');
    }
  }

  /// Manual check — call from Settings → "Check for updates" button.
  Future<void> manualCheck(BuildContext context) async {
    _checkedThisSession = false; // allow re-check
    await checkForUpdate(context: context);
  }

  /// Reset session flag (for testing).
  void resetSessionFlag() {
    _checkedThisSession = false;
  }
}

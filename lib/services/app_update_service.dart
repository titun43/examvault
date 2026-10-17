// =============================================================================
// ExamVault - App Update Service (Native MethodChannel approach)
// =============================================================================
// Uses NATIVE AppUpdateManager via MethodChannel — no Flutter package needed.
// The native side (MainActivity.kt) wraps:
//   - com.google.android.play:app-update:2.1.0
//   - com.google.android.play:app-update-ktx:2.1.0
//
// Channel: "com.examvault.education/update"
// Methods:
//   - checkUpdate → returns Map with updateAvailable, versionCode, etc.
//   - startUpdate → starts flexible update flow (native dialog)
//   - openPlayStore → fallback: opens Play Store page directly
//
// This avoids the broken in_app_update Flutter package (Gradle cache issues).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService _instance = AppUpdateService._();
  factory AppUpdateService() => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.examvault.education/update');

  // Track last check time to avoid spamming the API on every screen rebuild.
  // We check at most once per app session.
  bool _checkedThisSession = false;

  /// Check for update and show appropriate UI.
  /// Call this from main.dart / splash screen after the first frame.
  Future<void> checkForUpdate({BuildContext? context}) async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;

    try {
      debugPrint('AppUpdateService: checking for update via native channel...');
      final result = await _channel.invokeMethod('checkUpdate');
      if (result == null) {
        debugPrint('AppUpdateService: null result from native');
        return;
      }

      final bool updateAvailable = result['updateAvailable'] == true;
      if (!updateAvailable) {
        debugPrint('AppUpdateService: no update available');
        return;
      }

      final int? versionCode = result['versionCode'] as int?;
      final bool flexibleAllowed = result['flexibleAllowed'] == true;
      final bool immediateAllowed = result['immediateAllowed'] == true;

      debugPrint('AppUpdateService: update available! '
          'versionCode=$versionCode, '
          'flexibleAllowed=$flexibleAllowed, '
          'immediateAllowed=$immediateAllowed');

      if (context == null || !context.mounted) {
        // No context — silent check, native side will handle prompt
        return;
      }

      await _showUpdateDialog(context);
    } catch (e) {
      debugPrint('AppUpdateService: native channel failed (non-fatal): $e');
      // Silent fail — update check is non-critical
    }
  }

  /// Show update dialog with "Later" and "Update Now" options.
  Future<void> _showUpdateDialog(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.successColor.withOpacity(0.2)),
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
              'Tap "Update Now" to download and install. The app will restart automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _startNativeUpdate(context);
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

  /// Start native update flow (flexible mode).
  /// Native side will show Play's standard update UI.
  Future<void> _startNativeUpdate(BuildContext context) async {
    try {
      await _channel.invokeMethod('startUpdate');
    } catch (e) {
      debugPrint('AppUpdateService: startUpdate failed: $e');
      // Fallback: open Play Store
      _showFallbackPlayStoreOption(context);
    }
  }

  /// Fallback: open Play Store page directly.
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

  /// Open Play Store page via native side.
  Future<void> _openPlayStore() async {
    try {
      await _channel.invokeMethod('openPlayStore');
    } catch (e) {
      debugPrint('AppUpdateService: openPlayStore failed: $e');
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

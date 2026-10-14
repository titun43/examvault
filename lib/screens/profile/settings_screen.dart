// =============================================================================
// ExamVault - Settings Screen (Modernized v2)
// =============================================================================
// v2 CHANGES:
//   - Added a Language section (English / অসমীয়া / Both) wired to the
//     LanguageProvider so users can actually switch the bilingual UI. Without
//     this toggle, the entire l10n layer was invisible to the end user.
//   - Theme section restyled with design tokens and a segmented feel.
//   - About section uses category-colored icon tiles instead of flat icons.
//   - Bilingual labels via tr() / L10nText.
//   - flutter_animate entrance on each section.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../config/app_config.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  String _appBuild = '';

  // ─── Delete Account flow state ───
  // Controller for the type-to-confirm dialog (user must type "DELETE").
  // _isDeleting gates the dialog's Confirm button + shows a spinner while
  // AuthService.deleteAccount() is in-flight.
  final TextEditingController _deleteConfirmController =
      TextEditingController();
  bool _isDeleting = false;

  // ─── Issue #19: Notification preference state ───
  // Three local toggles persisted to SharedPreferences. These are LOCAL
  // preferences only — wiring them to actual FCM topic subscribe/unsubscribe
  // (via NotificationService.subscribeToAllTopics /
  // unsubscribeFromCategory) is a follow-up task. For now the toggles just
  // record the user's intent so the FCM wiring can read them on next launch.
  // Default to true (opt-in) per FCM best practice.
  static const String _kPrefPush = 'notif_push_enabled';
  static const String _kPrefAnnouncements = 'notif_announcements_enabled';
  static const String _kPrefDailyQuiz = 'notif_daily_quiz_enabled';

  bool _notifPush = true;
  bool _notifAnnouncements = true;
  bool _notifDailyQuiz = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        // Default to true if the key has never been set (opt-in).
        _notifPush = prefs.getBool(_kPrefPush) ?? true;
        _notifAnnouncements = prefs.getBool(_kPrefAnnouncements) ?? true;
        _notifDailyQuiz = prefs.getBool(_kPrefDailyQuiz) ?? true;
      });
    } catch (_) {
      // Non-fatal — keep defaults.
    }
  }

  Future<void> _setNotifPref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Non-fatal — the in-memory toggle still flips for this session.
    }
    // NOTE (follow-up): wire these to FCM topic subscribe/unsubscribe via
    // NotificationService. E.g. when _notifPush turns false, call
    // FirebaseService.messaging.unsubscribeFromTopic('all_users') etc.
    // Left as a follow-up to avoid touching NotificationService bootstrap
    // logic in this stub-fix task.
  }

  @override
  void dispose() {
    _deleteConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _appBuild = info.buildNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersion = AppConfig.version;
        _appBuild = '';
      });
    }
  }

  Future<void> _launchUrl(String url, String label) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showToast('Invalid $label URL');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showToast('Unable to open $label');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ==================== DELETE ACCOUNT FLOW (Critical #5) ====================
  // Google Play's Data Deletion policy (effective Jan 2024) requires an
  // in-app account-deletion option. AuthService.deleteAccount() existed
  // but was never wired to any UI. This two-step confirmation flow guards
  // against accidental deletion: (1) warning dialog, (2) type-"DELETE"
  // confirmation. Only if the user types DELETE exactly (case-sensitive)
  // do we call the destructive API.

  /// Step 1: warning dialog listing what gets deleted, with a Cancel button.
  void _showDeleteAccountWarningDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppTheme.errorColor, size: 48),
        title: L10nText('settings_delete_account_confirm_title'),
        content: L10nText(
          'settings_delete_account_confirm_msg',
          style: AppFonts.style(
              size: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: L10nText('settings_delete_account_cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showTypeToDeleteDialog();
            },
            icon: const Icon(Icons.delete_forever_rounded),
            label: L10nText('settings_delete_account'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: type-"DELETE" confirmation dialog. The Confirm button is
  /// disabled until the TextField contains exactly "DELETE" (case-
  /// sensitive). While the deletion API call is in-flight, both buttons
  /// are disabled and a CircularProgressIndicator replaces the icon.
  void _showTypeToDeleteDialog() {
    _deleteConfirmController.clear();
    showDialog<void>(
      context: context,
      barrierDismissible: !_isDeleting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final typed = _deleteConfirmController.text.trim();
          final canConfirm = !_isDeleting && typed == 'DELETE';
          return PopScope(
            canPop: !_isDeleting,
            child: AlertDialog(
              title: L10nText('settings_delete_account_confirm_title'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L10nText(
                    'settings_delete_account_confirm_msg',
                    style: AppFonts.style(
                        size: 13,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurfaceVariant),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    tr(ctx, 'settings_delete_account_type_to_confirm'),
                    style: AppFonts.style(
                        size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  TextField(
                    controller: _deleteConfirmController,
                    enabled: !_isDeleting,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      border: const OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  child: L10nText('settings_delete_account_cancel'),
                ),
                FilledButton.icon(
                  onPressed: canConfirm
                      ? () async {
                          setDialogState(() => _isDeleting = true);
                          await _performDeleteAccount(ctx);
                        }
                      : null,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: L10nText('settings_delete_account_final_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.errorColor.withOpacity(0.5),
                    disabledForegroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Step 3: actually call AuthService.deleteAccount(). On success, sign
  /// the user out (deleteAccount() deletes the Auth user but does NOT call
  /// AuthService.logout(), so we explicitly clear the local AuthProvider
  /// state and its Firestore user-doc subscription), then navigate to the
  /// Login screen. On failure, reset the loading flag and surface the
  /// error via a SnackBar.
  Future<void> _performDeleteAccount(BuildContext dialogCtx) async {
    try {
      await AuthService.deleteAccount();
      if (!mounted) return;
      Navigator.of(dialogCtx).pop(); // close the type-to-confirm dialog
      _showToast(tr(context, 'settings_delete_account_success'));
      // deleteAccount() removes the Auth user but does not call signOut(),
      // so the AuthProvider still holds a stale UserModel + an active
      // user-doc subscription. Explicitly logout() to clean both up.
      try {
        await Provider.of<AuthProvider>(context, listen: false).logout();
      } catch (_) {
        // Safe to swallow — _auth.signOut() on a just-deleted user is a
        // no-op; the Auth state listener fires with null regardless.
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      // Dialog may still be open — close it so the user can retry.
      Navigator.of(dialogCtx).maybePop();
      setState(() => _isDeleting = false);
      _showToast('${tr(context, 'settings_delete_account_failed')}: $e');
    }
  }

  // ==================== LOGOUT FLOW (Issue #19) ====================
  // Logout previously lived only on the Profile screen. The audit wants it
  // on Settings too (it's the conventional place). This is a simple confirm-
  // then-call pattern (no type-to-confirm needed — logout is reversible).

  /// Shows a confirmation dialog, then calls AuthProvider.logout() and
  /// navigates to LoginScreen (clearing the back stack).
  void _showLogoutConfirmDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded,
            color: AppTheme.errorColor, size: 48),
        title: L10nText('settings_logout_confirm_title'),
        content: L10nText(
          'settings_logout_confirm_msg',
          style: AppFonts.style(
              size: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: L10nText('settings_cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performLogout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: L10nText('settings_logout_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Calls AuthProvider.logout() (which signs out FirebaseAuth, cancels the
  /// user-doc subscription, clears the in-memory UserModel, and notifies
  /// listeners), then navigates to the Login screen with a clean stack.
  Future<void> _performLogout() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).logout();
    } catch (_) {
      // Safe to swallow — signOut() on a valid session is a no-op; the
      // Auth state listener fires with null regardless.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final versionText = _appVersion.isEmpty
        ? '1.0.0'
        : _appBuild.isEmpty
            ? _appVersion
            : '$_appVersion+$_appBuild';

    return Scaffold(
      appBar: AppBar(
        title: L10nText('profile_settings',
            style: AppFonts.style(
                size: 20,
                weight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          // ==================== APPEARANCE (THEME) ====================
          _SectionHeader(labelKey: 'settings_theme'),
          const SizedBox(height: AppTheme.spaceSm),
          _SettingsCard(
            color: cardColor,
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return Column(
                  children: [
                    _ThemeOption(
                      icon: Icons.light_mode_rounded,
                      label: tr(context, 'settings_light'),
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                    ),
                    _Divider(),
                    _ThemeOption(
                      icon: Icons.dark_mode_rounded,
                      label: tr(context, 'settings_dark'),
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                    ),
                    _Divider(),
                    _ThemeOption(
                      icon: Icons.brightness_auto_rounded,
                      label: tr(context, 'settings_system'),
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                    ),
                  ],
                );
              },
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: AppTheme.spaceXxl),

          // ==================== LANGUAGE ====================
          _SectionHeader(labelKey: 'settings_language'),
          const SizedBox(height: AppTheme.spaceSm),
          _SettingsCard(
            color: cardColor,
            child: Consumer<LanguageProvider>(
              builder: (context, langProvider, _) {
                return Column(
                  children: [
                    _LanguageOption(
                      emoji: '🇬🇧',
                      label: 'English',
                      subtitle: 'English',
                      isSelected: langProvider.mode == LanguageMode.english,
                      onTap: () => langProvider.setMode(LanguageMode.english),
                    ),
                    _Divider(),
                    _LanguageOption(
                      emoji: '🇮🇳',
                      label: 'অসমীয়া',
                      subtitle: 'Assamese',
                      isSelected: langProvider.mode == LanguageMode.assamese,
                      onTap: () => langProvider.setMode(LanguageMode.assamese),
                    ),
                    _Divider(),
                    _LanguageOption(
                      emoji: '🌐',
                      label: tr(context, 'settings_both'),
                      subtitle: 'English + অসমীয়া',
                      isSelected: langProvider.mode == LanguageMode.both,
                      onTap: () => langProvider.setMode(LanguageMode.both),
                    ),
                  ],
                );
              },
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: AppTheme.spaceXxl),

          // ==================== NOTIFICATIONS (Issue #19) ====================
          // Three local toggles persisted to SharedPreferences. The actual
          // FCM topic subscribe/unsubscribe wiring is a follow-up (see the
          // _setNotifPref note above). For now these just record the user's
          // intent. The master switch (_notifPush) does NOT cascade-disable
          // the other two in the UI — that would hide the user's last-saved
          // state. The FCM wiring layer should treat _notifPush=false as a
          // global mute.
          _SectionHeader(labelKey: 'settings_notifications'),
          const SizedBox(height: AppTheme.spaceSm),
          _SettingsCard(
            color: cardColor,
            child: Column(
              children: [
                _NotifToggle(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppTheme.primaryColor,
                  titleKey: 'settings_notif_push',
                  subtitleKey: 'settings_notif_push_subtitle',
                  value: _notifPush,
                  onChanged: (v) {
                    setState(() => _notifPush = v);
                    _setNotifPref(_kPrefPush, v);
                  },
                ),
                _Divider(),
                _NotifToggle(
                  icon: Icons.campaign_rounded,
                  iconColor: AppTheme.accentColor,
                  titleKey: 'settings_notif_announcements',
                  subtitleKey: 'settings_notif_announcements_subtitle',
                  value: _notifAnnouncements,
                  onChanged: (v) {
                    setState(() => _notifAnnouncements = v);
                    _setNotifPref(_kPrefAnnouncements, v);
                  },
                ),
                _Divider(),
                _NotifToggle(
                  icon: Icons.quiz_rounded,
                  iconColor: AppTheme.warningColor,
                  titleKey: 'settings_notif_daily_quiz',
                  subtitleKey: 'settings_notif_daily_quiz_subtitle',
                  value: _notifDailyQuiz,
                  onChanged: (v) {
                    setState(() => _notifDailyQuiz = v);
                    _setNotifPref(_kPrefDailyQuiz, v);
                  },
                ),
              ],
            ),
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: AppTheme.spaceXxl),

          // ==================== ACCOUNT (DELETE ACCOUNT — Critical #5) ====================
          // Google Play Data Deletion policy (Jan 2024) requires an in-app
          // account-deletion option. Tapping the tile triggers a two-step
          // confirmation flow (warning dialog → type-"DELETE" dialog).
          _SectionHeader(labelKey: 'settings_account'),
          const SizedBox(height: AppTheme.spaceSm),
          _SettingsCard(
            color: cardColor,
            child: _AboutTile(
              icon: Icons.delete_forever_rounded,
              iconColor: AppTheme.errorColor,
              title: tr(context, 'settings_delete_account'),
              onTap: _isDeleting ? null : _showDeleteAccountWarningDialog,
            ),
          ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: AppTheme.spaceXxl),

          // ==================== ABOUT ====================
          _SectionHeader(labelKey: 'about'),
          const SizedBox(height: AppTheme.spaceSm),
          _SettingsCard(
            color: cardColor,
            child: Column(
              children: [
                _AboutTile(
                  icon: Icons.info_rounded,
                  iconColor: AppTheme.primaryColor,
                  title: tr(context, 'appVersion'),
                  trailing: Text(versionText,
                      style: AppFonts.style(
                          size: 14,
                          weight: FontWeight.w600,
                          color: subtitleColor)),
                ),
                _Divider(),
                _AboutTile(
                  icon: Icons.privacy_tip_rounded,
                  iconColor: AppTheme.successColor,
                  title: tr(context, 'privacyPolicy'),
                  onTap: () =>
                      _launchUrl(AppConfig.privacyPolicyUrl, 'Privacy Policy'),
                ),
                _Divider(),
                _AboutTile(
                  icon: Icons.description_rounded,
                  iconColor: AppTheme.accentDarkColor,
                  title: tr(context, 'termsConditions'),
                  onTap: () =>
                      _launchUrl(AppConfig.termsUrl, 'Terms & Conditions'),
                ),
                _Divider(),
                _AboutTile(
                  icon: Icons.payment_rounded,
                  iconColor: AppTheme.warningColor,
                  title: tr(context, 'refundPolicy'),
                  onTap: () =>
                      _launchUrl(AppConfig.refundPolicyUrl, 'Refund Policy'),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 160.ms, duration: 350.ms).slideY(begin: 0.05),

          const SizedBox(height: AppTheme.spaceXxl),

          // ==================== LOGOUT (Issue #19) ====================
          // Conventional placement: at the very bottom of Settings. Uses
          // errorColor to signal a destructive-ish action. Tapping shows a
          // confirmation dialog (logout is reversible but still disruptive —
          // user loses their current screen state + cache).
          _SettingsCard(
            color: cardColor,
            child: _AboutTile(
              icon: Icons.logout_rounded,
              iconColor: AppTheme.errorColor,
              title: tr(context, 'settings_logout'),
              onTap: _showLogoutConfirmDialog,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.05),

          // Bottom spacing so the last card isn't flush against the edge.
          const SizedBox(height: AppTheme.spaceXxl),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================
class _SectionHeader extends StatelessWidget {
  final String labelKey;
  const _SectionHeader({required this.labelKey});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spaceXs),
      child: L10nText(
        labelKey,
        style: AppFonts.style(
          size: 13,
          weight: FontWeight.w700,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// =============================================================================
// SETTINGS CARD WRAPPER
// =============================================================================
class _SettingsCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _SettingsCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
      ),
      child: child,
    );
  }
}

// =============================================================================
// THEME OPTION ROW
// =============================================================================
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Text(label,
                  style: AppFonts.style(
                      size: 15,
                      weight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LANGUAGE OPTION ROW
// =============================================================================
class _LanguageOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: AppFonts.style(
                          size: 15,
                          weight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: AppFonts.style(
                          size: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ABOUT TILE
// =============================================================================
class _AboutTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AboutTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd + 2),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Text(title,
                  style: AppFonts.style(
                      size: 15,
                      weight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface)),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DIVIDER
// =============================================================================
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
      ),
    );
  }
}

// =============================================================================
// NOTIFICATION TOGGLE ROW (Issue #19)
// =============================================================================
// A row with an icon, title, subtitle, and a Switch. Mirrors the visual
// structure of _AboutTile / _ThemeOption but uses a Switch instead of a
// trailing arrow. The title and subtitle are bilingual via L10nText.
class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titleKey;
  final String subtitleKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({
    required this.icon,
    required this.iconColor,
    required this.titleKey,
    required this.subtitleKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm + 2),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                L10nText(
                  titleKey,
                  style: AppFonts.style(
                    size: 15,
                    weight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                L10nText(
                  subtitleKey,
                  style: AppFonts.style(
                    size: 12,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

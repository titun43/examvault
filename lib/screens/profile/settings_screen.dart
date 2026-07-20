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
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  String _appBuild = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
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

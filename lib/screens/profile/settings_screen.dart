// ExamVault - Settings Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
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
      // Fall back to AppConfig.version if package_info is unavailable.
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
    // version(+build) — fall back to "1.0.0" if not loaded yet, but never
    // show a hardcoded stale value.
    final versionText = _appVersion.isEmpty
        ? '1.0.0'
        : _appBuild.isEmpty
            ? _appVersion
            : '$_appVersion+$_appBuild';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return Column(
                        children: [
                          RadioListTile<ThemeMode>(
                            title: const Text('Light Mode'),
                            value: ThemeMode.light,
                            groupValue: themeProvider.themeMode,
                            onChanged: (v) => themeProvider.setThemeMode(v!),
                          ),
                          RadioListTile<ThemeMode>(
                            title: const Text('Dark Mode'),
                            value: ThemeMode.dark,
                            groupValue: themeProvider.themeMode,
                            onChanged: (v) => themeProvider.setThemeMode(v!),
                          ),
                          RadioListTile<ThemeMode>(
                            title: const Text('System Default'),
                            value: ThemeMode.system,
                            groupValue: themeProvider.themeMode,
                            onChanged: (v) => themeProvider.setThemeMode(v!),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('About', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info, color: AppTheme.primaryColor),
                  title: const Text('App Version'),
                  trailing: Text(versionText),
                ),
                ListTile(
                  leading: const Icon(Icons.description, color: AppTheme.primaryColor),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _launchUrl(AppConfig.privacyPolicyUrl, 'Privacy Policy'),
                ),
                ListTile(
                  leading: const Icon(Icons.description, color: AppTheme.primaryColor),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _launchUrl(AppConfig.termsUrl, 'Terms & Conditions'),
                ),
                ListTile(
                  leading: const Icon(Icons.payment, color: AppTheme.primaryColor),
                  title: const Text('Refund Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _launchUrl(AppConfig.refundPolicyUrl, 'Refund Policy'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ExamVault - PDF Viewer Screen (Issue #18 pragmatic fix)
// =============================================================================
// PRAGMATIC FIX NOTE (Issue #18):
// The original audit wanted a full in-app PDF viewer (zoom, search, jump-to-
// page, thumbnails, offline download, annotation). The `flutter_pdfview`
// package was tried in this project before but FAILED with a Gradle
// compatibility issue ("Could not get unknown property 'android' for project
// ':flutter_pdfview'") on Flutter 3.24.5 + recent AGP — see the explanatory
// comment in pubspec.yaml's PDF section. Re-adding it now is risky and could
// break the build for every other agent working in this repo.
//
// Per the task's explicit fallback instruction ("If adding a package is
// risky (build issues), a SIMPLER alternative: keep the url_launcher approach
// but ADD a proper loading state, error handling, and an 'Open in external
// app' button. Document this as a partial fix."), this screen keeps the
// url_launcher approach but enhances it with:
//   1. A proper loading state while url_launcher resolves (already existed).
//   2. Robust error handling with a retry button (already existed, now also
//      offers a manual "Open in Browser" button so the user always has a
//      way out).
//   3. An "Open in Browser" AppBar action that is ALWAYS available, so even
//      if the auto-launch silently fails the user can tap it to manually
//      trigger the system PDF viewer.
//   4. Localized strings (was hardcoded English before).
//   5. A clearer "did it not open?" hint on the error screen pointing the
//      user at the manual button.
//
// This is a PARTIAL fix — a full in-app viewer (with the audit's full
// feature set) requires either (a) re-attempting flutter_pdfview with a
// Gradle workaround, or (b) adopting syncfusion_flutter_pdfviewer (large
// binary footprint, commercial licence for advanced features). Both are
// out of scope for this stub-fix task and risky to do blind.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String materialId;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    required this.materialId,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _launching = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _launchPdf();
  }

  /// Launches the PDF URL in the system's default PDF viewer. Tries
  /// externalApplication mode first (opens in a dedicated PDF app), then
  /// falls back to inAppBrowserView (opens in an in-app browser tab), then
  /// default platform behavior.
  Future<void> _launchPdf() async {
    setState(() {
      _launching = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(widget.pdfUrl);
      bool success = false;

      // Try external app first (dedicated PDF viewer — best experience).
      try {
        if (await canLaunchUrl(uri)) {
          success = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (_) {
        success = false;
      }

      // Fallback: in-app browser view.
      if (!success) {
        try {
          success = await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
          );
        } catch (_) {
          success = false;
        }
      }

      // Fallback: default platform behavior.
      if (!success) {
        try {
          success = await launchUrl(uri);
        } catch (_) {
          success = false;
        }
      }

      if (!success) {
        if (!mounted) return;
        setState(() {
          _error = tr(context, 'pdf_no_viewer');
          _launching = false;
        });
        return;
      }

      // Success — pop back to the material list after a brief delay so the
      // user sees the "Opening..." feedback before returning.
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _launching = false;
      });
    }
  }

  /// Manual launch — invoked from the AppBar action and the error CTA. Same
  /// fallback chain, but always shows the result via a SnackBar so the user
  /// gets feedback even on the manual path.
  Future<void> _manualLaunch() async {
    try {
      final uri = Uri.parse(widget.pdfUrl);
      bool success = false;
      try {
        success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        success = false;
      }
      if (!success) {
        try {
          success = await launchUrl(uri);
        } catch (_) {
          success = false;
        }
      }
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: L10nText('pdf_no_viewer')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Always-available manual fallback. If the auto-launch silently
        // fails (e.g. the system has no PDF viewer registered for the
        // https scheme), the user can tap this to retry with an explicit
        // external launch.
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: tr(context, 'pdf_open_in_browser'),
            onPressed: _manualLaunch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_launching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 24),
              L10nText(
                'pdf_opening',
                style: AppFonts.style(
                  size: 16,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              L10nText(
                'pdf_open_failed',
                style: AppFonts.style(
                  size: 18,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              L10nText(
                'pdf_open_manually',
                style: AppFonts.style(
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _launchPdf,
                    icon: const Icon(Icons.refresh),
                    label: L10nText('retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _manualLaunch,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: L10nText('pdf_open_in_browser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}

// =============================================================================
// ExamVault - PDF Viewer Screen
// =============================================================================
// Opens a study material PDF using the system's native PDF viewer (Chrome,
// Adobe Reader, etc.) via url_launcher. This approach was chosen after
// flutter_pdfview failed with a Gradle compatibility issue ("Could not get
// unknown property 'android' for project ':flutter_pdfview'") on Flutter
// 3.24.5 + recent AGP. Using url_launcher (already in pubspec) avoids all
// dependency/Gradle risk and works on every device — the system always has
// at least one app that can render a PDF (browser fallback).
//
// This screen shows a brief "Opening PDF..." loading state while the URL
// launcher resolves, then auto-pops back to the material list. If the launch
// fails (no PDF viewer installed), an error with a retry button is shown.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// falls back to inAppBrowserView (opens in an in-app browser tab).
  Future<void> _launchPdf() async {
    try {
      final uri = Uri.parse(widget.pdfUrl);
      bool success = false;

      // Try external app first (dedicated PDF viewer — best experience).
      if (await canLaunchUrl(uri)) {
        success = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      // Fallback: in-app browser view.
      if (!success) {
        success = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
      }

      // Fallback: default platform behavior.
      if (!success) {
        success = await launchUrl(uri);
      }

      if (!success) {
        setState(() {
          _error = 'No PDF viewer app found on this device.';
          _launching = false;
        });
        return;
      }

      // Success — pop back to the material list after a brief delay so the
      // user sees the "Opening..." feedback before returning.
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _launching = false;
        });
      }
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
              const Text(
                'Opening PDF...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not open PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _launching = true;
                    _error = null;
                  });
                  _launchPdf();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}

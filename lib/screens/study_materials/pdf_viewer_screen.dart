// =============================================================================
// ExamVault - PDF Viewer Screen
// =============================================================================
// Displays a study material PDF in-app using flutter_pdfview (Android's native
// PdfRenderer / iOS PDFKit — no AndroidX conflict, unlike the old pdf/printing
// generation packages).
//
// The PDF is downloaded to the app's temporary directory on first open, then
// displayed. On subsequent opens of the SAME material, the cached file is
// reused (instant open, works offline). The download progress is shown as a
// linear progress indicator.
//
// flutter_pdfview requires a LOCAL FILE PATH (not a URL), so we must download
// first. We use dio (already in pubspec) + path_provider for this.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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
  String? _localPath;
  bool _downloading = true;
  double _progress = 0;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndPrepare();
  }

  /// Downloads the PDF to a temp file (or reuses the cached copy if it
  /// already exists for this material). The file is keyed by materialId so
  /// re-opening the same material is instant and works offline.
  Future<void> _downloadAndPrepare() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/study_material_${widget.materialId}.pdf');

      // If the file already exists (cached), use it directly.
      if (await file.exists()) {
        setState(() {
          _localPath = file.path;
          _downloading = false;
        });
        return;
      }

      // Download with progress tracking.
      await Dio().download(
        widget.pdfUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          setState(() {
            _progress = received / total;
          });
        },
      );

      setState(() {
        _localPath = file.path;
        _downloading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _downloading = false;
      });
    }
  }

  /// Opens the PDF in the system's default PDF viewer (external app) as a
  /// fallback when the in-app viewer fails or the user prefers external.
  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF')),
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
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_downloading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _progress > 0
                    ? 'Loading PDF... ${(_progress * 100).toInt()}%'
                    : 'Loading PDF...',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              if (_progress > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _progress),
              ],
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
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _downloading = true;
                    _error = null;
                    _progress = 0;
                  });
                  _downloadAndPrepare();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in browser instead'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages, width, height) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          _error = error.toString();
        });
      },
      onPageError: (page, error) {
        // Non-fatal — a single page failing to render shouldn't crash.
      },
      onViewCreated: (controller) {
        // Controller is available for programmatic page navigation if needed.
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? _totalPages;
        });
      },
    );
  }
}

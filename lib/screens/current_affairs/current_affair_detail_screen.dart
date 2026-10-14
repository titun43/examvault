// =============================================================================
// ExamVault - Current Affair Detail Screen
// Opens when a single current-affair card is tapped on the Home screen (or from
// the full Current Affairs list). Shows the complete content for ONE affair:
// banner image, full title, date, source, category, important badge, complete
// body content, tags, and a PDF download / share action when available.
// Previously tapping a card on Home always opened the full "View All" list —
// this screen gives each affair its own dedicated detail page.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/current_affair_model.dart';
import '../../utils/share_helper.dart';
import '../../utils/localized_content.dart';

class CurrentAffairDetailScreen extends StatelessWidget {
  final CurrentAffairModel affair;
  const CurrentAffairDetailScreen({super.key, required this.affair});

  String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m - 1];
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  Future<void> _launchUrl(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link')));
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        final ok2 = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!ok2 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link')));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = affair.imageUrl != null && affair.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image (or gradient slab when no image is set).
          SliverAppBar(
            expandedHeight: hasImage ? 240 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: affair.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.primaryColor,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.primaryColor,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white70, size: 48),
                          ),
                        ),
                        // Dark scrim so the back button stays legible over
                        // busy photos.
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.35),
                                Colors.transparent,
                                Colors.black.withOpacity(0.25),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: affair.isImportant
                            ? AppTheme.accentGradient
                            : AppTheme.primaryGradient,
                      ),
                    ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black38,
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              // Share button — shares this affair's title, date, summary,
              // PDF link + the ExamVault Play Store URL. Always visible in
              // the pinned app bar.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black38,
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  tooltip: 'Share this affair',
                  onPressed: () {
                    ShareHelper.shareCurrentAffair(affair);
                  },
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta row: date + important badge + category
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _fmtDate(affair.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (affair.isImportant) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.priority_high,
                                  size: 12, color: AppTheme.accentColor),
                              const SizedBox(width: 2),
                              const Text(
                                'Important',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (affair.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            affair.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    lc(context, affair.title, affair.titleAs),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  if (affair.source.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Source: ${affair.source}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Summary card (highlighted)
                  if (affair.summary.isNotEmpty &&
                      affair.summary != affair.content) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb,
                                  size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              const Text(
                                'In Short',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lc(context, affair.summary, affair.summaryAs),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Full content
                  if (affair.content.isNotEmpty) ...[
                    const Text(
                      'Full Story',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lc(context, affair.content, affair.contentAs),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tags
                  if (affair.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: affair.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$t',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  if (affair.pdfUrl != null && affair.pdfUrl!.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchUrl(context, affair.pdfUrl),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text(
                          'Download PDF',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

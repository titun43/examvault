// =============================================================================
// ExamVault - Government Sources Screen
// =============================================================================
// Per Play Store Misleading Claims policy (Oct 15, 2026):
// Apps that provide government information must link to original .gov sources.
//
// This screen lists official exam-conducting body websites so users can
// verify information directly from the source.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class GovernmentSourcesScreen extends StatelessWidget {
  const GovernmentSourcesScreen({super.key});

  // Official exam-conducting body URLs (all .gov or official domains)
  static const List<Map<String, String>> _sources = [
    {
      'name': 'Staff Selection Commission (SSC)',
      'url': 'https://ssc.nic.in',
      'desc': 'Official SSC website — CGL, CHSL, MTS, GD notifications',
    },
    {
      'name': 'Union Public Service Commission (UPSC)',
      'url': 'https://www.upsc.gov.in',
      'desc': 'Official UPSC website — Civil Services, NDA, CDS',
    },
    {
      'name': 'Assam Public Service Commission (APSC)',
      'url': 'https://apsc.nic.in',
      'desc': 'Official APSC website — Assam Civil Service recruitment',
    },
    {
      'name': 'Assam Government (ADRE)',
      'url': 'https://assam.gov.in',
      'desc': 'Official Assam Govt portal — Direct Recruitment Examination',
    },
    {
      'name': 'Indian Railways',
      'url': 'https://indianrailways.gov.in',
      'desc': 'Official Railway site — RRB NTPC, Group D, ALP',
    },
    {
      'name': 'Railway Recruitment Boards',
      'url': 'https://rrbcdg.gov.in',
      'desc': 'Official RRB portal — recruitment notifications',
    },
    {
      'name': 'IBPS (Banking)',
      'url': 'https://www.ibps.in',
      'desc': 'Official IBPS website — PO, Clerk, RRBs',
    },
    {
      'name': 'State Bank of India (SBI)',
      'url': 'https://sbi.co.in/web/careers',
      'desc': 'Official SBI Careers — PO, Clerk, SO recruitment',
    },
    {
      'name': 'National Testing Agency (NTA)',
      'url': 'https://nta.ac.in',
      'desc': 'Official NTA website — NEET, JEE, CUET',
    },
    {
      'name': 'Ministry of Education',
      'url': 'https://www.education.gov.in',
      'desc': 'Official MoE — education policies, scholarships',
    },
  ];

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.loc;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.t('govSources')),
      ),
      body: Column(
        children: [
          // === DISCLAIMER BANNER ===
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.t('disclaimerTitle'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr.t('disclaimerBody'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // === SECTION HEADER ===
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr.t('officialSources'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // === SOURCES LIST ===
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final source = _sources[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified,
                          color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      source['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        source['desc']!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    trailing: const Icon(Icons.open_in_new,
                        color: AppColors.primary, size: 20),
                    onTap: () => _launchUrl(source['url']!),
                  ),
                );
              },
            ),
          ),

          // === FOOTER NOTE ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tr.t('sourcesFooterNote'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

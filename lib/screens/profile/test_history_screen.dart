// =============================================================================
// ExamVault - Test History Screen (Issue #20 rewrite)
// =============================================================================
// The original was a 65-line stub showing only title + "X/Y correct • Z%" +
// a PASSED/FAILED chip. It ignored 10+ rich fields on TestResultModel:
//   attemptedAt, obtainedMarks/totalMarks, accuracy, timeTaken, rank,
//   wrongAnswers, unattempted, totalTime, percentage.
//
// This rewrite shows a rich card per attempt with a colored score bar,
// all the key metrics, a filter chip row (All / Passed / Failed), and a
// "Re-attempt" button that navigates to TestInstructionsScreen.
//
// The Firestore query is unchanged (FirestoreService.getUserResultsStream),
// which streams the current user's results ordered by attemptedAt desc.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../models/test_result_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_state.dart';
import '../tests/test_instructions_screen.dart';

/// Filter enum for the chip row.
enum _HistoryFilter { all, passed, failed }

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: L10nText(
          'history_title',
          style: AppFonts.style(
            size: 20,
            weight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: StreamBuilder<List<TestResultModel>>(
        stream: FirestoreService.getUserResultsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              titleText: tr(context, 'error'),
              descText: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          final allResults = snapshot.data ?? [];
          if (allResults.isEmpty) {
            return EmptyState(
              icon: Icons.history_rounded,
              l10nTitleKey: 'history_empty_title',
              l10nDescKey: 'history_empty_msg',
            );
          }

          // Apply the active filter.
          final filtered = allResults.where(_matchesFilter).toList();

          return Column(
            children: [
              // ---- Filter chip row ----
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd, AppTheme.spaceMd, AppTheme.spaceMd, 0),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(_HistoryFilter.all,
                          tr(context, 'history_filter_all'), allResults.length),
                      const SizedBox(width: AppTheme.spaceSm),
                      _buildFilterChip(
                          _HistoryFilter.passed,
                          tr(context, 'history_filter_passed'),
                          allResults.where((r) => r.isPassed).length),
                      const SizedBox(width: AppTheme.spaceSm),
                      _buildFilterChip(
                          _HistoryFilter.failed,
                          tr(context, 'history_filter_failed'),
                          allResults.where((r) => !r.isPassed).length),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              // ---- Results list ----
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        titleText: tr(context, 'history_no_results'),
                        iconColor: AppTheme.warningColor,
                        circleSize: 72,
                        iconSize: 32,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            AppTheme.spaceMd,
                            AppTheme.spaceSm,
                            AppTheme.spaceMd,
                            AppTheme.spaceLg),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildResultCard(filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matchesFilter(TestResultModel r) {
    switch (_filter) {
      case _HistoryFilter.all:
        return true;
      case _HistoryFilter.passed:
        return r.isPassed;
      case _HistoryFilter.failed:
        return !r.isPassed;
    }
  }

  Widget _buildFilterChip(
      _HistoryFilter value, String label, int count) {
    final selected = _filter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: selected
            ? AppTheme.primaryColor
            : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildResultCard(TestResultModel result) {
    // Score percentage for the colored bar. Prefer the model's `percentage`
    // field (already computed server-side); fall back to a client-side
    // calculation from obtainedMarks/totalMarks.
    final double pct = result.percentage > 0
        ? result.percentage
        : (result.totalMarks > 0
            ? (result.obtainedMarks / result.totalMarks) * 100
            : 0);

    // Color bands: red < 40%, amber 40-60%, green > 60%.
    final Color barColor = pct < 40
        ? AppTheme.errorColor
        : pct <= 60
            ? AppTheme.warningColor
            : AppTheme.successColor;

    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFmt.format(result.attemptedAt.toLocal());

    // Format timeTaken (seconds) as mm:ss.
    final mins = (result.timeTaken ~/ 60).toString().padLeft(2, '0');
    final secs = (result.timeTaken % 60).toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header row: title + passed/failed badge ----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.testTitle.isNotEmpty
                        ? result.testTitle
                        : tr(context, 'history_no_results'),
                    style: AppFonts.style(
                      size: 16,
                      weight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.isPassed
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    result.isPassed
                        ? tr(context, 'history_filter_passed').toUpperCase()
                        : tr(context, 'history_filter_failed').toUpperCase(),
                    style: AppFonts.style(
                      size: 10,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXs),
            // ---- Date ----
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    formattedDate,
                    style: AppFonts.style(
                        size: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            // ---- Score bar ----
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            // ---- Metrics row ----
            Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: AppTheme.spaceXs,
              children: [
                _MetricChip(
                  icon: Icons.star_rounded,
                  label: tr(context, 'history_score'),
                  value: '${result.obtainedMarks}/${result.totalMarks}',
                  color: barColor,
                ),
                _MetricChip(
                  icon: Icons.percent_rounded,
                  label: tr(context, 'history_accuracy'),
                  value: '${result.accuracy.toStringAsFixed(1)}%',
                  color: AppTheme.primaryColor,
                ),
                _MetricChip(
                  icon: Icons.timer_outlined,
                  label: tr(context, 'history_time_taken'),
                  value: '$mins:$secs',
                  color: AppTheme.accentColor,
                ),
                if (result.rank > 0)
                  _MetricChip(
                    icon: Icons.emoji_events_outlined,
                    label: tr(context, 'history_rank'),
                    value: '#${result.rank}',
                    color: AppTheme.warningColor,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            // ---- Re-attempt button ----
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _reattemptTest(result),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: L10nText('history_reattempt'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
                  side: BorderSide(color: AppTheme.primaryColor),
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fetches the test by testId and navigates to TestInstructionsScreen.
  /// Mirrors the pattern used in bookmarks_screen._openBookmarkedTest: show
  /// a loading SnackBar, fetch the test, navigate (or show a not-found
  /// SnackBar if the test was deleted).
  Future<void> _reattemptTest(TestResultModel result) async {
    if (result.testId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: L10nText('history_loading_test'),
        duration: const Duration(seconds: 10),
      ),
    );
    try {
      final test = await FirestoreService.getTest(result.testId);
      messenger.hideCurrentSnackBar();
      if (test == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: L10nText('history_test_not_found')),
        );
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestInstructionsScreen(test: test),
        ),
      );
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: L10nText('history_test_not_found')),
      );
    }
  }
}

// =============================================================================
// METRIC CHIP — small label/value pair shown in the metrics row
// =============================================================================
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: AppFonts.style(
                size: 11, color: Colors.grey.shade600, weight: FontWeight.w500),
          ),
          Text(
            value,
            style: AppFonts.style(
                size: 12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

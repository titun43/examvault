// =============================================================================
// ExamVault - Leaderboard Screen
// =============================================================================
// BUGFIX (offline + post-logout): Previously used a raw StreamBuilder that
// showed an infinite CircularProgressIndicator when the stream was in the
// "waiting" state — which happened every time the user logged out (the app
// navigates to a fresh MainNavigation, re-creating this screen and its
// stream) OR when the device was offline. The user saw a spinner that never
// resolved, making it look like the Ranks tab "went away" after logout or
// that the app "doesn't work offline".
//
// Now uses OfflineAwareStreamBuilder which:
//   1. Shows cached data IMMEDIATELY if available (even while the stream is
//      re-validating against the server) — so the Ranks tab shows the
//      leaderboard instantly after logout instead of a spinner.
//   2. Shows a friendly "You appear to be offline" message with a Retry
//      button when there is no cached data AND the stream can't reach the
//      server — instead of an infinite spinner.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../models/leaderboard_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/offline_aware_stream_builder.dart';
import '../search/search_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: L10nText(
            'leaderboard_title',
            style: AppFonts.style(
              size: 20,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            // Global search — available on every bottom-nav tab, not just Home.
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: tr(context, 'search'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: AppTheme.accentColor,
            indicatorWeight: 3,
            labelStyle: AppFonts.style(
                size: 14, weight: FontWeight.w600),
            unselectedLabelStyle: AppFonts.style(
                size: 14, weight: FontWeight.w500),
            tabs: [
              Tab(text: tr(context, 'leaderboard_weekly')),
              Tab(text: tr(context, 'leaderboard_monthly')),
              Tab(text: tr(context, 'leaderboard_allTime')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLeaderboard(context, LeaderboardType.weekly),
            _buildLeaderboard(context, LeaderboardType.monthly),
            _buildLeaderboard(context, LeaderboardType.allTime),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context, LeaderboardType type) {
    final currentUserId = Provider.of<AuthProvider>(context).user?.id;

    // BUGFIX: use OfflineAwareStreamBuilder instead of raw StreamBuilder.
    // This shows cached data immediately (fixing the post-logout spinner)
    // and shows a friendly offline message instead of an infinite spinner
    // when the device has no connectivity and no cached data.
    return OfflineAwareStreamBuilder<List<LeaderboardModel>>(
      stream: FirestoreService.getLeaderboardStream(type: type),
      dataBuilder: (context, leaderboard, isStale) {
        if (leaderboard.isEmpty) {
          return _buildEmptyState(context);
        }
        return Column(
          children: [
            // Stale-data badge — shown when the data is from cache (stream
            // is waiting/errored). Lets the user know they might be seeing
            // slightly outdated rankings (e.g. offline or reconnecting).
            if (isStale) _buildStaleBanner(context),
            // Top 3
            if (leaderboard.length >= 3) _buildTopThree(context, leaderboard),
            // List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(AppTheme.spaceLg),
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  final entry = leaderboard[index];
                  final isCurrentUser = entry.userId == currentUserId;
                  return _buildRankCard(context, entry, isCurrentUser)
                      .animate()
                      .fadeIn(
                        duration: 300.ms,
                        delay: (index * 40).ms,
                      );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Slim banner shown above the leaderboard when the displayed data is from
  /// cache (stream is waiting/errored). Reassures the user that the rankings
  /// they see might be slightly stale.
  Widget _buildStaleBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
      color: AppTheme.warningColor.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppTheme.warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: L10nText(
              'leaderboard_stale',
              style: AppFonts.style(
                size: 12,
                weight: FontWeight.w500,
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Illustrated empty state when there is no leaderboard data.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: AppTheme.spaceLg),
            L10nText(
              'leaderboard_empty',
              style: AppFonts.style(
                size: 15,
                weight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildTopThree(BuildContext context, List<LeaderboardModel> leaderboard) {
    final top3 = leaderboard.take(3).toList();
    return Container(
      padding: EdgeInsets.all(AppTheme.spaceXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          _buildTopPlayer(top3[1], 2, 80)
              .animate()
              .fadeIn(delay: 100.ms, duration: 450.ms)
              .slideY(begin: 0.2)
              .scale(begin: const Offset(0.9, 0.9)),
          // 1st place
          _buildTopPlayer(top3[0], 1, 100)
              .animate()
              .fadeIn(delay: 180.ms, duration: 450.ms)
              .slideY(begin: 0.25)
              .scale(begin: const Offset(0.85, 0.85)),
          // 3rd place
          _buildTopPlayer(top3[2], 3, 70)
              .animate()
              .fadeIn(delay: 260.ms, duration: 450.ms)
              .slideY(begin: 0.2)
              .scale(begin: const Offset(0.9, 0.9)),
        ],
      ),
    );
  }

  Widget _buildTopPlayer(LeaderboardModel player, int rank, double height) {
    // Medal palette — gold (amber), silver (slate), bronze (orange).
    // Uses the Assam theme tokens so it harmonizes with the emerald brand
    // gradient instead of the old Material-2 raw Colors.yellow.
    final colors = [
      AppTheme.accentColor,            // 1st — gold/amber
      const Color(0xFF94A3B8),         // 2nd — slate 400 (silver)
      const Color(0xFFEA580C),         // 3rd — orange 600 (bronze)
    ];
    final rankLabels = ['1st', '2nd', '3rd'];
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors[rank - 1],
              child: player.userPhoto != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: player.userPhoto!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors[rank - 1],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: AppTheme.softShadow1,
                ),
                child: Text(
                  rankLabels[rank - 1],
                  style: AppFonts.style(
                    size: 10,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spaceSm),
        Text(
          player.userName,
          style: AppFonts.style(
            color: Colors.white,
            size: 12,
            weight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${player.totalXp} XP',
          style: AppFonts.style(
            color: Colors.white.withValues(alpha: 0.9),
            size: 11,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(BuildContext context, LeaderboardModel entry, bool isCurrentUser) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
        boxShadow: AppTheme.softShadow1,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${entry.rank}',
              style: AppFonts.style(
                size: 18,
                weight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: AppTheme.spaceMd),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            child: entry.userPhoto != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: entry.userPhoto!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person, color: AppTheme.primaryColor),
          ),
          SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.userName,
                        style: AppFonts.style(
                          weight: FontWeight.w600,
                          size: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: AppTheme.spaceSm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: L10nText(
                          'leaderboard_you',
                          style: AppFonts.style(
                            size: 9,
                            weight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '${entry.totalTestsAttempted} ${tr(context, 'leaderboard_tests')} • ${entry.averageScore.toStringAsFixed(1)}% ${tr(context, 'leaderboard_avg')}',
                  style: AppFonts.style(
                    size: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalXp}',
                style: AppFonts.style(
                  weight: FontWeight.w700,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                'XP',
                style: AppFonts.style(
                  size: 10,
                  weight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              // Streak chip — only shown when the user has a streak of at
              // least 1 day.
              if (entry.streak > 0) ...[
                SizedBox(height: AppTheme.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 11,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.streak}',
                        style: AppFonts.style(
                          size: 10,
                          color: AppTheme.accentColor,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

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
import '../../theme/app_theme.dart';
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
          title: const Text('Leaderboard'),
          actions: [
            // Global search — available on every bottom-nav tab, not just Home.
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
              Tab(text: 'All Time'),
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
          return const Center(child: Text('No leaderboard data available'));
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
                padding: const EdgeInsets.all(16),
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  final entry = leaderboard[index];
                  final isCurrentUser = entry.userId == currentUserId;
                  return _buildRankCard(context, entry, isCurrentUser);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached rankings — reconnect to refresh.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(BuildContext context, List<LeaderboardModel> leaderboard) {
    final top3 = leaderboard.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.brandGradient,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          _buildTopPlayer(top3[1], 2, 80),
          // 1st place
          _buildTopPlayer(top3[0], 1, 100),
          // 3rd place
          _buildTopPlayer(top3[2], 3, 70),
        ],
      ),
    );
  }

  Widget _buildTopPlayer(LeaderboardModel player, int rank, double height) {
    final colors = [
      Colors.yellow, // 1st
      Colors.grey.shade300, // 2nd
      Colors.orange.shade300, // 3rd
    ];
    return Column(
      children: [
        Stack(
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
                ),
                child: Text(
                  rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          player.userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${player.totalXp} XP',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(BuildContext context, LeaderboardModel entry, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryColor, width: 2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${entry.rank}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: entry.userPhoto != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: entry.userPhoto!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${entry.totalTestsAttempted} tests • ${entry.averageScore.toStringAsFixed(1)}% avg',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              // Streak chip — only shown when the user has a streak of at
              // least 1 day. Leaderboard entries are refreshed after every
              // test submission, so the stored streak value is reasonably
              // fresh (no client-side staleness computation needed here).
              if (entry.streak > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
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
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w700,
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

// =============================================================================
// ExamVault - Leaderboard Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/leaderboard_model.dart';
import '../../services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
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

    return StreamBuilder<List<LeaderboardModel>>(
      stream: FirestoreService.getLeaderboardStream(type: type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No leaderboard data available'));
        }
        final leaderboard = snapshot.data!;

        return Column(
          children: [
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

  Widget _buildTopThree(BuildContext context, List<LeaderboardModel> leaderboard) {
    final top3 = leaderboard.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF003C8F)],
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
            ],
          ),
        ],
      ),
    );
  }
}

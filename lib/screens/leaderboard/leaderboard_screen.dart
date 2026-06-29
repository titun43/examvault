// =============================================================================
// ExamVault - Leaderboard Screen (offline — computed from local users+results)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';

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
            _buildLeaderboard(context),
            _buildLeaderboard(context),
            _buildLeaderboard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).user?.id;
    final users = LocalDataService.getAllUsers()
        .where((u) => u.role == 'student')
        .toList();
    final entries = <_LeaderEntry>[];
    for (final u in users) {
      final results = LocalDataService.resultsByUser(u.id);
      final totalScore = results.fold<int>(0, (s, r) => s + r.score);
      final totalMax = results.fold<int>(0, (s, r) => s + r.total);
      final attempted = results.length;
      final avg = totalMax > 0 ? (totalScore / totalMax) * 100 : 0.0;
      entries.add(_LeaderEntry(
        userId: u.id,
        userName: u.name,
        totalXp: totalScore,
        totalTestsAttempted: attempted,
        averageScore: avg,
      ));
    }
    entries.sort((a, b) => b.totalXp.compareTo(a.totalXp));
    for (var i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(rank: i + 1);
    }

    if (entries.isEmpty) {
      return const Center(child: Text('No leaderboard data available'));
    }

    return Column(
      children: [
        if (entries.length >= 3) _buildTopThree(entries),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isCurrentUser = entry.userId == currentUserId;
              return _buildRankCard(context, entry, isCurrentUser);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopThree(List<_LeaderEntry> leaderboard) {
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
          _buildTopPlayer(top3[1], 2, 80),
          _buildTopPlayer(top3[0], 1, 100),
          _buildTopPlayer(top3[2], 3, 70),
        ],
      ),
    );
  }

  Widget _buildTopPlayer(_LeaderEntry player, int rank, double height) {
    final colors = [
      Colors.yellow,
      Colors.grey.shade300,
      Colors.orange.shade300,
    ];
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors[rank - 1],
              child: const Icon(Icons.person, color: Colors.white),
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

  Widget _buildRankCard(
      BuildContext context, _LeaderEntry entry, bool isCurrentUser) {
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
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderEntry {
  final String userId;
  final String userName;
  final int totalXp;
  final int totalTestsAttempted;
  final double averageScore;
  final int rank;

  _LeaderEntry({
    required this.userId,
    required this.userName,
    required this.totalXp,
    required this.totalTestsAttempted,
    required this.averageScore,
    this.rank = 0,
  });

  _LeaderEntry copyWith({int? rank}) => _LeaderEntry(
        userId: userId,
        userName: userName,
        totalXp: totalXp,
        totalTestsAttempted: totalTestsAttempted,
        averageScore: averageScore,
        rank: rank ?? this.rank,
      );
}

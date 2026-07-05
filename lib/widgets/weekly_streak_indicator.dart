// =============================================================================
// ExamVault - Weekly Streak Indicator
// A compact 7-dot row (Mon→Sun) showing which days of the current week the
// user has been active on. Used on the Profile screen and the Daily Quiz
// screen to give a quick visual sense of consistency.
//
// We only render a "filled" dot when we can prove activity happened on that
// day (see streak_helper.weeklyActivityForCurrentUser). Days with no
// recorded activity render as an empty ring so the user can see at a glance
// which days they still need to cover this week.
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/streak_helper.dart';

class WeeklyStreakIndicator extends StatelessWidget {
  /// Raw flags for Mon→Sun. If null, computed from [lastActiveAt].
  final List<bool>? activity;
  final DateTime? lastActiveAt;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? labelColor;
  final double dotSize;

  const WeeklyStreakIndicator({
    super.key,
    this.activity,
    this.lastActiveAt,
    this.activeColor,
    this.inactiveColor,
    this.labelColor,
    this.dotSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final flags = activity ?? weeklyActivityForCurrentUser(lastActiveAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = activeColor ?? AppTheme.accentColor;
    final inactive = inactiveColor ??
        (isDark ? Colors.white24 : Colors.grey.shade300);
    final labels = labelColor ??
        (isDark ? Colors.white60 : Colors.grey.shade600);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isActive = i < flags.length && flags[i];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? active : Colors.transparent,
                border: Border.all(
                  color: isActive ? active : inactive,
                  width: isActive ? 0 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isActive
                  ? const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 16,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Text(
              streakWeekdayLabels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? active : labels,
              ),
            ),
          ],
        );
      }),
    );
  }
}

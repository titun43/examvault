// =============================================================================
// ExamVault - Streak Helper
// Centralizes daily-streak computation so the profile screen, daily quiz
// screen, and any future surface all agree on what "current streak" means.
//
// Background: the `users/{uid}.streak` field in Firestore is only updated when
// a test is submitted (see FirestoreService.updateUserStatsAfterTest). That
// means a user who had a 7-day streak and then skipped 3 days would still see
// "7🔥" on their profile until they submit another test (at which point the
// server would reset it to 1). This helper computes the *effective* streak
// from `streak` + `lastActiveAt` so the displayed value is always correct,
// even when the user has been inactive.
// =============================================================================

/// Returns the effective current streak for a user, given the raw stored
/// `streak` value and the `lastActiveAt` timestamp from Firestore.
///
/// Rules:
///   - lastActiveAt == null              → 0  (never active)
///   - lastActiveAt is today             → stored streak
///   - lastActiveAt is yesterday         → stored streak (still alive today)
///   - lastActiveAt is >1 day ago        → 0  (broken — not yet reset on server)
///   - stored streak is 0                → 0  (regardless)
int computeEffectiveStreak(int storedStreak, DateTime? lastActiveAt) {
  if (storedStreak <= 0) return 0;
  if (lastActiveAt == null) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(lastActiveAt.year, lastActiveAt.month, lastActiveAt.day);
  final diffInDays = today.difference(last).inDays;

  if (diffInDays <= 1) {
    // Today or yesterday — streak is still alive.
    return storedStreak;
  }
  // More than 1 day gap — streak is broken. The server will reset to 1 on
  // the next test submission, but until then we show 0 so the user isn't
  // misled by a stale number.
  return 0;
}

/// Returns true if the user has been active today (i.e. submitted at least
/// one test today). Used to decide whether to show "keep it going" vs
/// "take today's quiz to keep your streak" messaging.
bool wasActiveToday(DateTime? lastActiveAt) {
  if (lastActiveAt == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(lastActiveAt.year, lastActiveAt.month, lastActiveAt.day);
  return today.difference(last).inDays == 0;
}

/// Returns a short human-readable label describing the streak state, used on
/// the daily quiz motivational card.
String streakMessage(int effectiveStreak, DateTime? lastActiveAt) {
  final activeToday = wasActiveToday(lastActiveAt);
  if (effectiveStreak == 0) {
    return activeToday
        ? "Great start! Take a quiz to begin a streak."
        : "Take today's quiz to start a new streak.";
  }
  if (activeToday) {
    return "You're on fire! Come back tomorrow to extend it.";
  }
  return "Take today's quiz to keep your streak alive.";
}

/// Returns a list of 7 booleans (Monday → Sunday) for the current week,
/// where `true` means the user was active (submitted a test) on that day.
///
/// Activity is inferred from `lastActiveAt` for the current day only — we
/// don't have a per-day history on the user doc, so this is a conservative
/// approximation: only today's activity is known for sure. Days that have
/// already passed this week without `lastActiveAt` landing on them are shown
/// as inactive. This keeps the indicator honest (we never show a "filled"
/// dot for a day we can't prove activity happened).
List<bool> weeklyActivityForCurrentUser(DateTime? lastActiveAt) {
  // Monday=0 .. Sunday=6
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayIndex = now.weekday - 1; // 1=Mon → 0
  final flags = List<bool>.filled(7, false);
  if (lastActiveAt == null) return flags;
  final last = DateTime(lastActiveAt.year, lastActiveAt.month, lastActiveAt.day);
  final diff = today.difference(last).inDays;
  // Only mark today if lastActiveAt is today.
  if (diff == 0) {
    flags[todayIndex] = true;
  }
  return flags;
}

/// Short weekday labels matching [weeklyActivityForCurrentUser] order.
const List<String> streakWeekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

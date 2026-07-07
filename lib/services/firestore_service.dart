// =============================================================================
// ExamVault - Firestore Service (CRUD operations for all collections)
// =============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../models/subject_model.dart';
import '../models/test_model.dart';
import '../models/question_model.dart';
import '../models/test_result_model.dart';
import '../models/current_affair_model.dart';
import '../models/notification_model.dart';
import '../models/leaderboard_model.dart';
import '../models/announcement_model.dart';
import '../models/upcoming_exam_model.dart';
import '../models/banner_model.dart';
import '../models/app_open_banner_model.dart';
import '../models/premium_plan_model.dart';
import 'firebase_service.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseService.firestore;

  // ==================== CATEGORIES ====================
  // IMPORTANT: We do NOT use .orderBy('order') server-side because Firestore's
  // orderBy SKIPS documents that are missing the field — so a category
  // created without an `order` field would silently disappear from the user
  // app. Instead we fetch all and sort client-side.
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _db.collection('categories').get();
      final docs = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
      docs.sort((a, b) => a.order.compareTo(b.order));
      return docs;
    } catch (e) {
      print('getCategories error: $e');
      return [];
    }
  }

  static Stream<List<CategoryModel>> getCategoriesStream() {
    return _db.collection('categories')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();
          docs.sort((a, b) => a.order.compareTo(b.order));
          return docs;
        });
  }

  static Future<String?> addCategory(CategoryModel category) async {
    final docRef = await _db.collection('categories').add(category.toFirestore());
    return docRef.id;
  }

  static Future<void> updateCategory(CategoryModel category) async {
    await _db.collection('categories').doc(category.id).update(category.toFirestore());
  }

  static Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  // ==================== SUBJECTS ====================
  // IMPORTANT: We use ONLY single-field filters (categoryId) and sort
  // client-side by `order`. Combining .orderBy('order') + .where('categoryId')
  // requires a COMPOSITE INDEX that is not configured in Firestore, which
  // silently breaks the stream → user sees "No subjects available". This
  // mirrors the pattern already used for tests/questions/announcements.
  //
  // ROBUST MATCHING: The admin may have created subjects in the Firestore
  // console using the category's document ID, its NAME (e.g. "Indian
  // Railways"), or its SLUG (e.g. "indian-railways") as the `categoryId`
  // value. To cover all three cases we query the top-level `subjects`
  // collection once for each candidate value and merge the results. This is
  // what fixes the "no subject available" bug under Indian Railways.
  static Future<List<SubjectModel>> getSubjects({
    String? categoryId,
    String? categoryName,
    String? categorySlug,
  }) async {
    try {
      // No category context → return all subjects.
      if (categoryId == null && categoryName == null && categorySlug == null) {
        final snapshot = await _db.collection('subjects').get();
        var docs = snapshot.docs
            .map((doc) => SubjectModel.fromFirestore(doc))
            .toList();
        docs.sort((a, b) => a.order.compareTo(b.order));
        return docs;
      }

      // Build the set of candidate categoryId values to match against.
      // De-dup + ignore empties so we don't fire redundant queries.
      final candidates = <String>{
        if (categoryId != null && categoryId.isNotEmpty) categoryId,
        if (categoryName != null && categoryName.isNotEmpty) categoryName,
        if (categorySlug != null && categorySlug.isNotEmpty) categorySlug,
      }.toList();

      final seen = <String>{};
      final docs = <SubjectModel>[];

      // Query the top-level `subjects` collection for each candidate value.
      for (final cand in candidates) {
        try {
          final snapshot = await _db
              .collection('subjects')
              .where('categoryId', isEqualTo: cand)
              .get();
          for (final doc in snapshot.docs) {
            final s = SubjectModel.fromFirestore(doc);
            if (!seen.contains(s.id)) {
              seen.add(s.id);
              docs.add(s);
            }
          }
        } catch (e) {
          print('getSubjects query for "$cand" error: $e');
        }
      }

      // Fallback: also check the subcollection categories/{catId}/subjects
      // (legacy/admin writes may land there). Only need to do this for the
      // real document id, not for name/slug.
      if (categoryId != null && categoryId.isNotEmpty) {
        try {
          final subSnapshot = await _db
              .collection('categories')
              .doc(categoryId)
              .collection('subjects')
              .get();
          for (final doc in subSnapshot.docs) {
            final s = SubjectModel.fromFirestore(doc);
            if (!seen.contains(s.id)) {
              seen.add(s.id);
              docs.add(s);
            }
          }
        } catch (_) {
          // Subcollection may not exist or may be blocked — ignore.
        }
      }

      docs.sort((a, b) => a.order.compareTo(b.order));
      return docs;
    } catch (e) {
      print('getSubjects error: $e');
      return [];
    }
  }

  static Stream<List<SubjectModel>> getSubjectsStream({
    String? categoryId,
    String? categoryName,
    String? categorySlug,
  }) {
    // Build the list of candidate categoryId values to match against.
    final candidates = <String>{
      if (categoryId != null && categoryId.isNotEmpty) categoryId,
      if (categoryName != null && categoryName.isNotEmpty) categoryName,
      if (categorySlug != null && categorySlug.isNotEmpty) categorySlug,
    }.toList();

    // No category context at all → just stream all subjects.
    if (candidates.isEmpty) {
      try {
        return _db.collection('subjects').snapshots().map((snapshot) {
          var docs = snapshot.docs
              .map((doc) => SubjectModel.fromFirestore(doc))
              .toList();
          docs.sort((a, b) => a.order.compareTo(b.order));
          return docs;
        }).handleError((e) {
          print('getSubjectsStream(all) error: $e');
        });
      } catch (e) {
        return Stream.value(<SubjectModel>[]);
      }
    }

    // A single top-level subjects query stream for one candidate value.
    Stream<List<SubjectModel>> topLevelFor(String cand) {
      try {
        return _db
            .collection('subjects')
            .where('categoryId', isEqualTo: cand)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs
              .map((doc) => SubjectModel.fromFirestore(doc))
              .toList();
        }).handleError((e) {
          print('getSubjectsStream(top-level "$cand") error: $e');
        });
      } catch (e) {
        return Stream.value(<SubjectModel>[]);
      }
    }

    // Subcollection stream categories/{catId}/subjects (only for the real id).
    Stream<List<SubjectModel>> subCollection() {
      if (categoryId == null || categoryId.isEmpty) {
        return Stream.value(<SubjectModel>[]);
      }
      try {
        return _db
            .collection('categories')
            .doc(categoryId)
            .collection('subjects')
            .snapshots()
            .map((snapshot) {
          return snapshot.docs
              .map((doc) => SubjectModel.fromFirestore(doc))
              .toList();
        }).handleError((e) {
          // Subcollection may not exist or may be blocked — emit empty.
          print('getSubjectsStream(subcollection) info: $e');
        });
      } catch (e) {
        return Stream.value(<SubjectModel>[]);
      }
    }

    // Merge all source streams (one per candidate + the subcollection),
    // de-dup by id, and sort by order. Uses a controller-based merger so we
    // don't need an rxdart dependency. The user sees subjects regardless of
    // whether the admin wrote categoryId as the doc id, the name, or the slug.
    final controller = StreamController<List<SubjectModel>>();
    final latest = List<List<SubjectModel>>.filled(
        candidates.length + 1, const <SubjectModel>[]);
    bool closed = false;

    void emitMerged() {
      if (closed) return;
      final seen = <String>{};
      final combined = <SubjectModel>[];
      for (final list in latest) {
        for (final s in list) {
          if (!seen.contains(s.id)) {
            seen.add(s.id);
            combined.add(s);
          }
        }
      }
      combined.sort((a, b) => a.order.compareTo(b.order));
      controller.add(combined);
    }

    // Emit an initial empty list so the StreamBuilder doesn't hang in
    // "waiting" forever if all source streams error before emitting.
    controller.add(const []);

    final subs = <StreamSubscription>[];
    for (var i = 0; i < candidates.length; i++) {
      final idx = i;
      subs.add(topLevelFor(candidates[i]).listen(
        (data) {
          latest[idx] = data;
          emitMerged();
        },
        onError: (e) {
          latest[idx] = const [];
          emitMerged();
        },
      ));
    }
    // Subcollection is the last slot.
    subs.add(subCollection().listen(
      (data) {
        latest[candidates.length] = data;
        emitMerged();
      },
      onError: (e) {
        latest[candidates.length] = const [];
        emitMerged();
      },
    ));

    controller.onCancel = () {
      closed = true;
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  static Future<String?> addSubject(SubjectModel subject) async {
    final docRef = await _db.collection('subjects').add(subject.toFirestore());
    return docRef.id;
  }

  /// Fetch a single subject by its Firestore document id. Returns null if the
  /// subject doesn't exist or the read fails. Used by TakeTestScreen to
  /// resolve the categoryId for a test (TestModel only has subjectId, not
  /// categoryId) so the backend's exam-pack access tier can be checked.
  static Future<SubjectModel?> getSubjectById(String id) async {
    if (id.isEmpty) return null;
    try {
      final doc = await _db.collection('subjects').doc(id).get();
      if (!doc.exists) return null;
      return SubjectModel.fromFirestore(doc);
    } catch (e) {
      print('getSubjectById($id) error: $e');
      return null;
    }
  }

  static Future<void> updateSubject(SubjectModel subject) async {
    await _db.collection('subjects').doc(subject.id).update(subject.toFirestore());
  }

  static Future<void> deleteSubject(String id) async {
    await _db.collection('subjects').doc(id).delete();
  }

  // ==================== TESTS ====================
  static Future<List<TestModel>> getTests({
    String? subjectId,
    String? categoryId,
    TestType? type,
    bool? isPublished,
  }) async {
    try {
      // IMPORTANT: Avoid combining .orderBy() with .where() — that requires a
      // composite index which may not exist. Use single-field filter only and
      // sort client-side. This is the root cause of the "could not load search
      // data" error in the SearchScreen (the orderBy+where combo threw an
      // error that Future.wait propagated up because there was no try/catch).
      Query query = _db.collection('tests');
      // Prefer the most selective single filter to stay within auto-index limits.
      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      } else if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      } else if (isPublished != null) {
        query = query.where('isPublished', isEqualTo: isPublished);
      }

      final snapshot = await query.get();
      var docs = snapshot.docs.map((doc) => TestModel.fromFirestore(doc)).toList();
      // Client-side filters for remaining conditions
      if (type != null && subjectId != null) {
        docs = docs.where((t) => t.type == type).toList();
      }
      if (isPublished != null) {
        docs = docs.where((t) => t.isPublished == isPublished).toList();
      }
      // Sort client-side by createdAt desc
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    } catch (e) {
      print('getTests error: $e');
      return [];
    }
  }

  static Stream<List<TestModel>> getTestsStream({
    String? subjectId,
    TestType? type,
    bool? isPublished,
  }) {
    // Use ONLY single-field filters to avoid composite index requirements.
    // Firestore auto-creates single-field indexes, so this works without
    // manual index setup. We filter+sort client-side for the rest.
    Query query = _db.collection('tests');
    // Prefer the most selective single filter:
    if (subjectId != null) {
      query = query.where('subjectId', isEqualTo: subjectId);
    } else if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    } else if (isPublished != null) {
      query = query.where('isPublished', isEqualTo: isPublished);
    }

    return query.snapshots().map((snapshot) {
      var docs = snapshot.docs.map((doc) => TestModel.fromFirestore(doc)).toList();
      // Client-side filters for remaining conditions
      if (type != null && subjectId != null) {
        docs = docs.where((t) => t.type == type).toList();
      }
      if (isPublished != null) {
        docs = docs.where((t) => t.isPublished == isPublished).toList();
      }
      // Sort by createdAt desc (client-side)
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    }).handleError((e) {
      print('getTestsStream error: $e');
    });
  }

  static Future<TestModel?> getTest(String id) async {
    final doc = await _db.collection('tests').doc(id).get();
    if (!doc.exists) return null;
    return TestModel.fromFirestore(doc);
  }

  static Future<String?> addTest(TestModel test) async {
    final docRef = await _db.collection('tests').add(test.toFirestore());
    return docRef.id;
  }

  static Future<void> updateTest(TestModel test) async {
    await _db.collection('tests').doc(test.id).update(test.toFirestore());
  }

  static Future<void> deleteTest(String id) async {
    await _db.collection('tests').doc(id).delete();
  }

  /// Atomically increments the `attemptCount` field on a test document by 1.
  /// Called after a user submits a test so the "N attempts" counter on test
  /// cards reflects real engagement. Uses FieldValue.increment so concurrent
  /// submissions never overwrite each other (race-safe). The field is created
  /// if it doesn't exist yet. Best-effort — callers wrap in try/catch.
  static Future<void> incrementAttemptCount(String testId) async {
    await _db.collection('tests').doc(testId).update({
      'attemptCount': FieldValue.increment(1),
    });
  }

  // ==================== QUESTIONS ====================
  static Future<List<QuestionModel>> getQuestions(String testId) async {
    try {
      // Single-field filter only (testId) — sort client-side to avoid the
      // composite index requirement (testId + createdAt).
      final snapshot = await _db.collection('questions')
          .where('testId', isEqualTo: testId)
          .get();
      final docs = snapshot.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();
      docs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return docs;
    } catch (e) {
      print('getQuestions error: $e');
      return [];
    }
  }

  static Stream<List<QuestionModel>> getQuestionsStream(String testId) {
    // Single-field filter only (testId) — sort client-side to avoid the
    // composite index requirement (testId + createdAt).
    return _db.collection('questions')
        .where('testId', isEqualTo: testId)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return docs;
        })
        .handleError((e) {
          print('getQuestionsStream error: $e');
        });
  }

  static Future<String?> addQuestion(QuestionModel question) async {
    final docRef = await _db.collection('questions').add(question.toFirestore());
    return docRef.id;
  }

  static Future<void> updateQuestion(QuestionModel question) async {
    await _db.collection('questions').doc(question.id).update(question.toFirestore());
  }

  static Future<void> deleteQuestion(String id) async {
    await _db.collection('questions').doc(id).delete();
  }

  // ==================== TEST RESULTS ====================
  static Future<List<TestResultModel>> getUserResults(String userId) async {
    try {
      final snapshot = await _db.collection('results')
          .where('userId', isEqualTo: userId)
          .orderBy('attemptedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => TestResultModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getUserResults error: $e');
      return [];
    }
  }

  static Stream<List<TestResultModel>> getUserResultsStream(String userId) {
    // Single-field filter (userId) — sort client-side to avoid composite index.
    return _db.collection('results')
        .where('userId', isEqualTo: userId)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => TestResultModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => b.attemptedAt.compareTo(a.attemptedAt));
          return docs;
        })
        .handleError((e) {
          print('getUserResultsStream error: $e');
        });
  }

  static Future<String?> saveResult(TestResultModel result) async {
    final docRef = await _db.collection('results').add(result.toFirestore());
    return docRef.id;
  }

  /// Updates the user's aggregate stats after a test attempt. Increments
  /// totalTestsAttempted, adds XP (10 per correct answer), recomputes
  /// averageScore and level, and bumps the daily streak. Uses FieldValue
  /// increments so it's safe against concurrent writes. Best-effort: errors
  /// are swallowed so a stats-update failure never blocks the result screen.
  static Future<void> updateUserStatsAfterTest({
    required String userId,
    required int correctAnswers,
    required int totalQuestions,
    required double percentage,
  }) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final int prevAttempts = (data['totalTestsAttempted'] ?? 0) as int;
      final double prevAvg = (data['averageScore'] ?? 0).toDouble();
      final int prevXp = (data['totalXp'] ?? 0) as int;

      final newAttempts = prevAttempts + 1;
      final newAvg = ((prevAvg * prevAttempts) + percentage) / newAttempts;
      final newXp = prevXp + (correctAnswers * 10);
      final newLevel = (newXp ~/ 100) + 1;

      // Streak: bump if last active was yesterday; keep if today; reset to 1 otherwise.
      final lastActive = (data['lastActiveAt'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      int newStreak = (data['streak'] ?? 0) as int;
      if (lastActive == null) {
        newStreak = 1;
      } else {
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastActive.year, lastActive.month, lastActive.day))
            .inDays;
        if (diff == 1) {
          newStreak = newStreak + 1;
        } else if (diff > 1) {
          newStreak = 1;
        }
        // diff == 0 → same day → keep streak
      }

      await userRef.update({
        'totalTestsAttempted': newAttempts,
        'averageScore': newAvg,
        'totalXp': newXp,
        'level': newLevel,
        'streak': newStreak,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // LEADERBOARD WRITE: the user app cannot read other users' docs
      // (Firestore rules: users collection is owner-read-only). The
      // `leaderboard` collection is public-read + signed-in-write, so we
      // mirror the user's fresh stats into it after every test so the
      // Ranks screen can populate. We write 3 entries (allTime, weekly,
      // monthly) keyed by type + userId. The stream sorts by totalXp and
      // assigns rank client-side, so no rank field needs to be correct
      // here. For weekly/monthly, periodStart marks the current week/month
      // so the stream can exclude stale entries from previous periods.
      final String userName = (data['name'] ?? 'User').toString();
      final String? userPhoto = data['photoUrl']?.toString();
      final lbNow = DateTime.now();
      // Week bounds (week starts on Monday; weekday: 1=Mon..7=Sun).
      final daysFromMonday = lbNow.weekday - 1;
      final startOfWeek = DateTime(lbNow.year, lbNow.month, lbNow.day)
          .subtract(Duration(days: daysFromMonday));
      final startOfMonth = DateTime(lbNow.year, lbNow.month, 1);
      final baseEntry = <String, dynamic>{
        'userId': userId,
        'userName': userName,
        'userPhoto': userPhoto,
        'totalXp': newXp,
        'totalTestsAttempted': newAttempts,
        'averageScore': newAvg,
        'streak': newStreak,
        'rank': 0, // computed client-side by getLeaderboardStream
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final lbBatch = _db.batch();
      lbBatch.set(
        _db.collection('leaderboard').doc('allTime_$userId'),
        {
          ...baseEntry,
          'type': 'allTime',
          'periodStart': Timestamp.fromDate(DateTime(2020, 1, 1)),
          'periodEnd': FieldValue.serverTimestamp(),
        },
      );
      lbBatch.set(
        _db.collection('leaderboard').doc('weekly_$userId'),
        {
          ...baseEntry,
          'type': 'weekly',
          'periodStart': Timestamp.fromDate(startOfWeek),
          'periodEnd': Timestamp.fromDate(
              startOfWeek.add(const Duration(days: 7))),
        },
      );
      lbBatch.set(
        _db.collection('leaderboard').doc('monthly_$userId'),
        {
          ...baseEntry,
          'type': 'monthly',
          'periodStart': Timestamp.fromDate(startOfMonth),
          'periodEnd': Timestamp.fromDate(
              DateTime(lbNow.year, lbNow.month + 1, 1)),
        },
      );
      await lbBatch.commit();
    } catch (e) {
      // Swallow — stats update is best-effort. The result was already saved.
      print('updateUserStatsAfterTest error: $e');
    }
  }

  // ==================== CURRENT AFFAIRS ====================
  static Future<List<CurrentAffairModel>> getCurrentAffairs({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    try {
      // Avoid server-side orderBy (skips docs missing the field + may need
      // composite index with where clauses). Fetch + sort client-side.
      Query query = _db.collection('current_affairs').limit(limit * 3);
      if (fromDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      if (toDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }

      final snapshot = await query.get();
      var docs = snapshot.docs.map((doc) => CurrentAffairModel.fromFirestore(doc)).toList();
      docs.sort((a, b) => b.date.compareTo(a.date));
      return docs.take(limit).toList();
    } catch (e) {
      print('getCurrentAffairs error: $e');
      return [];
    }
  }

  static Stream<List<CurrentAffairModel>> getCurrentAffairsStream({int limit = 50}) {
    // No server-side orderBy — Firestore's orderBy SKIPS documents that are
    // missing the field, so a current affair without a `date` field would
    // silently disappear. We fetch all and sort client-side instead.
    return _db.collection('current_affairs')
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => CurrentAffairModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => b.date.compareTo(a.date));
          return docs.take(limit).toList();
        })
        .handleError((e) {
          print('getCurrentAffairsStream error: $e');
        });
  }

  // ==================== NOTIFICATIONS ====================
  static Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    // whereIn + orderBy requires composite index. Use whereIn only,
    // sort client-side.
    return _db.collection('notifications')
        .where('userId', whereIn: [userId, 'all'])
        .limit(100)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs.take(50).toList();
        })
        .handleError((e) {
          print('getNotificationsStream error: $e');
        });
  }

  static Future<void> markNotificationRead(String id) async {
    await _db.collection('notifications').doc(id).update({'isRead': true});
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    final batch = _db.batch();
    final snapshot = await _db.collection('notifications')
        .where('userId', whereIn: [userId, 'all'])
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ==================== LEADERBOARD ====================
  static Future<List<LeaderboardModel>> getLeaderboard({
    LeaderboardType type = LeaderboardType.allTime,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _db.collection('leaderboard')
          .where('type', isEqualTo: type.name)
          .orderBy('rank')
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => LeaderboardModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getLeaderboard error: $e');
      return [];
    }
  }

  static Stream<List<LeaderboardModel>> getLeaderboardStream({
    LeaderboardType type = LeaderboardType.allTime,
    int limit = 100,
  }) {
    // Compute the minimum periodStart for weekly/monthly so stale entries
    // from previous periods are excluded. For allTime, no period filter.
    final now = DateTime.now();
    DateTime? minPeriodStart;
    switch (type) {
      case LeaderboardType.weekly:
        // Week starts on Monday (weekday: 1=Mon..7=Sun).
        final daysFromMonday = now.weekday - 1;
        minPeriodStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        break;
      case LeaderboardType.monthly:
        minPeriodStart = DateTime(now.year, now.month, 1);
        break;
      case LeaderboardType.allTime:
      case LeaderboardType.testSpecific:
        minPeriodStart = null;
        break;
    }
    // Single-field filter (type) only — period filtering is client-side to
    // avoid needing a composite index (type + periodStart).
    return _db.collection('leaderboard')
        .where('type', isEqualTo: type.name)
        .limit(limit * 3)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs
              .map((doc) => LeaderboardModel.fromFirestore(doc))
              .toList();
          // Client-side period filter (excludes entries from previous
          // weeks/months that haven't been refreshed this period).
          if (minPeriodStart != null) {
            docs = docs
                .where((d) =>
                    !d.periodStart.isBefore(minPeriodStart!))
                .toList();
          }
          // Sort by totalXp desc (the stored rank field is stale/0 — rank
          // is computed live here so ties and new entries are always correct).
          docs.sort((a, b) => b.totalXp.compareTo(a.totalXp));
          // Assign live ranks and take the top `limit`.
          final ranked = <LeaderboardModel>[];
          for (var i = 0; i < docs.length && i < limit; i++) {
            final d = docs[i];
            ranked.add(LeaderboardModel(
              id: d.id,
              userId: d.userId,
              userName: d.userName,
              userPhoto: d.userPhoto,
              totalXp: d.totalXp,
              totalTestsAttempted: d.totalTestsAttempted,
              averageScore: d.averageScore,
              rank: i + 1,
              streak: d.streak,
              type: d.type,
              testId: d.testId,
              periodStart: d.periodStart,
              periodEnd: d.periodEnd,
              updatedAt: d.updatedAt,
            ));
          }
          return ranked;
        })
        .handleError((e) {
          print('getLeaderboardStream error: $e');
        });
  }

  // ==================== ANNOUNCEMENTS ====================
  static Future<List<AnnouncementModel>> getAnnouncements({int limit = 50}) async {
    try {
      final snapshot = await _db.collection('announcements')
          .where('isPublished', isEqualTo: true)
          .orderBy('isPinned', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => AnnouncementModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getAnnouncements error: $e');
      return [];
    }
  }

  static Stream<List<AnnouncementModel>> getAnnouncementsStream({int limit = 50}) {
    // Single-field filter (isPublished) — sort client-side to avoid composite index.
    return _db.collection('announcements')
        .where('isPublished', isEqualTo: true)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => AnnouncementModel.fromFirestore(doc)).toList();
          docs.sort((a, b) {
            // Pinned first, then by createdAt desc
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          return docs.take(limit).toList();
        })
        .handleError((e) {
          print('getAnnouncementsStream error: $e');
        });
  }

  /// Admin-only: includes drafts and unpublished items.
  static Stream<List<AnnouncementModel>> getAllAnnouncementsStream() {
    return _db.collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromFirestore(doc))
            .toList());
  }

  static Future<String?> addAnnouncement(AnnouncementModel a) async {
    final docRef = await _db.collection('announcements').add(a.toFirestore());
    return docRef.id;
  }

  static Future<void> updateAnnouncement(AnnouncementModel a) async {
    await _db.collection('announcements').doc(a.id).update(a.toFirestore());
  }

  static Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
  }

  // ==================== UPCOMING EXAMS ====================
  static Future<List<UpcomingExamModel>> getUpcomingExams({int limit = 50}) async {
    try {
      final snapshot = await _db.collection('upcoming_exams')
          .where('isPublished', isEqualTo: true)
          .orderBy('examDate')
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => UpcomingExamModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getUpcomingExams error: $e');
      return [];
    }
  }

  static Stream<List<UpcomingExamModel>> getUpcomingExamsStream({int limit = 50}) {
    // Single-field filter (isPublished) — sort client-side by examDate asc.
    return _db.collection('upcoming_exams')
        .where('isPublished', isEqualTo: true)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => UpcomingExamModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => a.examDate.compareTo(b.examDate));
          return docs.take(limit).toList();
        })
        .handleError((e) {
          print('getUpcomingExamsStream error: $e');
        });
  }

  /// Admin-only: includes drafts and unpublished items.
  static Stream<List<UpcomingExamModel>> getAllUpcomingExamsStream() {
    return _db.collection('upcoming_exams')
        .orderBy('examDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UpcomingExamModel.fromFirestore(doc))
            .toList());
  }

  static Future<String?> addUpcomingExam(UpcomingExamModel e) async {
    final docRef = await _db.collection('upcoming_exams').add(e.toFirestore());
    return docRef.id;
  }

  static Future<void> updateUpcomingExam(UpcomingExamModel e) async {
    await _db.collection('upcoming_exams').doc(e.id).update(e.toFirestore());
  }

  static Future<void> deleteUpcomingExam(String id) async {
    await _db.collection('upcoming_exams').doc(id).delete();
  }

  // ==================== BANNERS ====================
  static Stream<List<BannerModel>> getActiveBannersStream() {
    // Single-field filter (isActive) — sort client-side by order.
    return _db.collection('banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => BannerModel.fromFirestore(doc))
              .where((b) => b.isVisible && b.imageUrl.isNotEmpty)
              .toList();
          docs.sort((a, b) => (a.order).compareTo(b.order));
          return docs;
        })
        .handleError((e) {
          print('getActiveBannersStream error: $e');
        });
  }

  /// Admin-only: includes inactive and scheduled banners.
  static Stream<List<BannerModel>> getAllBannersStream() {
    return _db.collection('banners')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BannerModel.fromFirestore(doc))
            .toList());
  }

  static Future<String?> addBanner(BannerModel b) async {
    final docRef = await _db.collection('banners').add(b.toFirestore());
    return docRef.id;
  }

  static Future<void> updateBanner(BannerModel b) async {
    await _db.collection('banners').doc(b.id).update(b.toFirestore());
  }

  static Future<void> deleteBanner(String id) async {
    await _db.collection('banners').doc(id).delete();
  }

  // ==================== APP OPEN BANNERS ====================
  // Full-screen promotional banner shown once per app launch (splash → home
  // transition). Admin-set frequency cap + urgent override + audience targeting.
  // Collection name: app_open_banners (kept separate from `banners` so the
  // home-screen carousel is unaffected).

  /// Streams ALL app-open banners (admin view — includes inactive/scheduled).
  static Stream<List<AppOpenBannerModel>> getAllAppOpenBannersStream() {
    return _db.collection('app_open_banners')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => AppOpenBannerModel.fromFirestore(doc))
              .toList();
          // Higher priority first, then by createdAt desc (newest first).
          docs.sort((a, b) {
            final byPriority = b.priority.compareTo(a.priority);
            if (byPriority != 0) return byPriority;
            return b.createdAt.compareTo(a.createdAt);
          });
          return docs;
        })
        .handleError((e) {
          print('getAllAppOpenBannersStream error: $e');
        });
  }

  /// Fetches the SINGLE active app-open banner to show right now.
  /// Filters: isActive=true, imageUrl not empty, within scheduled window,
  /// matches target audience, and priority-sorted (highest wins).
  /// Returns null on error or when no banner qualifies.
  static Future<AppOpenBannerModel?> fetchActiveAppOpenBanner({
    required bool isGuest,
    required bool isPremium,
  }) async {
    try {
      final snapshot = await _db
          .collection('app_open_banners')
          .where('isActive', isEqualTo: true)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final all = snapshot.docs
          .map((doc) => AppOpenBannerModel.fromFirestore(doc))
          .where((b) =>
              b.isVisibleNow &&
              b.matchesAudience(isGuest: isGuest, isPremium: isPremium))
          .toList();
      if (all.isEmpty) return null;
      // Highest priority first; tiebreak by newest createdAt.
      all.sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        return b.createdAt.compareTo(a.createdAt);
      });
      return all.first;
    } catch (e) {
      print('fetchActiveAppOpenBanner error: $e');
      return null;
    }
  }

  static Future<String?> addAppOpenBanner(AppOpenBannerModel b) async {
    final docRef = await _db.collection('app_open_banners').add(b.toFirestore());
    return docRef.id;
  }

  static Future<void> updateAppOpenBanner(AppOpenBannerModel b) async {
    await _db
        .collection('app_open_banners')
        .doc(b.id)
        .update(b.toFirestore());
  }

  static Future<void> deleteAppOpenBanner(String id) async {
    await _db.collection('app_open_banners').doc(id).delete();
  }

  /// Increments the banner's impression counter (best-effort, non-blocking).
  static Future<void> incrementAppOpenBannerImpression(String bannerId) async {
    try {
      await _db.collection('app_open_banners').doc(bannerId).update({
        'impressionCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('incrementAppOpenBannerImpression error: $e');
    }
  }

  /// Increments the banner's click counter (best-effort, non-blocking).
  static Future<void> incrementAppOpenBannerClick(String bannerId) async {
    try {
      await _db.collection('app_open_banners').doc(bannerId).update({
        'clickCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('incrementAppOpenBannerClick error: $e');
    }
  }

  // ==================== PREMIUM PLANS ====================
  // Admin-controllable premium subscription plans. The premium screen streams
  // these and falls back to AppConfig defaults when the collection is empty.
  // We use a single-field filter (isActive) and sort client-side by `order`
  // to avoid Firestore composite-index requirements.
  static Stream<List<PremiumPlanModel>> getActivePremiumPlansStream() {
    try {
      return _db.collection('premium_plans')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            var docs = snapshot.docs
                .map((doc) => PremiumPlanModel.fromFirestore(doc))
                .toList();
            docs.sort((a, b) => a.order.compareTo(b.order));
            return docs;
          })
          .handleError((e) {
            print('getActivePremiumPlansStream error: $e');
          });
    } catch (e) {
      print('getActivePremiumPlansStream init error: $e');
      return Stream.value(<PremiumPlanModel>[]);
    }
  }

  static Future<List<PremiumPlanModel>> getActivePremiumPlans() async {
    try {
      final snapshot = await _db.collection('premium_plans')
          .where('isActive', isEqualTo: true)
          .get();
      final docs = snapshot.docs
          .map((doc) => PremiumPlanModel.fromFirestore(doc))
          .toList();
      docs.sort((a, b) => a.order.compareTo(b.order));
      return docs;
    } catch (e) {
      print('getActivePremiumPlans error: $e');
      return [];
    }
  }

  // ==================== PREVIOUS PAPERS (Test type filter) ====================
  static Stream<List<TestModel>> getPreviousPapersStream() {
    // Single-field filter only (type) — sort + isPublished filter client-side
    // to avoid composite index requirement.
    return _db.collection('tests')
        .where('type', isEqualTo: 'previousYear')
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => TestModel.fromFirestore(doc)).toList();
          docs = docs.where((t) => t.isPublished).toList();
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        })
        .handleError((e) {
          print('getPreviousPapersStream error: $e');
        });
  }

  // ==================== CATEGORY ID RESOLUTION ====================
  // The admin may have stored a category's NAME or SLUG in subject.categoryId
  // instead of the real Firestore document ID. This method tries all three
  // representations and returns the authoritative document id so the backend's
  // exam-pack access tier (ExamPackPurchase.categoryId) can match correctly.
  //
  // Always call this before passing categoryId to /api/payments/access-check
  // when the categoryId came from a subject document (not from a CategoryModel
  // that was already loaded from Firestore).
  static Future<String?> resolveCategoryId(String? ref) async {
    if (ref == null || ref.isEmpty) return null;
    try {
      // Fast path: ref IS the real Firestore document id.
      final doc = await _db.collection('categories').doc(ref).get();
      if (doc.exists) return doc.id;
    } catch (_) {}
    try {
      // Fallback 1: match by category name.
      final byName = await _db
          .collection('categories')
          .where('name', isEqualTo: ref)
          .limit(1)
          .get();
      if (byName.docs.isNotEmpty) return byName.docs.first.id;
    } catch (_) {}
    try {
      // Fallback 2: match by slug.
      final bySlug = await _db
          .collection('categories')
          .where('slug', isEqualTo: ref)
          .limit(1)
          .get();
      if (bySlug.docs.isNotEmpty) return bySlug.docs.first.id;
    } catch (_) {}
    // Could not resolve — return the input as-is. The access check will still
    // run; it will simply miss the exam-pack tier if the id is wrong.
    return ref;
  }

  // ==================== BOOKMARKS ====================
  // Stored at: users/{uid}/bookmarks/{testId}
  // Fields: testId, testTitle, subjectId, addedAt
  //
  // Bookmarks are per-user and keyed by testId so toggling is idempotent.
  // The BookmarksScreen streams this subcollection ordered by addedAt desc.

  static Stream<List<Map<String, dynamic>>> getBookmarksStream(String uid) {
    // No server-side orderBy — Firestore's orderBy on a subcollection may need
    // a composite index that isn't always deployed, causing the stream to hang
    // in ConnectionState.waiting indefinitely. Sort client-side instead.
    return _db
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList();
      // Sort by addedAt descending (newest first). Treat null/missing as epoch.
      list.sort((a, b) {
        final aTs = a['addedAt'];
        final bTs = b['addedAt'];
        DateTime aDate = DateTime(1970);
        DateTime bDate = DateTime(1970);
        if (aTs is Timestamp) aDate = aTs.toDate();
        if (bTs is Timestamp) bDate = bTs.toDate();
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  /// Returns the CategoryModel for the given Firestore document id, or null.
  static Future<CategoryModel?> getCategoryById(String id) async {
    if (id.isEmpty) return null;
    try {
      final doc = await _db.collection('categories').doc(id).get();
      if (!doc.exists) return null;
      return CategoryModel.fromFirestore(doc);
    } catch (e) {
      print('getCategoryById($id) error: $e');
      return null;
    }
  }

  /// Streams a single category document by id. Used by CategoryDetailScreen
  /// so the screen receives LIVE updates when the admin toggles premium,
  /// changes the price, uploads an image, etc. Without this, the screen
  /// used a stale snapshot from the constructor and premium changes made in
  /// the admin panel didn't reflect until the user navigated away and back.
  static Stream<CategoryModel?> getCategoryStream(String id) {
    if (id.isEmpty) {
      return Stream.value(null);
    }
    return _db.collection('categories').doc(id).snapshots().map(
      (doc) => doc.exists ? CategoryModel.fromFirestore(doc) : null,
    );
  }

  static Future<void> addBookmark(
    String uid,
    String testId,
    String testTitle, {
    String? subjectId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(testId)
        .set({
      'testId': testId,
      'testTitle': testTitle,
      'subjectId': subjectId ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeBookmark(String uid, String testId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .doc(testId)
        .delete();
  }

  static Future<bool> isBookmarked(String uid, String testId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .doc(testId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Returns a list of testId strings the user has bookmarked.
  /// Used for bulk operations (e.g. "clear all"). Does NOT throw.
  static Future<List<String>> getBookmarksOnce(String uid) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (_) {
      return [];
    }
  }

  // ==================== ANALYTICS (for Admin Dashboard) ====================
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final usersCount = await _db.collection('users').count().get();
    final testsCount = await _db.collection('tests').count().get();
    final questionsCount = await _db.collection('questions').count().get();
    final resultsCount = await _db.collection('results').count().get();
    final paymentsCount = await _db.collection('payments').count().get();
    final premiumUsersCount = await _db.collection('users')
        .where('subscriptionStatus', isEqualTo: 'premium')
        .count()
        .get();

    return {
      'totalUsers': usersCount.count,
      'totalTests': testsCount.count,
      'totalQuestions': questionsCount.count,
      'totalAttempts': resultsCount.count,
      'totalPayments': paymentsCount.count,
      'premiumUsers': premiumUsersCount.count,
    };
  }
}

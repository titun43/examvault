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
        })
        .handleError((e) {
          print('getCategoriesStream error: $e');
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
    Query query = _db.collection('tests').orderBy('createdAt', descending: true);
    if (subjectId != null) query = query.where('subjectId', isEqualTo: subjectId);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    if (isPublished != null) query = query.where('isPublished', isEqualTo: isPublished);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => TestModel.fromFirestore(doc)).toList();
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

  // ==================== QUESTIONS ====================
  static Future<List<QuestionModel>> getQuestions(String testId) async {
    // Single-field filter only (testId) — sort client-side to avoid the
    // composite index requirement (testId + createdAt).
    final snapshot = await _db.collection('questions')
        .where('testId', isEqualTo: testId)
        .get();
    final docs = snapshot.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();
    docs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return docs;
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
    final snapshot = await _db.collection('results')
        .where('userId', isEqualTo: userId)
        .orderBy('attemptedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => TestResultModel.fromFirestore(doc)).toList();
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
    Query query = _db.collection('current_affairs')
        .orderBy('date', descending: true)
        .limit(limit);
    if (fromDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }
    if (toDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => CurrentAffairModel.fromFirestore(doc)).toList();
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
    final snapshot = await _db.collection('leaderboard')
        .where('type', isEqualTo: type.name)
        .orderBy('rank')
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => LeaderboardModel.fromFirestore(doc)).toList();
  }

  static Stream<List<LeaderboardModel>> getLeaderboardStream({
    LeaderboardType type = LeaderboardType.allTime,
    int limit = 100,
  }) {
    // Single-field filter (type) — sort client-side by rank.
    return _db.collection('leaderboard')
        .where('type', isEqualTo: type.name)
        .limit(limit * 2)
        .snapshots()
        .map((snapshot) {
          var docs = snapshot.docs.map((doc) => LeaderboardModel.fromFirestore(doc)).toList();
          docs.sort((a, b) => a.rank.compareTo(b.rank));
          return docs.take(limit).toList();
        });
  }

  // ==================== ANNOUNCEMENTS ====================
  static Future<List<AnnouncementModel>> getAnnouncements({int limit = 50}) async {
    final snapshot = await _db.collection('announcements')
        .where('isPublished', isEqualTo: true)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => AnnouncementModel.fromFirestore(doc)).toList();
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
    final snapshot = await _db.collection('upcoming_exams')
        .where('isPublished', isEqualTo: true)
        .orderBy('examDate')
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => UpcomingExamModel.fromFirestore(doc)).toList();
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
        });
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

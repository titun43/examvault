// =============================================================================
// ExamVault - Firestore Service (CRUD operations for all collections)
// =============================================================================

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
import 'firebase_service.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseService.firestore;

  // ==================== CATEGORIES ====================
  static Future<List<CategoryModel>> getCategories() async {
    final snapshot = await _db.collection('categories')
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
  }

  static Stream<List<CategoryModel>> getCategoriesStream() {
    return _db.collection('categories')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
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
  static Future<List<SubjectModel>> getSubjects({String? categoryId}) async {
    Query query = _db.collection('subjects').orderBy('order');
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SubjectModel.fromFirestore(doc)).toList();
  }

  static Stream<List<SubjectModel>> getSubjectsStream({String? categoryId}) {
    Query query = _db.collection('subjects').orderBy('order');
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => SubjectModel.fromFirestore(doc))
        .toList());
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

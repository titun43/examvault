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
    Query query = _db.collection('tests').orderBy('createdAt', descending: true);
    if (subjectId != null) query = query.where('subjectId', isEqualTo: subjectId);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    if (isPublished != null) query = query.where('isPublished', isEqualTo: isPublished);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => TestModel.fromFirestore(doc))
        .toList());
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
    final snapshot = await _db.collection('questions')
        .where('testId', isEqualTo: testId)
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) => QuestionModel.fromFirestore(doc)).toList();
  }

  static Stream<List<QuestionModel>> getQuestionsStream(String testId) {
    return _db.collection('questions')
        .where('testId', isEqualTo: testId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuestionModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('results')
        .where('userId', isEqualTo: userId)
        .orderBy('attemptedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TestResultModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('current_affairs')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CurrentAffairModel.fromFirestore(doc))
            .toList());
  }

  // ==================== NOTIFICATIONS ====================
  static Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _db.collection('notifications')
        .where('userId', whereIn: [userId, 'all'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('leaderboard')
        .where('type', isEqualTo: type.name)
        .orderBy('rank')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaderboardModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('announcements')
        .where('isPublished', isEqualTo: true)
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('upcoming_exams')
        .where('isPublished', isEqualTo: true)
        .orderBy('examDate')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UpcomingExamModel.fromFirestore(doc))
            .toList());
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
    return _db.collection('banners')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BannerModel.fromFirestore(doc))
            .where((b) => b.isVisible && b.imageUrl.isNotEmpty)
            .toList());
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
    return _db.collection('tests')
        .where('type', isEqualTo: 'previousYear')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TestModel.fromFirestore(doc))
            .toList());
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

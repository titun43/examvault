// =============================================================================
// ExamVault - Local Data Service (Offline-first, Admin-editable)
// =============================================================================
// Uses SharedPreferences + JSON encoding to persist ALL app data locally.
// This makes login work WITHOUT Firebase, and lets the admin panel edit
// real data that reflects in the user-facing screens (A-Z control).
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String password;
  final String role; // 'admin' | 'student'
  final bool isPremium;
  final String? photoUrl;
  final DateTime createdAt;

  LocalUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.password,
    this.role = 'student',
    this.isPremium = false,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        'isPremium': isPremium,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LocalUser.fromJson(Map<String, dynamic> j) => LocalUser(
        id: j['id'] ?? '',
        name: j['name'] ?? 'User',
        email: j['email'],
        phone: j['phone'],
        password: j['password'] ?? '',
        role: j['role'] ?? 'student',
        isPremium: j['isPremium'] ?? false,
        photoUrl: j['photoUrl'],
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class LocalCategory {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String description;
  final int testCount;

  LocalCategory({
    required this.id,
    required this.name,
    this.icon = 'school',
    this.color = '#1565C0',
    this.description = '',
    this.testCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'description': description,
        'testCount': testCount,
      };

  factory LocalCategory.fromJson(Map<String, dynamic> j) => LocalCategory(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        icon: j['icon'] ?? 'school',
        color: j['color'] ?? '#1565C0',
        description: j['description'] ?? '',
        testCount: j['testCount'] ?? 0,
      );
}

class LocalSubject {
  final String id;
  final String categoryId;
  final String name;
  final String icon;
  final int questionCount;

  LocalSubject({
    required this.id,
    required this.categoryId,
    required this.name,
    this.icon = 'book',
    this.questionCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'icon': icon,
        'questionCount': questionCount,
      };

  factory LocalSubject.fromJson(Map<String, dynamic> j) => LocalSubject(
        id: j['id'] ?? '',
        categoryId: j['categoryId'] ?? '',
        name: j['name'] ?? '',
        icon: j['icon'] ?? 'book',
        questionCount: j['questionCount'] ?? 0,
      );
}

class LocalQuestion {
  final String id;
  final String testId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  LocalQuestion({
    required this.id,
    required this.testId,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'testId': testId,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory LocalQuestion.fromJson(Map<String, dynamic> j) => LocalQuestion(
        id: j['id'] ?? '',
        testId: j['testId'] ?? '',
        question: j['question'] ?? '',
        options: List<String>.from(j['options'] ?? []),
        correctIndex: j['correctIndex'] ?? 0,
        explanation: j['explanation'] ?? '',
      );
}

class LocalTest {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final int durationMinutes;
  final int totalQuestions;
  final int totalMarks;
  final bool isFree;
  final bool isActive;

  LocalTest({
    required this.id,
    required this.categoryId,
    required this.title,
    this.description = '',
    this.durationMinutes = 30,
    this.totalQuestions = 20,
    this.totalMarks = 20,
    this.isFree = true,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'title': title,
        'description': description,
        'durationMinutes': durationMinutes,
        'totalQuestions': totalQuestions,
        'totalMarks': totalMarks,
        'isFree': isFree,
        'isActive': isActive,
      };

  factory LocalTest.fromJson(Map<String, dynamic> j) => LocalTest(
        id: j['id'] ?? '',
        categoryId: j['categoryId'] ?? '',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        durationMinutes: j['durationMinutes'] ?? 30,
        totalQuestions: j['totalQuestions'] ?? 20,
        totalMarks: j['totalMarks'] ?? 20,
        isFree: j['isFree'] ?? true,
        isActive: j['isActive'] ?? true,
      );
}

class LocalPayment {
  final String id;
  final String userId;
  final String userName;
  final String plan;
  final int amount;
  final String status;
  final DateTime date;

  LocalPayment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.plan,
    required this.amount,
    this.status = 'success',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'plan': plan,
        'amount': amount,
        'status': status,
        'date': date.toIso8601String(),
      };

  factory LocalPayment.fromJson(Map<String, dynamic> j) => LocalPayment(
        id: j['id'] ?? '',
        userId: j['userId'] ?? '',
        userName: j['userName'] ?? '',
        plan: j['plan'] ?? '',
        amount: j['amount'] ?? 0,
        status: j['status'] ?? 'success',
        date: j['date'] != null
            ? DateTime.tryParse(j['date']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class LocalAnnouncement {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool isActive;

  LocalAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    DateTime? date,
    this.isActive = true,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'isActive': isActive,
      };

  factory LocalAnnouncement.fromJson(Map<String, dynamic> j) =>
      LocalAnnouncement(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        date: j['date'] != null
            ? DateTime.tryParse(j['date']) ?? DateTime.now()
            : DateTime.now(),
        isActive: j['isActive'] ?? true,
      );
}

class LocalCurrentAffair {
  final String id;
  final String title;
  final String summary;
  final String category;
  final DateTime date;
  final bool isActive;

  LocalCurrentAffair({
    required this.id,
    required this.title,
    required this.summary,
    this.category = 'General',
    DateTime? date,
    this.isActive = true,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'category': category,
        'date': date.toIso8601String(),
        'isActive': isActive,
      };

  factory LocalCurrentAffair.fromJson(Map<String, dynamic> j) =>
      LocalCurrentAffair(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        summary: j['summary'] ?? '',
        category: j['category'] ?? 'General',
        date: j['date'] != null
            ? DateTime.tryParse(j['date']) ?? DateTime.now()
            : DateTime.now(),
        isActive: j['isActive'] ?? true,
      );
}

class LocalUpcomingExam {
  final String id;
  final String name;
  final String organization;
  final DateTime examDate;
  final String status;

  LocalUpcomingExam({
    required this.id,
    required this.name,
    required this.organization,
    required this.examDate,
    this.status = 'upcoming',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'organization': organization,
        'examDate': examDate.toIso8601String(),
        'status': status,
      };

  factory LocalUpcomingExam.fromJson(Map<String, dynamic> j) =>
      LocalUpcomingExam(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        organization: j['organization'] ?? '',
        examDate: j['examDate'] != null
            ? DateTime.tryParse(j['examDate']) ?? DateTime.now()
            : DateTime.now(),
        status: j['status'] ?? 'upcoming',
      );
}

class LocalTestResult {
  final String id;
  final String userId;
  final String testId;
  final String testTitle;
  final int score;
  final int total;
  final DateTime date;

  LocalTestResult({
    required this.id,
    required this.userId,
    required this.testId,
    required this.testTitle,
    required this.score,
    required this.total,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'testId': testId,
        'testTitle': testTitle,
        'score': score,
        'total': total,
        'date': date.toIso8601String(),
      };

  factory LocalTestResult.fromJson(Map<String, dynamic> j) => LocalTestResult(
        id: j['id'] ?? '',
        userId: j['userId'] ?? '',
        testId: j['testId'] ?? '',
        testTitle: j['testTitle'] ?? '',
        score: j['score'] ?? 0,
        total: j['total'] ?? 0,
        date: j['date'] != null
            ? DateTime.tryParse(j['date']) ?? DateTime.now()
            : DateTime.now(),
      );
}

// =============================================================================
// MAIN SERVICE
// =============================================================================

class LocalDataService {
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  static const _kUsers = 'users';
  static const _kCategories = 'categories';
  static const _kSubjects = 'subjects';
  static const _kTests = 'tests';
  static const _kQuestions = 'questions';
  static const _kPayments = 'payments';
  static const _kAnnouncements = 'announcements';
  static const _kCurrentAffairs = 'current_affairs';
  static const _kUpcomingExams = 'upcoming_exams';
  static const _kTestResults = 'test_results';
  static const _kCurrentUserId = 'current_user_id';
  static const _kSeeded = 'seeded_v3'; // bumped to clear old demo data

  static Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _seedIfFirstRun();
    _initialized = true;
  }

  static SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError('LocalDataService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  // ==================== SEED ====================
  // Only the admin account is seeded. All other content (categories, tests,
  // questions, announcements, etc.) must be added by the admin from the panel.
  // Users register/login via Firebase Phone OTP.
  static Future<void> _seedIfFirstRun() async {
    if (_prefs!.getBool(_kSeeded) == true) return;

    // Clear any leftover demo data from older versions
    await _prefs!.remove(_kUsers);
    await _prefs!.remove(_kCategories);
    await _prefs!.remove(_kSubjects);
    await _prefs!.remove(_kTests);
    await _prefs!.remove(_kQuestions);
    await _prefs!.remove(_kPayments);
    await _prefs!.remove(_kAnnouncements);
    await _prefs!.remove(_kCurrentAffairs);
    await _prefs!.remove(_kUpcomingExams);
    await _prefs!.remove(_kTestResults);
    await _prefs!.remove(_kCurrentUserId);

    final admin = LocalUser(
      id: 'admin-001',
      name: 'Admin',
      email: 'admin@examvault.com',
      phone: '9000000000',
      password: 'admin123',
      role: 'admin',
      isPremium: true,
    );
    await _save(_kUsers, [admin.toJson()]);

    await _prefs!.setBool(_kSeeded, true);
  }

  // ==================== IO HELPERS ====================
  static List<Map<String, dynamic>> _readList(String key) {
    final raw = _p.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> _save(String key, List<Map<String, dynamic>> data) async {
    await _p.setString(key, jsonEncode(data));
  }

  // ==================== AUTH ====================
  static LocalUser? get currentUser {
    final id = _p.getString(_kCurrentUserId);
    if (id == null) return null;
    final users = _readList(_kUsers).map(LocalUser.fromJson).toList();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Login with email OR phone + password.
  static LocalUser? loginWithIdentifier({
    required String identifier,
    required String password,
  }) {
    final id = identifier.trim();
    final isEmail = id.contains('@');
    final users = _readList(_kUsers).map(LocalUser.fromJson).toList();
    LocalUser? match;
    try {
      match = isEmail
          ? users.firstWhere((u) =>
              (u.email ?? '').toLowerCase() == id.toLowerCase())
          : users.firstWhere((u) {
              final ph = (u.phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
              final inp = id.replaceAll(RegExp(r'[^\d]'), '');
              return ph.isNotEmpty &&
                  inp.isNotEmpty &&
                  ph.endsWith(inp.length >= 10 ? inp.substring(inp.length - 10) : inp);
            });
    } catch (_) {
      match = null;
    }
    if (match == null) return null;
    if (match.password != password) return null;
    _p.setString(_kCurrentUserId, match.id);
    return match;
  }

  static LocalUser? register({
    required String name,
    required String password,
    String? email,
    String? phone,
  }) {
    final users = _readList(_kUsers).map(LocalUser.fromJson).toList();
    if (email != null && email.isNotEmpty) {
      if (users.any((u) => (u.email ?? '').toLowerCase() == email.toLowerCase())) {
        throw Exception('This email is already registered. Please sign in.');
      }
    }
    if (phone != null && phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length != 10) {
        throw Exception('Please enter a valid 10-digit mobile number');
      }
      if (users.any((u) {
        final ph = (u.phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
        return ph.endsWith(digits);
      })) {
        throw Exception('This mobile number is already registered.');
      }
    }
    final newId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final newUser = LocalUser(
      id: newId,
      name: name,
      email: email,
      phone: phone,
      password: password,
      role: 'student',
      isPremium: false,
    );
    users.add(newUser);
    _save(_kUsers, users.map((u) => u.toJson()).toList());
    _p.setString(_kCurrentUserId, newId);
    return newUser;
  }

  static Future<void> logout() async {
    await _p.remove(_kCurrentUserId);
  }

  static bool get isAdmin => currentUser?.role == 'admin';

  /// Find or create a student by phone number (used after Firebase OTP login).
  static LocalUser findOrCreateByPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    final users = _readList(_kUsers).map(LocalUser.fromJson).toList();
    try {
      final existing = users.firstWhere((u) {
        final ph = (u.phone ?? '').replaceAll(RegExp(r'[^\d]'), '');
        return ph.isNotEmpty && ph.endsWith(last10);
      });
      _p.setString(_kCurrentUserId, existing.id);
      return existing;
    } catch (_) {
      // Create new student
      final newId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      final newUser = LocalUser(
        id: newId,
        name: 'User',
        phone: last10,
        password: '',
        role: 'student',
        isPremium: false,
      );
      users.add(newUser);
      _save(_kUsers, users.map((u) => u.toJson()).toList());
      _p.setString(_kCurrentUserId, newId);
      return newUser;
    }
  }

  // ==================== USERS (Admin CRUD) ====================
  static List<LocalUser> getAllUsers() =>
      _readList(_kUsers).map(LocalUser.fromJson).toList();

  static Future<void> deleteUser(String id) async {
    final users = getAllUsers();
    users.removeWhere((u) => u.id == id);
    await _save(_kUsers, users.map((u) => u.toJson()).toList());
  }

  static Future<void> toggleUserPremium(String id) async {
    final users = getAllUsers();
    final idx = users.indexWhere((u) => u.id == id);
    if (idx >= 0) {
      final u = users[idx];
      users[idx] = LocalUser(
        id: u.id,
        name: u.name,
        email: u.email,
        phone: u.phone,
        password: u.password,
        role: u.role,
        isPremium: !u.isPremium,
        photoUrl: u.photoUrl,
        createdAt: u.createdAt,
      );
      await _save(_kUsers, users.map((x) => x.toJson()).toList());
    }
  }

  // ==================== CATEGORIES ====================
  static List<LocalCategory> getCategories() =>
      _readList(_kCategories).map(LocalCategory.fromJson).toList();

  static Future<void> addCategory(LocalCategory c) async {
    final list = getCategories();
    list.add(LocalCategory(
      id: c.id.isEmpty ? 'cat-${DateTime.now().millisecondsSinceEpoch}' : c.id,
      name: c.name,
      icon: c.icon,
      color: c.color,
      description: c.description,
      testCount: c.testCount,
    ));
    await _save(_kCategories, list.map((c) => c.toJson()).toList());
  }

  static Future<void> updateCategory(LocalCategory c) async {
    final list = getCategories();
    final idx = list.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      list[idx] = c;
      await _save(_kCategories, list.map((c) => c.toJson()).toList());
    }
  }

  static Future<void> deleteCategory(String id) async {
    final list = getCategories();
    list.removeWhere((c) => c.id == id);
    await _save(_kCategories, list.map((c) => c.toJson()).toList());
    final subjects = getSubjects().where((s) => s.categoryId != id).toList();
    await _save(_kSubjects, subjects.map((s) => s.toJson()).toList());
    final tests = getTests().where((t) => t.categoryId != id).toList();
    await _save(_kTests, tests.map((t) => t.toJson()).toList());
    final testIds = tests.map((t) => t.id).toSet();
    final questions = getQuestions().where((q) => testIds.contains(q.testId)).toList();
    await _save(_kQuestions, questions.map((q) => q.toJson()).toList());
  }

  // ==================== SUBJECTS ====================
  static List<LocalSubject> getSubjects() =>
      _readList(_kSubjects).map(LocalSubject.fromJson).toList();

  static List<LocalSubject> subjectsByCategory(String categoryId) =>
      getSubjects().where((s) => s.categoryId == categoryId).toList();

  // ==================== TESTS ====================
  static List<LocalTest> getTests() =>
      _readList(_kTests).map(LocalTest.fromJson).toList();

  static List<LocalTest> testsByCategory(String categoryId) =>
      getTests().where((t) => t.categoryId == categoryId).toList();

  static Future<void> addTest(LocalTest t) async {
    final list = getTests();
    list.add(LocalTest(
      id: t.id.isEmpty ? 'test-${DateTime.now().millisecondsSinceEpoch}' : t.id,
      categoryId: t.categoryId,
      title: t.title,
      description: t.description,
      durationMinutes: t.durationMinutes,
      totalQuestions: t.totalQuestions,
      totalMarks: t.totalMarks,
      isFree: t.isFree,
      isActive: t.isActive,
    ));
    await _save(_kTests, list.map((t) => t.toJson()).toList());
  }

  static Future<void> updateTest(LocalTest t) async {
    final list = getTests();
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      list[idx] = t;
      await _save(_kTests, list.map((t) => t.toJson()).toList());
    }
  }

  static Future<void> deleteTest(String id) async {
    final list = getTests();
    list.removeWhere((t) => t.id == id);
    await _save(_kTests, list.map((t) => t.toJson()).toList());
    final questions = getQuestions().where((q) => q.testId != id).toList();
    await _save(_kQuestions, questions.map((q) => q.toJson()).toList());
  }

  // ==================== QUESTIONS ====================
  static List<LocalQuestion> getQuestions() =>
      _readList(_kQuestions).map(LocalQuestion.fromJson).toList();

  static List<LocalQuestion> questionsByTest(String testId) =>
      getQuestions().where((q) => q.testId == testId).toList();

  static Future<void> addQuestion(LocalQuestion q) async {
    final list = getQuestions();
    list.add(LocalQuestion(
      id: q.id.isEmpty ? 'q-${DateTime.now().millisecondsSinceEpoch}' : q.id,
      testId: q.testId,
      question: q.question,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
    ));
    await _save(_kQuestions, list.map((q) => q.toJson()).toList());
  }

  static Future<void> deleteQuestion(String id) async {
    final list = getQuestions();
    list.removeWhere((q) => q.id == id);
    await _save(_kQuestions, list.map((q) => q.toJson()).toList());
  }

  // ==================== PAYMENTS ====================
  static List<LocalPayment> getPayments() =>
      _readList(_kPayments).map(LocalPayment.fromJson).toList();

  static Future<void> addPayment(LocalPayment p) async {
    final list = getPayments();
    list.add(LocalPayment(
      id: p.id.isEmpty ? 'pay-${DateTime.now().millisecondsSinceEpoch}' : p.id,
      userId: p.userId,
      userName: p.userName,
      plan: p.plan,
      amount: p.amount,
      status: p.status,
      date: p.date,
    ));
    await _save(_kPayments, list.map((p) => p.toJson()).toList());
  }

  // ==================== ANNOUNCEMENTS ====================
  static List<LocalAnnouncement> getAnnouncements() =>
      _readList(_kAnnouncements).map(LocalAnnouncement.fromJson).toList();

  static Future<void> addAnnouncement(LocalAnnouncement a) async {
    final list = getAnnouncements();
    list.insert(
        0,
        LocalAnnouncement(
          id: a.id.isEmpty ? 'ann-${DateTime.now().millisecondsSinceEpoch}' : a.id,
          title: a.title,
          body: a.body,
          date: a.date,
          isActive: a.isActive,
        ));
    await _save(_kAnnouncements, list.map((a) => a.toJson()).toList());
  }

  static Future<void> deleteAnnouncement(String id) async {
    final list = getAnnouncements();
    list.removeWhere((a) => a.id == id);
    await _save(_kAnnouncements, list.map((a) => a.toJson()).toList());
  }

  // ==================== CURRENT AFFAIRS ====================
  static List<LocalCurrentAffair> getCurrentAffairs() =>
      _readList(_kCurrentAffairs).map(LocalCurrentAffair.fromJson).toList();

  static Future<void> addCurrentAffair(LocalCurrentAffair c) async {
    final list = getCurrentAffairs();
    list.insert(
        0,
        LocalCurrentAffair(
          id: c.id.isEmpty ? 'ca-${DateTime.now().millisecondsSinceEpoch}' : c.id,
          title: c.title,
          summary: c.summary,
          category: c.category,
          date: c.date,
          isActive: c.isActive,
        ));
    await _save(_kCurrentAffairs, list.map((c) => c.toJson()).toList());
  }

  static Future<void> deleteCurrentAffair(String id) async {
    final list = getCurrentAffairs();
    list.removeWhere((c) => c.id == id);
    await _save(_kCurrentAffairs, list.map((c) => c.toJson()).toList());
  }

  // ==================== UPCOMING EXAMS ====================
  static List<LocalUpcomingExam> getUpcomingExams() =>
      _readList(_kUpcomingExams).map(LocalUpcomingExam.fromJson).toList();

  static Future<void> addUpcomingExam(LocalUpcomingExam u) async {
    final list = getUpcomingExams();
    list.add(LocalUpcomingExam(
      id: u.id.isEmpty ? 'ue-${DateTime.now().millisecondsSinceEpoch}' : u.id,
      name: u.name,
      organization: u.organization,
      examDate: u.examDate,
      status: u.status,
    ));
    await _save(_kUpcomingExams, list.map((u) => u.toJson()).toList());
  }

  static Future<void> deleteUpcomingExam(String id) async {
    final list = getUpcomingExams();
    list.removeWhere((u) => u.id == id);
    await _save(_kUpcomingExams, list.map((u) => u.toJson()).toList());
  }

  // ==================== TEST RESULTS ====================
  static List<LocalTestResult> getTestResults() =>
      _readList(_kTestResults).map(LocalTestResult.fromJson).toList();

  static List<LocalTestResult> resultsByUser(String userId) =>
      getTestResults().where((r) => r.userId == userId).toList();

  static Future<void> addTestResult(LocalTestResult r) async {
    final list = getTestResults();
    list.insert(
        0,
        LocalTestResult(
          id: r.id.isEmpty ? 'tr-${DateTime.now().millisecondsSinceEpoch}' : r.id,
          userId: r.userId,
          testId: r.testId,
          testTitle: r.testTitle,
          score: r.score,
          total: r.total,
          date: r.date,
        ));
    await _save(_kTestResults, list.map((r) => r.toJson()).toList());
  }

  // ==================== DASHBOARD STATS ====================
  static Map<String, dynamic> dashboardStats() {
    final users = getAllUsers();
    final students = users.where((u) => u.role == 'student').toList();
    final payments = getPayments();
    final revenue = payments
        .where((p) => p.status == 'success')
        .fold<int>(0, (sum, p) => sum + p.amount);
    return {
      'totalUsers': students.length,
      'totalTests': getTests().length,
      'totalQuestions': getQuestions().length,
      'totalCategories': getCategories().length,
      'totalRevenue': revenue,
      'premiumUsers': students.where((u) => u.isPremium).length,
      'totalPayments': payments.length,
      'totalAnnouncements': getAnnouncements().length,
      'totalCurrentAffairs': getCurrentAffairs().length,
      'totalUpcomingExams': getUpcomingExams().length,
    };
  }
}

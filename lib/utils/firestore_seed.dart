// =============================================================================
// ExamVault - Firestore Initial Data Seed Script
// Run this script to populate initial data in Firestore
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSeed {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> seedAll() async {
    await seedCategories();
    await seedAdmin();
    await seedCurrentAffairs();
    await seedNotifications();
    print('Seed data created successfully!');
  }

  // ==================== CATEGORIES ====================
  static Future<void> seedCategories() async {
    final categories = [
      {
        'name': 'Railway',
        'slug': 'railway',
        'icon': '🚂',
        'description': 'RRB NTPC, RRB Group D, RRB ALP, RRB JE and other railway exams',
        'color': 'E53935',
        'order': 1,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'SSC',
        'slug': 'ssc',
        'icon': '📋',
        'description': 'SSC CGL, SSC CHSL, SSC MTS, SSC GD and other SSC exams',
        'color': '1E88E5',
        'order': 2,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'UPSC',
        'slug': 'upsc',
        'icon': '🏛️',
        'description': 'UPSC Civil Services, UPSC CDS, UPSC NDA and other UPSC exams',
        'color': '8E24AA',
        'order': 3,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Banking',
        'slug': 'banking',
        'icon': '🏦',
        'description': 'IBPS PO, IBPS Clerk, SBI PO, SBI Clerk and other banking exams',
        'color': '43A047',
        'order': 4,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'ADRE',
        'slug': 'adre',
        'icon': '🎯',
        'description': 'Assam Direct Recruitment Examination',
        'color': 'FB8C00',
        'order': 5,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'State Exams',
        'slug': 'state-exams',
        'icon': '🏛️',
        'description': 'State level competitive exams across India',
        'color': '00897B',
        'order': 6,
        'subjectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final category in categories) {
      await _db.collection('categories').add(category);
    }
    print('Categories seeded');
  }

  // ==================== ADMIN USER ====================
  static Future<void> seedAdmin() async {
    // TODO: Replace with your real admin email and password
    // Default admin credentials:
    // Email: admin@examvault.com
    // Password: Admin@123
    final admin = {
      'name': 'Super Admin',
      'email': 'admin@examvault.com',
      'password': 'Admin@123', // ⚠️ Hash this in production!
      'role': 'superAdmin',
      'isActive': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('admins').doc('admin@examvault.com').set(admin);
    print('Admin user created');
    print('Email: admin@examvault.com');
    print('Password: Admin@123');
  }

  // ==================== CURRENT AFFAIRS ====================
  static Future<void> seedCurrentAffairs() async {
    final affairs = [
      {
        'date': Timestamp.fromDate(DateTime.now()),
        'title': 'PM Launches Viksit Bharat 2047 Roadmap',
        'content': 'The Prime Minister launched the Viksit Bharat 2047 roadmap with focus on infrastructure, education, and economic growth.',
        'summary': 'PM launches roadmap for developed India by 2047',
        'source': 'PIB',
        'category': 'Governance',
        'isImportant': true,
        'tags': ['policy', 'governance', 'economy'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'date': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
        'title': 'India\'s Forex Reserves Cross \$670 Billion',
        'content': 'India\'s foreign exchange reserves have crossed \$670 billion, reaching a new milestone.',
        'summary': 'Forex reserves reach all-time high',
        'source': 'RBI',
        'category': 'Economy',
        'isImportant': true,
        'tags': ['economy', 'forex', 'rbi'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final affair in affairs) {
      await _db.collection('current_affairs').add(affair);
    }
    print('Current affairs seeded');
  }

  // ==================== NOTIFICATIONS ====================
  static Future<void> seedNotifications() async {
    final notifications = [
      {
        'userId': 'all',
        'title': 'Welcome to ExamVault!',
        'body': 'Start your exam preparation journey today with thousands of mock tests.',
        'type': 'announcement',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final notification in notifications) {
      await _db.collection('notifications').add(notification);
    }
    print('Notifications seeded');
  }
}

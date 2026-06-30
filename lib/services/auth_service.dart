// =============================================================================
// ExamVault - Authentication Service
// Mobile OTP (real SMS via Firebase Phone Auth) + Email/Password (admin)
// =============================================================================

import 'dart:developer' as devlog;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

/// A structured auth error that carries the Firebase error code alongside the
/// human-readable message — so the UI can show actionable hints (e.g. "App
// signature not registered", "Quota exceeded", etc.).
class AppAuthException implements Exception {
  final String code;
  final String message;
  AppAuthException(this.code, this.message);

  @override
  String toString() => '[$code] $message';
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseService.auth;
  static final FirebaseFirestore _db = FirebaseService.firestore;

  // ==================== STATE STREAM ====================
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ==================== PHONE AUTH (real SMS OTP) ====================
  /// Kicks off Firebase Phone Auth verification.
  ///
  /// IMPORTANT: `verificationCompleted` (Android auto-retrieval) is also
  /// handled here — when the OS auto-detects the SMS, we sign in *and* create
  /// the user's Firestore doc, otherwise `loadUserData()` would return null
  /// and the user would appear "not logged in".
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(AppAuthException e) onVerificationFailed,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          await _createOrUpdateUser(result.user, authMethod: 'phone');
        } catch (e, st) {
          devlog.log('Auto-retrieval sign-in failed: $e\n$st');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        // Surface a structured error so the UI can show actionable hints
        final friendly = _friendlyPhoneError(e);
        onVerificationFailed(AppAuthException(e.code, friendly));
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval timed out — the user will have to enter the OTP manually.
        onCodeAutoRetrievalTimeout(verificationId);
      },
      timeout: timeout,
    );
  }

  static Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    await _createOrUpdateUser(result.user, authMethod: 'phone');
    return result;
  }

  /// Maps raw Firebase Phone Auth error codes to actionable messages.
  static String _friendlyPhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Phone number is invalid. Enter a valid 10-digit mobile number.';
      case 'too-many-requests':
        return 'Too many OTP requests from this number. Please wait a few minutes and try again.';
      case 'quota-exceeded':
        return 'Daily SMS quota exceeded. Try again tomorrow or contact admin.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Phone Auth is not enabled in Firebase Console. Ask admin to enable it.';
      case 'app-not-authorized':
        return 'App signature (SHA-1) not registered in Firebase. Ask admin to add it.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Check your network and try again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and re-enter the 6-digit code.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      default:
        return e.message ?? 'Phone verification failed (${e.code}).';
    }
  }

  // ==================== EMAIL/PASSWORD AUTH (admin + optional user) ====================
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user?.updateDisplayName(name);
    await _createOrUpdateUser(result.user, name: name, email: email, authMethod: 'email');
    return result;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _createOrUpdateUser(result.user, email: email, authMethod: 'email');
    return result;
  }

  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ==================== ADMIN LOGIN (Firebase Auth Email/Password) ====================
  /// Admin signs in with email/password via Firebase Auth.
  /// If the authenticated user's Firestore doc has role == 'admin', returns true.
  /// For the canonical admin email (admin@examvault.com), auto-creates the
  /// Firestore admin doc on first login (bootstrap).
  static Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = result.user!.uid;
      final userDoc = FirebaseService.usersRef.doc(uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // Bootstrap: if logging in with the canonical admin email, create the
        // admin Firestore doc automatically.
        if (email.trim().toLowerCase() == 'admin@examvault.com') {
          final adminUser = UserModel(
            id: uid,
            name: 'Admin',
            email: email.trim(),
            role: UserRole.admin,
            subscriptionStatus: SubscriptionStatus.premium,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          );
          await userDoc.set(adminUser.toFirestore());
          // Also mirror to admins/{uid} so Firestore isAdmin() rule works.
          await FirebaseService.adminsRef.doc(uid).set({
            'email': email.trim(),
            'role': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
        // Not admin and no user doc — sign out and reject
        await _auth.signOut();
        return false;
      }

      // Doc exists — check role
      final data = docSnapshot.data() as Map<String, dynamic>;
      if (data['role'] != 'admin') {
        await _auth.signOut();
        return false;
      }
      // Ensure admins/{uid} mirror exists (so security rules work)
      final adminMirror = await FirebaseService.adminsRef.doc(uid).get();
      if (!adminMirror.exists) {
        await FirebaseService.adminsRef.doc(uid).set({
          'email': email.trim(),
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // ==================== LOGOUT ====================
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ==================== HELPER: CREATE/UPDATE USER IN FIRESTORE ====================
  static Future<void> _createOrUpdateUser(
    User? firebaseUser, {
    String? name,
    String? email,
    String? authMethod,
  }) async {
    if (firebaseUser == null) return;

    final userDoc = FirebaseService.usersRef.doc(firebaseUser.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // New user - create document
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: name ?? firebaseUser.displayName ?? 'User',
        email: email ?? firebaseUser.email,
        phoneNumber: firebaseUser.phoneNumber,
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      await userDoc.set(newUser.toFirestore());
    } else {
      // Existing user - update last active
      await userDoc.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== GET CURRENT USER DATA ====================
  static Future<UserModel?> getCurrentUserData() async {
    if (currentUser == null) return null;
    final doc = await FirebaseService.usersRef.doc(currentUser!.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // ==================== UPDATE USER PROFILE ====================
  static Future<void> updateProfile({
    required String userId,
    String? name,
    String? photoUrl,
    String? email,
    String? phoneNumber,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (email != null) updates['email'] = email;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

    await FirebaseService.usersRef.doc(userId).update(updates);
  }

  // ==================== DELETE ACCOUNT ====================
  static Future<void> deleteAccount() async {
    if (currentUser != null) {
      await FirebaseService.usersRef.doc(currentUser!.uid).delete();
      await currentUser!.delete();
    }
  }
}

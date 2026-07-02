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

  /// Maps raw Firebase Phone Auth error codes to actionable, user-friendly
  /// messages. Admin/technical details (Firebase Console, SHA-1, etc.) are
  /// NEVER exposed to end users — they only see what they can act on.
  /// The original technical context is logged for debugging separately.
  static String _friendlyPhoneError(FirebaseAuthException e) {
    // Log the raw code + message for developer debugging.
    print('PhoneAuth error code: ${e.code}, message: ${e.message}');
    // For configuration errors, append the raw code so the app admin can
    // diagnose (e.g. add the signing SHA-1 to the Firebase Console). Regular
    // users still see a friendly lead-in; the code in parentheses is the only
    // technical bit and helps the admin act without us dumping raw Firebase
    // Console instructions on the end user.
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Phone number is invalid. Enter a valid 10-digit mobile number.';
      case 'too-many-requests':
        return 'Too many OTP requests from this number. Please wait a few minutes and try again.';
      case 'quota-exceeded':
        return 'Daily SMS quota exceeded. Please try again tomorrow.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'operation-not-allowed':
        // Real cause: Phone Auth not enabled in Firebase Console.
        // This is an ADMIN configuration issue — the end user can't fix it.
        // We tell them to use Email sign-in instead (which always works).
        return 'Mobile OTP login is temporarily unavailable. '
            'Please use Email sign-in instead — tap the "Email" tab above.';
      case 'app-not-authorized':
        // Real cause: app signing key (SHA-1) not registered in Firebase Console.
        return 'Mobile OTP login is temporarily unavailable. '
            'Please use Email sign-in instead — tap the "Email" tab above.';
      case 'captcha-check-failed':
        return 'Verification failed. Check your network and try again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and re-enter the 6-digit code.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'missing-client-identifier':
        // reCAPTCHA / SafetyNet could not be resolved — often a SHA-1 issue.
        return 'Mobile OTP login is temporarily unavailable. '
            'Please use Email sign-in instead — tap the "Email" tab above.';
      default:
        return 'Unable to send OTP right now. '
            'Please use Email sign-in instead — tap the "Email" tab above.';
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
  ///
  /// NOTE: This is defensive against Firestore permission-denied on the
  /// admins/{uid} read — if the doc doesn't exist yet, the read may throw,
  /// so we catch and fall through to the bootstrap create.
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

      final canonicalAdmin = email.trim().toLowerCase() == 'admin@examvault.com';

      if (!docSnapshot.exists) {
        // Bootstrap: if logging in with the canonical admin email, create the
        // admin Firestore doc automatically.
        if (canonicalAdmin) {
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
      final isAdminRole = data['role'] == 'admin';

      if (!isAdminRole) {
        // Allow canonical admin email to self-promote (defensive)
        if (canonicalAdmin) {
          await userDoc.update({
            'role': 'admin',
            'isPremium': true,
            'subscriptionStatus': 'premium',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await FirebaseService.adminsRef.doc(uid).set({
            'email': email.trim(),
            'role': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
        await _auth.signOut();
        return false;
      }

      // Ensure admins/{uid} mirror exists (so security rules work).
      // Defensive: if read throws (permission-denied on a non-existent doc),
      // fall through to create.
      bool mirrorExists = false;
      try {
        final adminMirror = await FirebaseService.adminsRef.doc(uid).get();
        mirrorExists = adminMirror.exists;
      } catch (_) {
        // Permission denied — mirror doc doesn't exist yet. Create below.
      }
      if (!mirrorExists) {
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
      devlog.log('adminLogin error: $e');
      return false;
    }
  }

  // ==================== LOGOUT ====================
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ==================== HELPER: CREATE/UPDATE USER IN FIRESTORE ====================
  /// Creates the user's Firestore doc on first sign-in, or updates lastActiveAt
  /// on subsequent sign-ins. CRITICALLY: this method NEVER throws — if the
  /// Firestore write fails (rules, network, etc.), we still consider the user
  /// "logged in" via Firebase Auth so they aren't kicked back to the login
  /// screen. The Firestore doc is best-effort.
  static Future<void> _createOrUpdateUser(
    User? firebaseUser, {
    String? name,
    String? email,
    String? authMethod,
  }) async {
    if (firebaseUser == null) return;

    final userDoc = FirebaseService.usersRef.doc(firebaseUser.uid);

    try {
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
        // Existing user - update last active (best-effort, don't throw)
        try {
          await userDoc.update({
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          devlog.log('Best-effort lastActiveAt update failed (non-fatal): $e');
        }
      }
    } catch (e) {
      // If the doc read fails (e.g. permission denied), try a best-effort create.
      devlog.log('User doc read failed, attempting best-effort create: $e');
      try {
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
        await userDoc.set(newUser.toFirestore(), SetOptions(merge: true));
      } catch (e2) {
        devlog.log('Best-effort user doc create also failed (non-fatal): $e2');
        // Still don't throw — Firebase Auth sign-in succeeded.
      }
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

  // ==================== UPDATE USER PROFILE (EXTENDED) ====================
  /// Extended profile update used by the EditProfileScreen. Updates name +
  /// photoUrl at the top level and deep-merges the supplied `preferences`
  /// map (e.g. dateOfBirth, gender, qualification, city, targetExam) into the
  /// user's existing preferences map.
  ///
  /// `dateOfBirth` (if non-null) is converted to a Firestore Timestamp before
  /// being written into preferences.
  ///
  /// This implementation reads the existing user doc first, merges the
  /// preferences map locally (so we don't clobber existing preference keys),
  /// then writes the full updated doc back with .set(merge: true). This is
  /// more reliable than dot-notation writes which can fail silently if the
  /// doc doesn't exist or if Firestore rules are misconfigured.
  static Future<void> updateProfileExtended({
    required String userId,
    String? name,
    String? photoUrl,
    Map<String, dynamic>? preferences,
  }) async {
    final userDocRef = FirebaseService.usersRef.doc(userId);

    // Build the top-level updates.
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) data['name'] = name;
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    // For preferences, read the existing doc and merge locally so we preserve
    // any preference keys that aren't being edited.
    if (preferences != null && preferences.isNotEmpty) {
      try {
        final existing = await userDocRef.get();
        Map<String, dynamic> existingPrefs = {};
        if (existing.exists) {
          final existingData = existing.data();
          if (existingData is Map) {
            final prefsVal = existingData['preferences'];
            if (prefsVal is Map) {
              existingPrefs = Map<String, dynamic>.from(prefsVal);
            }
          }
        }

        // Layer the new preferences on top.
        for (final entry in preferences.entries) {
          // Convert any DateTime values to Timestamp before writing.
          final value = entry.value is DateTime
              ? Timestamp.fromDate(entry.value as DateTime)
              : entry.value;
          existingPrefs[entry.key] = value;
        }

        data['preferences'] = existingPrefs;
      } catch (e) {
        // If the read fails (e.g. doc doesn't exist or rules issue), fall back
        // to writing just the new preferences as a fresh map. This still saves
        // the user's edits, just without preserving old keys.
        final freshPrefs = <String, dynamic>{};
        for (final entry in preferences.entries) {
          final value = entry.value is DateTime
              ? Timestamp.fromDate(entry.value as DateTime)
              : entry.value;
          freshPrefs[entry.key] = value;
        }
        data['preferences'] = freshPrefs;
      }
    }

    await userDocRef.set(
      data,
      SetOptions(merge: true),
    );
  }

  // ==================== DELETE ACCOUNT ====================
  static Future<void> deleteAccount() async {
    if (currentUser != null) {
      await FirebaseService.usersRef.doc(currentUser!.uid).delete();
      await currentUser!.delete();
    }
  }
}

// =============================================================================
// ExamVault - Authentication Service
// Mobile OTP (real SMS via Firebase Phone Auth) + Email/Password (admin)
// =============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseService.auth;
  static final FirebaseFirestore _db = FirebaseService.firestore;

  // ==================== STATE STREAM ====================
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ==================== PHONE AUTH (real SMS OTP) ====================
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    required void Function(String smsCode) onCodeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
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

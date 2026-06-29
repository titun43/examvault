// =============================================================================
// ExamVault - Authentication Service
// Mobile OTP, Email/Password, Google Sign-In
// =============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseService.auth;
  static final FirebaseFirestore _db = FirebaseService.firestore;

  // ==================== STATE STREAM ====================
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  // ==================== PHONE AUTH (OTP) ====================
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

  // ==================== EMAIL/PASSWORD AUTH ====================
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

  // ==================== GOOGLE SIGN-IN ====================
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use the Web OAuth Client ID (client_type 3) as serverClientId — this
      // is the recommended setup for Google Sign-In on Android with Firebase.
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleSignInClientId,
        scopes: const ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      await _createOrUpdateUser(result.user, authMethod: 'google');
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ADMIN LOGIN ====================
  static Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    // Admin login এর জন্য special collection চেক করবে
    final adminDoc = await _db.collection('admins').doc(email).get();
    if (!adminDoc.exists) return false;

    final adminData = adminDoc.data() as Map<String, dynamic>;
    if (adminData['password'] != password) return false;
    if (adminData['isActive'] != true) return false;

    return true;
  }

  // ==================== LOGOUT ====================
  static Future<void> logout() async {
    try {
      await GoogleSignIn(
        serverClientId: AppConfig.googleSignInClientId,
      ).signOut();
    } catch (_) {}
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
        'fcmToken': await _getFcmToken(),
      });
    }
  }

  static Future<String?> _getFcmToken() async {
    try {
      return await FirebaseService.messaging.getToken();
    } catch (_) {
      return null;
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

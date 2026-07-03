// =============================================================================
// ExamVault - Auth Provider
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// Converts raw Firebase auth exceptions into user-friendly messages.
String _friendlyAuthError(Object e) {
  final s = e.toString();
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Contact admin.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and enter the correct 6-digit code.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Enter a valid 10-digit mobile number.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'app-not-authorized':
        return 'App signature not registered in Firebase. Contact admin.';
      case 'captcha-check-failed':
        return 'Verification challenge failed. Check your network and retry.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
  if (e is AppAuthException) {
    return e.message;
  }
  if (s.contains('network')) {
    return 'Network error. Check your internet connection.';
  }
  // Strip the "Exception:" prefix from generic Dart errors
  final cleaned = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
}

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  int? _resendToken; // allows "Resend OTP" without burning quota
  // True once Firebase Auth has emitted its FIRST auth-state event. Before
  // this, we don't yet know whether a persisted session will be restored, so
  // the splash screen must NOT navigate the user to the login page (otherwise
  // a logged-in user gets kicked to login on every cold start because the
  // restore happens asynchronously and can take longer than a fixed delay).
  bool _authInitialized = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  int? get resendToken => _resendToken;
  bool get authInitialized => _authInitialized;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    // Listen to the FIRST auth-state event to know when Firebase has finished
    // restoring any persisted session. We keep listening for subsequent
    // changes (sign-in / sign-out) afterwards.
    AuthService.authStateChanges.listen((firebaseUser) async {
      // Mark auth as initialized on the very first event (user OR null).
      if (!_authInitialized) {
        _authInitialized = true;
      }
      if (firebaseUser != null) {
        await loadUserData();
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await AuthService.getCurrentUserData();
      // If user is authenticated in Firebase but their Firestore doc is missing
      // (can happen right after auto-retrieval sign-in or due to rules issues),
      // try to (re)create it with merge so we don't overwrite existing data.
      if (_user == null && AuthService.currentUser != null) {
        final fbUser = AuthService.currentUser!;
        final newUser = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email,
          phoneNumber: fbUser.phoneNumber,
          photoUrl: fbUser.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        try {
          await FirebaseService.usersRef.doc(fbUser.uid).set(
            newUser.toFirestore(),
            SetOptions(merge: true),
          );
          _user = newUser;
        } catch (e) {
          // Firestore write failed (e.g. rules). Don't fail the login —
          // the user is still authenticated via Firebase Auth. Use the
          // locally-constructed UserModel so the app can proceed.
          _user = newUser;
        }
      } else if (_user != null && AuthService.currentUser != null) {
        // RECOVERY for users affected by the signup race-condition bug:
        // If the Firestore doc's name is exactly the fallback string 'User'
        // but Firebase Auth has a real displayName (set via updateDisplayName
        // during signup), the Firestore name is stale — recover it by using
        // and persisting the displayName. This fixes existing users who
        // signed up before the _createOrUpdateUser fix and see "User"
        // instead of their real name.
        final fsName = _user!.name;
        final fbUser = AuthService.currentUser!;
        final fbName = fbUser.displayName;
        if (fsName == 'User' &&
            fbName != null &&
            fbName.isNotEmpty &&
            fbName != 'User') {
          _user = _user!.copyWith(name: fbName, updatedAt: DateTime.now());
          // Persist the recovered name to Firestore so it sticks.
          try {
            await FirebaseService.usersRef.doc(fbUser.uid).set({
              'name': fbName,
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          } catch (e) {
            print('[AuthProvider] loadUserData: name recovery persist failed (non-fatal): $e');
            // Non-fatal — the in-memory _user already has the correct name
            // for this session.
          }
        }
      }
    } catch (e) {
      // Don't fail login if Firestore read fails — keep user authenticated.
      _errorMessage = null;
      if (AuthService.currentUser != null) {
        final fbUser = AuthService.currentUser!;
        _user = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email,
          phoneNumber: fbUser.phoneNumber,
          photoUrl: fbUser.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== PHONE AUTH ====================
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        onCodeSent: (verificationId, resendToken) {
          // Remember the resend token so "Resend OTP" can use it later.
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        onVerificationFailed: (e) {
          _errorMessage = e.message;
          onError(e.message);
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      _errorMessage = _friendlyAuthError(e);
      onError(_errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the resend token (call when the user changes their phone number
  /// or successfully verifies, so the next "Send OTP" starts fresh).
  void resetOtpState() {
    _resendToken = null;
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await loadUserData();
      return true;
    } catch (e) {
      _errorMessage = _friendlyAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== EMAIL AUTH ====================
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      await loadUserData();
      return true;
    } catch (e) {
      _errorMessage = _friendlyAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.signInWithEmail(email: email, password: password);
      await loadUserData();
      return true;
    } catch (e) {
      _errorMessage = _friendlyAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== ADMIN LOGIN ====================
  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isAdmin = await AuthService.adminLogin(email: email, password: password);
      if (isAdmin) {
        await loadUserData();
        return true;
      } else {
        _errorMessage = 'Invalid admin credentials';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _resendToken = null;
    notifyListeners();
  }

  // ==================== OPTIMISTIC PURCHASE UPDATES ====================
  // After a server-verified successful payment, the backend grants the
  // entitlement in Prisma (TestPurchase / PremiumSubscription rows). But the
  // Flutter app's local UserModel (loaded from Firestore) won't reflect that
  // until the next loadUserData() round-trip — and even then, Firestore
  // doesn't store purchase info (only Prisma does). These methods optimistically
  // update the local user so the UI flips from "Buy" to "Start" instantly
  // without waiting for a refresh or a server access-check.

  /// Optimistically mark a test as purchased locally AND persist to Firestore.
  /// Call this in the Razorpay onSuccess callback.
  ///
  /// PERSISTENCE (v1.36): We now write the purchased test ID to the user's
  /// Firestore document so it survives app restarts. Previously, the optimistic
  /// update was in-memory only — after the app restarted, loadUserData() loaded
  /// from Firestore (which didn't have the purchase), the local check failed,
  /// and the server-side access check also failed (because the backend
  /// entitlement wasn't granted yet). The user saw the test lock again —
  /// 'payment ta bhalo hoi na' (payment doesn't stick).
  ///
  /// By persisting to Firestore, the local check in TakeTestScreen passes
  /// immediately after app restart, giving the backend webhook time to grant
  /// the Prisma entitlement. Even if the webhook is misconfigured, the user
  /// always has access to what they paid for.
  void addPurchasedTest(String testId) async {
    if (_user == null) return;
    if (_user!.purchasedTests.contains(testId)) return;
    _user = _user!.copyWith(
      purchasedTests: [..._user!.purchasedTests, testId],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    // Persist to Firestore (fire-and-forget — the in-memory update above
    // already gives the user immediate access; this just makes it durable).
    try {
      await FirebaseService.usersRef.doc(_user!.id).set({
        'purchasedTests': _user!.purchasedTests,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[AuthProvider] addPurchasedTest: Firestore persist failed: $e');
      // Non-fatal — the in-memory update is still valid for this session.
    }
  }

  /// Optimistically mark the user as premium locally AND persist to Firestore.
  /// Call this in the Razorpay onSuccess callback for premium subscriptions.
  void markPremium({
    DateTime? expiry,
    String? planId,
  }) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      subscriptionStatus: SubscriptionStatus.premium,
      subscriptionExpiry: expiry,
      subscriptionPlanId: planId,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    // Persist to Firestore (fire-and-forget).
    try {
      final data = <String, dynamic>{
        'isPremium': true,
        'subscriptionStatus': 'premium',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (expiry != null) {
        data['subscriptionExpiry'] = expiry.toIso8601String();
      }
      if (planId != null) {
        data['subscriptionPlanId'] = planId;
      }
      await FirebaseService.usersRef.doc(_user!.id).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('[AuthProvider] markPremium: Firestore persist failed: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

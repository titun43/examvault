// =============================================================================
// ExamVault - Auth Provider
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  int? get resendToken => _resendToken;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    AuthService.authStateChanges.listen((firebaseUser) async {
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
      // (can happen right after auto-retrieval sign-in), try to (re)create it.
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
          await FirebaseService.usersRef.doc(fbUser.uid).set(newUser.toFirestore());
          _user = newUser;
        } catch (_) {
          // If Firestore write fails (e.g. rules), at least keep the user
          // "authenticated" so they don't get kicked back to login.
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

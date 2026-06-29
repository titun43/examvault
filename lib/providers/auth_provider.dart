// =============================================================================
// ExamVault - Auth Provider
// =============================================================================
// User login: Firebase Phone Auth (real OTP via SMS)
// Admin login: local credentials (admin@examvault.com / admin123)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/local_data_service.dart';

class AuthProvider extends ChangeNotifier {
  LocalUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;

  LocalUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isAdmin => _user?.role == 'admin';

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = LocalDataService.currentUser;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== PHONE OTP (Firebase) ====================
  /// Sends OTP to the given phone number via Firebase.
  /// [onCodeSent] is called when OTP is sent (UI switches to OTP entry).
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function() onCodeSent,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Normalize to +91XXXXXXXXXX
      String fullPhone = phoneNumber.trim();
      final digits = fullPhone.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length == 10) {
        fullPhone = '+91$digits';
      } else if (!fullPhone.startsWith('+')) {
        fullPhone = '+$digits';
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only, rare)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _errorMessage = _friendlyError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e);
    } catch (e) {
      _errorMessage = 'Failed to send OTP. Check your internet connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies the OTP entered by the user.
  Future<bool> verifyOtp({required String smsCode}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_verificationId == null) {
        _errorMessage = 'Please request OTP first.';
        return false;
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Firebase auth succeeded — find or create local user
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      _user = LocalDataService.findOrCreateByPhone(phone);
      _verificationId = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      _user = LocalDataService.findOrCreateByPhone(phone);
    } catch (_) {}
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Enter a valid 10-digit mobile number.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and enter the correct 6-digit code.';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Contact admin.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ==================== ADMIN LOGIN (local) ====================
  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final u = LocalDataService.loginWithIdentifier(
        identifier: email,
        password: password,
      );
      if (u == null) {
        _errorMessage = 'Invalid admin credentials';
        return false;
      }
      if (u.role != 'admin') {
        _errorMessage = 'This account does not have admin access.';
        return false;
      }
      _user = u;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== REFRESH USER ====================
  void refreshUser() {
    _user = LocalDataService.currentUser;
    notifyListeners();
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await LocalDataService.logout();
    _user = null;
    _verificationId = null;
    notifyListeners();
  }
}

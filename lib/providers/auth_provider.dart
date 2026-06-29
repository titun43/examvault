// =============================================================================
// ExamVault - Auth Provider
// =============================================================================
// User login: Local OTP (6-digit code generated on-device, shown in the UI).
//             Works 100% offline — no Firebase setup required.
//             (Firebase Phone Auth can be wired in later for real SMS; the
//              local flow is the reliable fallback that always works.)
// Admin login: local credentials (admin@examvault.com / admin123)
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../services/local_data_service.dart';

class AuthProvider extends ChangeNotifier {
  LocalUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingPhone;      // phone number waiting for OTP
  String? _generatedOtp;      // locally-generated OTP for the current session
  int? _otpExpiresAt;         // epoch-millis expiry

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

  // ==================== LOCAL OTP (offline, always works) ====================
  /// Sends a 6-digit OTP to the given phone number (locally generated).
  /// [onCodeSent] is called with the generated OTP so the UI can display it
  /// (since there's no real SMS in this offline-first flow).
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String otp) onCodeSent,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Normalize to 10-digit Indian mobile
      String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length == 10) {
        // ok
      } else if (digits.length > 10) {
        digits = digits.substring(digits.length - 10);
      } else {
        _errorMessage = 'Please enter a valid 10-digit mobile number.';
        return;
      }
      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
        _errorMessage = 'Please enter a valid Indian mobile number.';
        return;
      }

      _pendingPhone = '+91$digits';
      // Generate a 6-digit OTP
      final rnd = Random();
      _generatedOtp = (100000 + rnd.nextInt(900000)).toString();
      _otpExpiresAt = DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000;
      onCodeSent(_generatedOtp!);
    } catch (e) {
      _errorMessage = 'Failed to send OTP. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verifies the OTP entered by the user against the locally-generated one.
  Future<bool> verifyOtp({required String smsCode}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_generatedOtp == null || _pendingPhone == null) {
        _errorMessage = 'Please request OTP first.';
        return false;
      }
      if (_otpExpiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > _otpExpiresAt!) {
        _errorMessage = 'OTP expired. Please request a new OTP.';
        _generatedOtp = null;
        return false;
      }
      if (smsCode.trim() != _generatedOtp) {
        _errorMessage = 'Invalid OTP. Please check and enter the correct 6-digit code.';
        return false;
      }
      // OTP matched — find or create the local student record
      _user = LocalDataService.findOrCreateByPhone(_pendingPhone!);
      _generatedOtp = null;
      _pendingPhone = null;
      _otpExpiresAt = null;
      return true;
    } catch (e) {
      _errorMessage = 'Verification failed. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      // Make sure the admin account exists (safety net — also done at app start)
      await LocalDataService.ensureAdminAccount();
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
    await LocalDataService.logout();
    _user = null;
    _generatedOtp = null;
    _pendingPhone = null;
    _otpExpiresAt = null;
    notifyListeners();
  }
}

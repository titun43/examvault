// =============================================================================
// ExamVault - Auth Provider
// =============================================================================

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;

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
        onCodeSent: onCodeSent,
        onVerificationFailed: (e) {
          _errorMessage = e.message ?? 'Verification failed';
          onError(_errorMessage!);
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      _errorMessage = e.toString();
      onError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== GOOGLE SIGN-IN ====================
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.signInWithGoogle();
      await loadUserData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
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
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

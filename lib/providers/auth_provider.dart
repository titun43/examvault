// =============================================================================
// ExamVault - Auth Provider (Local, offline-first)
// =============================================================================
// Uses LocalDataService (SharedPreferences) instead of Firebase.
// Login works with BOTH mobile number AND email. Admin login is separate.
// =============================================================================

import 'package:flutter/material.dart';
import '../services/local_data_service.dart';

class AuthProvider extends ChangeNotifier {
  LocalUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

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
    // Restore session from local storage
    _user = LocalDataService.currentUser;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== LOGIN (Email OR Mobile + Password) ====================
  Future<bool> loginWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 400)); // UX delay
      final u = LocalDataService.loginWithIdentifier(
        identifier: identifier,
        password: password,
      );
      if (u == null) {
        final isEmail = identifier.contains('@');
        _errorMessage = isEmail
            ? 'Incorrect email or password. Please try again.'
            : 'Incorrect mobile number or password. Please try again.';
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

  // ==================== REGISTER ====================
  Future<bool> register({
    required String name,
    required String password,
    String? email,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      final u = LocalDataService.register(
        name: name,
        password: password,
        email: email,
        phone: phone,
      );
      if (u == null) {
        _errorMessage = 'Registration failed. Please try again.';
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

  // ==================== ADMIN LOGIN ====================
  Future<bool> adminLogin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      // Admin must login with admin email
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

  // ==================== REFRESH USER (e.g. after premium activated) ====================
  void refreshUser() {
    _user = LocalDataService.currentUser;
    notifyListeners();
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    await LocalDataService.logout();
    _user = null;
    notifyListeners();
  }
}

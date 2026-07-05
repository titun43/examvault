// =============================================================================
// ExamVault - Auth Provider
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/premium_cache_service.dart';
import '../services/exam_pack_cache_service.dart';
import '../services/access_service.dart';

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
  // True after dispose() is called. Guards fire-and-forget async methods
  // (_syncPremiumFromBackend) from calling notifyListeners() after the
  // provider is no longer in the widget tree.
  bool _disposed = false;
  // Real-time subscription to the user's Firestore document. When the admin
  // grants/revokes entitlements (isPremium, purchasedCategoryIds,
  // purchasedTests) or edits profile fields server-side, this listener
  // updates the in-memory _user model + invalidates AccessService caches so
  // the change reflects in the UI WITHOUT requiring the user to re-login.
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  /// True when the user is browsing WITHOUT an account (guest mode). The
  /// splash screen sends unauthenticated users straight into MainNavigation
  /// so they can browse and take FREE tests. Premium / paid content must
  /// check this and prompt the guest to sign in before purchase.
  bool get isGuest => _user == null && _authInitialized;
  bool get isPremium => _user?.isPremium ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  /// True if the user can open this category — premium subscription OR exam-pack purchase.
  bool hasCategoryAccess(String categoryId) => _user?.hasCategoryAccess(categoryId) ?? false;
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
        // Cancel the user-doc listener on sign-out so we don't get stray
        // updates for the previous user's document.
        _userDocSub?.cancel();
        _userDocSub = null;
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
      // USER-SPECIFIC LOCAL CACHE: apply the persisted premium flag (if any)
      // to the in-memory _user model BEFORE the finally block notifies the
      // UI. This gives an instant premium state on app launch / login —
      // preventing the "Locked" flash that occurs while the real-time Neon
      // DB sync runs in the background. See _applyCachedPremium() for details.
      await _applyCachedPremium();
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
    // REAL-TIME SYNC: fetch the authoritative premium status from the Neon
    // PostgreSQL database (via the backend API) and overwrite both the
    // in-memory _user model and the SharedPreferences cache. This is
    // fire-and-forget so the UI is NOT blocked — the cached value applied
    // above bridges the gap until this completes. See _syncPremiumFromBackend.
    _syncPremiumFromBackend();
    // REAL-TIME USER-DOC LISTENER: subscribe to the user's Firestore document
    // so admin-granted entitlements (isPremium, purchasedCategoryIds,
    // purchasedTests) and profile edits propagate live without re-login.
    // See _startUserDocListener.
    _startUserDocListener();
  }

  // ==================== REAL-TIME USER DOC SUBSCRIPTION ====================
  // Subscribes to the user's Firestore document. When the admin grants or
  // revokes entitlements server-side (e.g. manually adds a categoryId to
  // purchasedCategoryIds, or flips isPremium), this listener fires, updates
  // the in-memory _user model, invalidates the relevant AccessService cache
  // entries, and notifies the UI — all in real-time, WITHOUT requiring the
  // user to re-login or restart the app.
  //
  // FEEDBACK-LOOP SAFETY: when the app itself writes to the user doc (via
  // addPurchasedTest / addPurchasedCategory / markPremium), this listener
  // fires too — but the local _user is already updated optimistically, so
  // re-parsing from the snapshot is a harmless no-op (the data matches).
  void _startUserDocListener() {
    // Cancel any existing subscription (e.g. from a previous login session).
    _userDocSub?.cancel();
    _userDocSub = null;
    if (_user == null) return;
    final uid = _user!.id;
    _userDocSub = FirebaseService.usersRef.doc(uid).snapshots().listen(
      (doc) {
        if (_disposed || _user == null || _user!.id != uid) return;
        if (!doc.exists) return; // doc deleted — auth-state will handle sign-out

        final newUser = UserModel.fromFirestore(doc);
        final oldUser = _user!;

        // Detect entitlement changes that require AccessService cache
        // invalidation so stale ALLOWED/DENIED decisions don't bypass the
        // new entitlement state.
        final premiumChanged = newUser.isPremium != oldUser.isPremium;
        final categoriesChanged =
            !_sameStringList(newUser.purchasedCategoryIds, oldUser.purchasedCategoryIds);
        final testsChanged =
            !_sameStringList(newUser.purchasedTests, oldUser.purchasedTests);

        // Always adopt the fresh snapshot (name, photo, stats, entitlements).
        _user = newUser;

        if (premiumChanged) {
          // Premium affects ALL access decisions — clear everything so the
          // next check hits the server with the new premium state.
          AccessService.clearCache();
          // Keep the SharedPreferences premium cache in sync.
          if (newUser.isPremium) {
            PremiumCacheService.setPremium(userId: uid);
          } else {
            PremiumCacheService.clearPremium(uid);
          }
        } else {
          // Only invalidate caches for entitlements that actually changed.
          if (categoriesChanged) {
            // Clear stale exam-pack caches for removed categories.
            for (final id in oldUser.purchasedCategoryIds) {
              if (!newUser.purchasedCategoryIds.contains(id)) {
                AccessService.clearCacheForCategory(id);
              }
            }
          }
          if (testsChanged) {
            for (final id in oldUser.purchasedTests) {
              if (!newUser.purchasedTests.contains(id)) {
                AccessService.clearCacheForTest(id);
              }
            }
          }
        }

        if (!_disposed) notifyListeners();
      },
      onError: (e) {
        // Firestore rules error / network issue — non-fatal. The app
        // continues with the existing in-memory _user; the next login /
        // app launch will re-subscribe.
        print('[AuthProvider] user doc stream error (non-fatal): $e');
      },
    );
  }

  /// Order-insensitive equality check for two string lists.
  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  // ==================== USER-SPECIFIC PREMIUM CACHE ====================
  // These two methods implement the "User-Specific Local Cache" strategy:
  //
  //   1. _applyCachedPremium()    — reads isPremium_${userId} from
  //                                 SharedPreferences and applies it to the
  //                                 in-memory _user (instant UI, no flash).
  //   2. _syncPremiumFromBackend() — fetches the REAL-TIME status from Neon
  //                                  DB via the backend API and OVERWRITES
  //                                  the cache (source of truth).
  //
  // SECURITY: the cache is NEVER the source of truth. On every launch / login
  // the backend overwrites it. If the backend says NOT premium, the cache is
  // CLEARED so a stale "true" can't give a lapsed/refunded user free access.
  //
  // ACCOUNT MIXING PREVENTION: all cache keys are scoped by userId
  // (isPremium_${userId}). A different user logging into the same device
  // checks their OWN key and never inherits the previous user's premium.

  /// Reads the user-specific SharedPreferences cache and, if it says the user
  /// is premium, optimistically applies that to the in-memory _user model.
  /// This gives the UI an instant premium state on app launch / login —
  /// preventing the "Locked" flash that occurs while the backend sync runs.
  ///
  /// This is NOT the source of truth — it's a bridge. The real-time Neon DB
  /// fetch in [_syncPremiumFromBackend] will overwrite this shortly.
  Future<void> _applyCachedPremium() async {
    if (_user == null) return;
    // If the user is already marked premium from Firestore, no need to check
    // the cache — Firestore already has the truth for this session.
    if (_user!.isPremium) return;
    final cachedPremium = await PremiumCacheService.isPremiumCached(_user!.id);
    if (!cachedPremium) return;
    // Apply the cached premium status + expiry + planId to the local model.
    final cachedExpiry = await PremiumCacheService.getCachedExpiry(_user!.id);
    final cachedPlanId = await PremiumCacheService.getCachedPlanId(_user!.id);
    _user = _user!.copyWith(
      subscriptionStatus: SubscriptionStatus.premium,
      subscriptionExpiry: cachedExpiry,
      subscriptionPlanId: cachedPlanId,
      updatedAt: DateTime.now(),
    );
    // Don't notify here — the caller (loadUserData) will notify in finally.
  }

  /// Fetches the REAL-TIME premium status from the Neon PostgreSQL database
  /// (via the backend API → AccessService.checkPremiumOnly) and overwrites
  /// both the in-memory _user model and the user-specific SharedPreferences
  /// cache. Called after [loadUserData] completes (fire-and-forget) so the UI
  /// isn't blocked.
  ///
  /// SECURITY: This is the source of truth. If the backend says the user is
  /// NOT premium (subscription expired / cancelled / refunded / never paid),
  /// we CLEAR the local cache so a stale "true" can't give free access.
  Future<void> _syncPremiumFromBackend() async {
    if (_user == null || _disposed) return;
    try {
      final decision = await AccessService.checkPremiumOnly();
      if (_user == null || _disposed) return;
      if (decision.allowed) {
        // Backend confirms premium — ensure the cache agrees (in case the
        // cache was cleared but the backend still has the subscription).
        final alreadyCached =
            await PremiumCacheService.isPremiumCached(_user!.id);
        if (!alreadyCached) {
          await PremiumCacheService.setPremium(userId: _user!.id);
        }
        // If the local model doesn't yet reflect premium, update it.
        if (!_user!.isPremium) {
          _user = _user!.copyWith(
            subscriptionStatus: SubscriptionStatus.premium,
            updatedAt: DateTime.now(),
          );
          if (!_disposed) notifyListeners();
        }
      } else {
        // Backend says NOT premium — clear the cache to prevent a stale
        // "true" from giving a lapsed/refunded user free access.
        await PremiumCacheService.clearPremium(_user!.id);
        if (_user!.isPremium) {
          _user = _user!.copyWith(
            subscriptionStatus: SubscriptionStatus.free,
            subscriptionExpiry: null,
            subscriptionPlanId: null,
            updatedAt: DateTime.now(),
          );
          if (!_disposed) notifyListeners();
        }
      }
    } catch (e) {
      // Backend unreachable — leave the cache as-is. The cached value is our
      // best guess until the next launch. This is acceptable because:
      //   1. If cached=true and the user is actually premium, no harm.
      //   2. If cached=true but the user is actually lapsed, they get temporary
      //      access until the next successful sync — a minor, bounded risk.
      //   3. If cached=false, the user sees the paywall as expected.
      print('[AuthProvider] _syncPremiumFromBackend: sync failed (non-fatal): $e');
    }
  }

  // ==================== PHONE AUTH ====================
  /// SAFETY-NET TIMEOUT (added Jul 4, 2026): on some devices, Firebase's
  /// native phone-verification call can silently never invoke ANY callback
  /// (neither codeSent nor verificationFailed) — e.g. if the SafetyNet/Play
  /// Integrity/reCAPTCHA app-verification step hangs or its result gets lost
  /// natively. Without a timeout, the user is stuck staring at a dead button
  /// forever with zero feedback. We race the real call against a timer so
  /// the user ALWAYS sees a message within ~20s.
  bool _phoneAuthSettled = false;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _phoneAuthSettled = false;
    notifyListeners();

    void settleOnce(void Function() action) {
      if (_phoneAuthSettled) return;
      _phoneAuthSettled = true;
      action();
    }

    try {
      await Future.any<void>([
        AuthService.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: _resendToken,
          onCodeSent: (verificationId, resendToken) {
            settleOnce(() {
              // Remember the resend token so "Resend OTP" can use it later.
              _resendToken = resendToken;
              onCodeSent(verificationId, resendToken);
            });
          },
          onVerificationFailed: (e) {
            settleOnce(() {
              _errorMessage = e.message;
              onError(e.message);
            });
          },
          onCodeAutoRetrievalTimeout: (_) {},
        ),
        Future.delayed(const Duration(seconds: 20), () {
          settleOnce(() {
            _errorMessage =
                'OTP request timed out. This usually means a temporary '
                'network/verification issue. Please try again, or use '
                'Email sign-in instead. (code: client-timeout)';
            onError(_errorMessage!);
          });
        }),
      ]);
    } catch (e) {
      settleOnce(() {
        _errorMessage = _friendlyAuthError(e);
        onError(_errorMessage!);
      });
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
    // Stop listening to the user's Firestore doc so we don't get stray
    // updates after the user has signed out.
    _userDocSub?.cancel();
    _userDocSub = null;
    await AuthService.logout();
    _user = null;
    _resendToken = null;
    // NOTE: we intentionally do NOT clear the SharedPreferences premium cache
    // (isPremium_${userId}) on logout. The cache is USER-SPECIFIC — when a
    // DIFFERENT user logs into this device next, loadUserData() checks their
    // OWN key (isPremium_${newUserId}) and never reads the previous user's
    // key. This prevents account mixing. Clearing the old user's cache here
    // would be harmless but unnecessary — it'll be re-synced from the backend
    // if that user ever logs in again.
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

  /// Optimistically add a purchased category (exam pack) to the user's local
  /// model and persist to Firestore. Call this in the Razorpay onSuccess
  /// callback for exam-pack purchases so home/categories screens unlock
  /// immediately without waiting for the backend verify round-trip.
  ///
  /// PERSISTENT LOCAL CACHE (v1.44.6):
  /// In addition to the in-memory + Firestore updates, we now write the
  /// categoryId to the user-specific SharedPreferences exam-pack cache
  /// (examPackCategories_${userId}). This survives app restarts and closes
  /// the "Buy" flash gap that occurs when the test list screen opens and
  /// _serverHasExamPackAccess is still false (waiting for the server
  /// access-check). The cache is user-specific — a different user logging in
  /// checks their own key. See ExamPackCacheService for details.
  void addPurchasedCategory(String categoryId) async {
    if (_user == null) return;
    if (_user!.purchasedCategoryIds.contains(categoryId)) return;
    _user = _user!.copyWith(
      purchasedCategoryIds: [..._user!.purchasedCategoryIds, categoryId],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    // Persist to the USER-SPECIFIC SharedPreferences cache (survives restart).
    // This is the key fix for the exam-pack "Buy" flash — the cache is read
    // instantly on the next screen open, before the server sync completes.
    ExamPackCacheService.addCategory(
      userId: _user!.id,
      categoryId: categoryId,
    );
    try {
      await FirebaseService.usersRef.doc(_user!.id).set({
        'purchasedCategoryIds': _user!.purchasedCategoryIds,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[AuthProvider] addPurchasedCategory: Firestore persist failed: $e');
    }
  }

  /// Optimistically mark the user as premium locally, persist to Firestore,
  /// AND write to the user-specific SharedPreferences cache.
  /// Call this in the Razorpay onSuccess callback for premium subscriptions.
  ///
  /// USER-SPECIFIC LOCAL CACHE (v1.44.5):
  /// In addition to the existing in-memory + Firestore updates, we now write
  /// `isPremium_${userId} = true` to SharedPreferences. This survives app
  /// restarts and closes the "Locked" flash gap that occurs while the backend
  /// webhook grants the entitlement in Neon PostgreSQL. The cache is
  /// user-specific — a different user logging in checks their own key and
  /// never inherits this premium. On the next app launch / login,
  /// loadUserData() fetches the real-time status from Neon DB and overwrites
  /// this cache (see _syncPremiumFromBackend).
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
    // Persist to the USER-SPECIFIC SharedPreferences cache (survives restart).
    // This is the key fix for the post-payment "Locked" flash — the cache is
    // read instantly on the next app launch / screen open, before the backend
    // sync completes.
    PremiumCacheService.setPremium(
      userId: _user!.id,
      expiry: expiry,
      planId: planId,
    );
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

  @override
  void dispose() {
    _disposed = true;
    _userDocSub?.cancel();
    _userDocSub = null;
    super.dispose();
  }
}

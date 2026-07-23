// =============================================================================
// ExamVault - Login Screen
// User login: Mobile OTP (real SMS) OR Email/Password
// Admin login: HIDDEN — tap the logo 7 times to open the admin login door
// =============================================================================

import 'dart:async';
// NOTE: `hide AuthProvider` is REQUIRED — package:firebase_auth transitively
// re-exports `AuthProvider` from firebase_auth_platform_interface, which
// collides with our own AuthProvider (../../providers/auth_provider.dart).
// Without the hide, every `Consumer<AuthProvider>` in this file fails to
// resolve the type → `auth` becomes `Object?` → compile errors on every
// auth.isLoading / auth.errorMessage / auth.clearError access.
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../home/main_navigation.dart';
import '../../admin/admin_login_screen.dart';
import '../../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _currentMethod = 0; // 0=Mobile, 1=Email
  int _logoTapCount = 0;

  // Mobile auth
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  // True while we are WAITING for Firebase to send the OTP (between tapping
  // "Send OTP" and the onCodeSent / onError callback firing). During this
  // window we show an informative loading panel so the user knows the app is
  // working — not frozen. Firebase Phone Auth can take 2-20 seconds.
  bool _isSendingOtp = false;
  // Elapsed seconds counter for the loading panel — lets us show escalating
  // hints ("Sending..." -> "Verifying..." -> "Still working...").
  // Driven by a Timer in _sendOtp().
  int _otpWaitSeconds = 0;
  // True when the LAST OTP attempt failed with a Firebase CONFIG error
  // (operation-not-allowed / app-not-authorized / missing-client-identifier).
  // When true, we show a persistent banner on the Mobile tab telling the
  // user to use Email sign-in — instead of silently auto-switching tabs
  // (which previously crashed the rebuild because _pageController was never
  // attached to a PageView, leaving the user with NO visible feedback).
  bool _phoneAuthUnavailable = false;
  // The full error message from the last OTP attempt — shown inside the
  // persistent banner so the user / admin can see the EXACT Firebase error
  // code (operation-not-allowed, app-not-authorized, missing-client-identifier,
  // quota-exceeded, client-timeout, etc.) without needing adb logcat.
  // This is critical for remote diagnosis: different codes point to very
  // different fixes (Blaze plan, SHA-1, Play Integrity, SMS quota, etc.).
  String? _phoneAuthError;

  // Email auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  // True while a password-reset email is being sent (shows inline spinner on
  // the "Forgot Password?" link and disables further taps).
  bool _isResetting = false;

  @override
  void dispose() {
    _otpWaitTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Hidden admin entry — tap the logo 7 times to open AdminLoginScreen.
  void _onLogoTap() {
    _logoTapCount++;
    if (_logoTapCount == 7) {
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  /// Routes the user after a successful login: admin → AdminDashboard, else → MainNavigation.
  void _routeAfterLogin() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!mounted) return;
    final dest = auth.isAdmin ? const AdminDashboard() : const MainNavigation();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo (secret admin entry — tap 7 times)
              GestureDetector(
                onTap: _onLogoTap,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(
                'Welcome to ExamVault',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue your exam preparation',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Auth Method Tabs
              Row(
                children: [
                  Expanded(
                    child: _buildMethodTab('Mobile', 0, Icons.phone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMethodTab('Email', 1, Icons.email),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Method Content
              _currentMethod == 0 ? _buildMobileAuth() : _buildEmailAuth(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Informative loading panel shown while Firebase is sending the OTP.
  /// Shows evolving, reassuring messages based on how long we've been
  /// waiting, so the user knows the app is working — not frozen. Firebase
  /// Phone Auth can take 2-20 seconds. For Play Store installs it runs
  /// silently (Play Integrity); for direct APK installs a verification page
  /// may open (reCAPTCHA fallback — a Firebase SDK 4.x limitation).
  Widget _buildOtpLoadingPanel() {
    // Pick a message based on elapsed time — escalating detail.
    String title;
    String subtitle;
    IconData icon;
    if (_otpWaitSeconds < 3) {
      title = 'Sending OTP...';
      subtitle = 'Please wait a moment';
      icon = Icons.send;
    } else if (_otpWaitSeconds < 8) {
      title = 'Verifying...';
      subtitle = 'Firebase is verifying your number. This may take a few seconds.';
      icon = Icons.verified_user;
    } else if (_otpWaitSeconds < 15) {
      title = 'Still working...';
      subtitle = 'Verification in progress. If a verification page opens, '
          'please complete it — the OTP will arrive afterwards.';
      icon = Icons.hourglass_top;
    } else {
      title = 'Taking longer than usual...';
      subtitle = 'There may be a network issue. Please be patient, or try '
          'again in a moment.';
      icon = Icons.signal_wifi_off;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated spinner
          const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Elapsed seconds badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_otpWaitSeconds}s',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab(String title, int index, IconData icon) {
    final isSelected = _currentMethod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMethod = index;
          // Clear any stale OTP-unavailable banner + provider error when the
          // user moves away from / back to the Mobile tab, so a fresh attempt
          // starts clean.
          _phoneAuthUnavailable = false;
          _phoneAuthError = null;
          Provider.of<AuthProvider>(context, listen: false).clearError();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MOBILE OTP AUTH ====================
  Widget _buildMobileAuth() {
    return Column(
      children: [
        // Persistent "OTP unavailable" banner — shown when the last attempt
        // failed with a Firebase config error (Phone Auth not enabled in the
        // Firebase Console, or the app's SHA-1/SHA-256 not registered).
        // This replaces the old behavior of silently auto-switching to the
        // Email tab (which crashed the rebuild and left the user with zero
        // visible feedback — "kichui hoi na").
        if (_phoneAuthUnavailable) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorColor.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sms_failed, size: 20, color: AppTheme.errorColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobile OTP is currently unavailable',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please use Email sign-in — tap the "Email" tab above.',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      // Show the EXACT Firebase error code/message so the
                      // admin can diagnose remotely. Different codes need
                      // different fixes:
                      //   operation-not-allowed  → Firebase Spark plan (upgrade to Blaze) OR Phone Auth not enabled
                      //   app-not-authorized      → SHA-1 fingerprint not registered in Firebase Console
                      //   missing-client-identifier → reCAPTCHA / Play Integrity / SHA issue
                      //   quota-exceeded          → daily SMS limit hit
                      //   client-timeout          → 20s safety-net fired (network / Play Integrity hung)
                      if (_phoneAuthError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _phoneAuthError!,
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          enabled: !_otpSent,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            hintText: '9876543210',
            prefixText: '+91 ',
            prefixIcon: const Icon(Icons.phone_outlined),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          Text(
            'Enter OTP sent to +91 ${_phoneController.text}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Pinput(
            controller: _otpController,
            length: 6,
            defaultPinTheme: PinTheme(
              width: 50,
              height: 56,
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onCompleted: (pin) {
              _verifyOtp();
            },
          ),
        ],
        const SizedBox(height: 16),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: auth.isLoading
                      ? null
                      : () {
                          // Clear any previous error so the inline message
                          // disappears as soon as the user retries.
                          auth.clearError();
                          if (_otpSent) {
                            _verifyOtp();
                          } else {
                            _sendOtp();
                          }
                        },
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_otpSent ? 'Verify OTP & Login' : 'Send OTP'),
                ),
                // ─── Informative loading panel while sending OTP ───
                // Firebase Phone Auth can take 2-20 seconds. Without this
                // panel the user sees a dead spinner and thinks the app has
                // frozen ("kichui hocche na"). We show evolving, reassuring
                // messages so the user knows the app is working.
                if (_isSendingOtp && !_otpSent) ...[
                  const SizedBox(height: 16),
                  _buildOtpLoadingPanel(),
                ],
                if (_otpSent) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                auth.clearError();
                                _otpController.clear();
                                _sendOtp(); // resend uses forceResendingToken
                              },
                        child: const Text('Resend OTP'),
                      ),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () {
                          final a = Provider.of<AuthProvider>(context, listen: false);
                          a.clearError();
                          a.resetOtpState();
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                            _verificationId = null;
                          });
                        },
                        child: const Text('Change number'),
                      ),
                    ],
                  ),
                ],
                // Inline error display — persists below the button so the user
                // can read WHY the OTP did not arrive (e.g. app-not-authorized,
                // quota-exceeded) instead of a fleeting SnackBar that is easy
                // to miss. Replaces the old amber "Did not receive OTP?" hint.
                if (auth.errorMessage != null && !_otpSent) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ==================== EMAIL AUTH ====================
  Widget _buildEmailAuth() {
    return Column(
      children: [
        if (_isSignUp)
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (_isSignUp) const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // "Forgot Password?" link — only shown in the Sign-In section (NOT
        // sign-up). Right-aligned below the password field. Tapping it sends
        // a Firebase password-reset email to whatever is in the email field.
        if (!_isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: _isResetting
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _resetPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(tr(context, 'auth_forgot_password')),
                  ),
          ),
        const SizedBox(height: 16),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return ElevatedButton(
              onPressed: auth.isLoading ? null : _emailAuth,
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _isSignUp = !_isSignUp;
            });
          },
          child: Text(
            _isSignUp
                ? 'Already have an account? Sign In'
                : 'Don\'t have an account? Sign Up',
          ),
        ),
      ],
    );
  }

  // ==================== OTP METHODS ====================
  Timer? _otpWaitTimer;

  void _sendOtp() async {
    // Reset the "OTP unavailable" banner for this fresh attempt — it will be
    // re-set if THIS attempt fails with a config error.
    _phoneAuthUnavailable = false;
    _phoneAuthError = null;
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }

    // Normalize: digits only
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');

    // Build full phone with country code
    String fullPhone;
    if (rawPhone.startsWith('+')) {
      fullPhone = rawPhone;
    } else if (digits.length == 10) {
      // 10-digit Indian number → prepend +91
      fullPhone = '+91$digits';
    } else if (digits.length > 10) {
      // Already includes country code (e.g. 919876543210)
      fullPhone = '+$digits';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    // ─── Start the "sending OTP" loading state ───
    // Firebase Phone Auth can take 2-20 seconds. For Play Store installs
    // it runs silently (Play Integrity). For direct APK installs it may
    // open a verification page (reCAPTCHA fallback) — that's a Firebase
    // SDK limitation in 4.x, not an app bug. Without a visible loading
    // indicator the user thinks the app has frozen ("kichui hocche na").
    // We tick a counter every second and show escalating messages.
    _isSendingOtp = true;
    _otpWaitSeconds = 0;
    setState(() {});
    _otpWaitTimer?.cancel();
    _otpWaitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isSendingOtp || !mounted) return;
      _otpWaitSeconds++;
      setState(() {});
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId, _) {
        _stopOtpWait();
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to $fullPhone')),
        );
      },
      onError: (error) {
        _stopOtpWait();
        // Show a persistent banner with the EXACT error message on the Mobile
        // tab. We NO LONGER auto-switch to the Email tab — the old code called
        // _pageController.animateToPage(), but _pageController was never
        // attached to a PageView (the tabs use conditional rendering, not a
        // PageView). That call threw inside setState, which prevented
        // markNeedsBuild() from running, so the UI never rebuilt AND the
        // SnackBar below was never reached — the user saw nothing
        // ("kichui hoi na"). Now we set a flag + show the SnackBar reliably.
        //
        // We show the banner for ALL errors (not just config errors) so the
        // admin can see timeout / quota errors too — they all need different
        // fixes:
        //   operation-not-allowed     → Firebase Spark plan OR Phone Auth not enabled
        //   app-not-authorized        → SHA-1 fingerprint not in Firebase Console
        //   missing-client-identifier → reCAPTCHA / Play Integrity / SHA issue
        //   quota-exceeded            → daily SMS limit hit
        //   client-timeout            → 20s safety-net fired (network/Integrity hung)
        _phoneAuthUnavailable = true;
        _phoneAuthError = error;
        if (!mounted) return;
        setState(() {}); // rebuild to show the banner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            duration: const Duration(seconds: 6),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
      // BUGFIX (auto-verify navigation): When Android auto-retrieves the SMS,
      // Firebase calls verificationCompleted → the user is silently signed
      // in. Previously, this callback did not exist, so the LoginScreen
      // stayed on the OTP entry / loading screen even though the user was
      // already logged in. The user had to press Back to discover they were
      // logged in. Now we stop the loading timer and navigate to home /
      // admin dashboard — exactly the same path as manual OTP verification.
      onAutoVerified: (User? user) async {
        if (!mounted) return;
        // Capture context-dependent refs BEFORE any await — using
        // BuildContext across an async gap is a Flutter antipattern and
        // triggers use_build_context_synchronously warnings.
        final messenger = ScaffoldMessenger.of(context);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        _stopOtpWait();
        // Clear OTP entry state so a stale OTP UI doesn't flash on screen
        // during the navigation transition.
        setState(() {
          _otpSent = false;
          _verificationId = null;
          _otpController.clear();
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('OTP auto-verified! Logging you in...'),
            duration: Duration(seconds: 2),
          ),
        );
        // Ensure AuthProvider has loaded the user's Firestore doc before
        // navigating. Without this, _routeAfterLogin() might read
        // auth.isAdmin == false (because _user is still null) and route an
        // admin to MainNavigation instead of AdminDashboard. The
        // authStateChanges listener ALSO calls loadUserData(), but it races
        // with this callback — awaiting here is idempotent and guarantees
        // _user is populated before we decide the destination.
        await auth.loadUserData();
        if (!mounted) return;
        _routeAfterLogin();
      },
    );
  }

  /// Stops the OTP-wait timer and clears the loading flag. Called from both
  /// onCodeSent and onError so the UI always settles no matter which path
  /// Firebase takes.
  void _stopOtpWait() {
    _isSendingOtp = false;
    _otpWaitSeconds = 0;
    _otpWaitTimer?.cancel();
    _otpWaitTimer = null;
    if (mounted) setState(() {});
  }

  void _verifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please request OTP first')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(
      verificationId: _verificationId!,
      smsCode: _otpController.text,
    );

    if (success && mounted) {
      _routeAfterLogin();
    } else if (auth.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // ==================== EMAIL AUTH METHODS ====================

  /// Sends a Firebase password-reset email to the address currently in the
  /// email field. Shown only in the Sign-In section via the "Forgot
  /// Password?" link. If the email field is empty, we ask the user to fill it
  /// first instead of letting Firebase throw a generic error.
  void _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'auth_enter_email_first'))),
      );
      return;
    }
    setState(() => _isResetting = true);
    try {
      await AuthService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'auth_reset_email_sent'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr(context, 'auth_reset_failed')}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  void _emailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (_isSignUp && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success;
    if (_isSignUp) {
      success = await auth.signUpWithEmail(
        email: email,
        password: password,
        name: _nameController.text.trim(),
      );
    } else {
      success = await auth.signInWithEmail(
        email: email,
        password: password,
      );
    }

    if (success && mounted) {
      _routeAfterLogin();
    } else if (auth.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          duration: const Duration(seconds: 5),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

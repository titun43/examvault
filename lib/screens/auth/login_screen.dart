// =============================================================================
// ExamVault - Login Screen
// User login: Mobile OTP (real SMS) OR Email/Password
// Admin login: HIDDEN — tap the logo 7 times to open the admin login door
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation.dart';
import '../../admin/admin_login_screen.dart';
import '../../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  int _currentMethod = 0; // 0=Mobile, 1=Email
  int _logoTapCount = 0;

  // Mobile auth
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;

  // Email auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _pageController.dispose();
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

  Widget _buildMethodTab(String title, int index, IconData icon) {
    final isSelected = _currentMethod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMethod = index;
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
            return ElevatedButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
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
            );
          },
        ),
        if (_otpSent)
          TextButton(
            onPressed: () {
              setState(() {
                _otpSent = false;
                _otpController.clear();
                _verificationId = null;
              });
            },
            child: const Text('Change mobile number'),
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
  void _sendOtp() async {
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

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to $fullPhone')),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            duration: const Duration(seconds: 5),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
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

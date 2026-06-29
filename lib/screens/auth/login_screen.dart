// =============================================================================
// ExamVault - Login Screen (Email / Mobile + Password, offline)
// =============================================================================
// - Login works with BOTH email and mobile number + password.
// - Admin login is HIDDEN: tap the logo 7 times to reveal the admin door.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  int _currentMethod = 0; // 0=Mobile, 1=Email
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailRegController = TextEditingController();
  final _phoneRegController = TextEditingController();
  final _passwordRegController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  int _logoTapCount = 0;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailRegController.dispose();
    _phoneRegController.dispose();
    _passwordRegController.dispose();
    super.dispose();
  }

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
              const SizedBox(height: 24),

              // Demo credentials hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Text(
                          'Demo Login',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Email: demo@examvault.com\nMobile: 9876543210\nPassword: demo123',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _isSignUp ? _buildSignUpForm() : _buildSignInForm(),

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
          ),
        ),
      ),
    );
  }

  // ==================== SIGN IN ====================
  Widget _buildSignInForm() {
    return Column(
      children: [
        // Method Tabs
        Row(
          children: [
            Expanded(child: _buildMethodTab('Mobile', 0, Icons.phone)),
            const SizedBox(width: 12),
            Expanded(child: _buildMethodTab('Email', 1, Icons.email)),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _identifierController,
          keyboardType:
              _currentMethod == 0 ? TextInputType.phone : TextInputType.emailAddress,
          maxLength: _currentMethod == 0 ? 10 : null,
          decoration: InputDecoration(
            labelText: _currentMethod == 0 ? 'Mobile Number' : 'Email Address',
            hintText: _currentMethod == 0 ? '9876543210' : 'you@example.com',
            prefixText: _currentMethod == 0 ? '+91 ' : null,
            prefixIcon: Icon(_currentMethod == 0
                ? Icons.phone_outlined
                : Icons.email_outlined),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return ElevatedButton(
              onPressed: auth.isLoading ? null : _signIn,
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Sign In'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMethodTab(String title, int index, IconData icon) {
    final isSelected = _currentMethod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMethod = index;
          _identifierController.clear();
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
            Icon(icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade600),
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

  void _signIn() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_currentMethod == 0) {
      // Mobile validation: 10 digits
      final digits = identifier.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a valid 10-digit mobile number')),
        );
        return;
      }
    } else {
      // Email validation
      if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(identifier)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithIdentifier(
      identifier: identifier,
      password: password,
    );

    if (success && mounted) {
      // Route admins to AdminDashboard, students to MainNavigation
      final dest = auth.isAdmin
          ? const AdminDashboard()
          : const MainNavigation();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dest),
      );
    } else if (auth.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  // ==================== SIGN UP ====================
  Widget _buildSignUpForm() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailRegController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email (optional)',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phoneRegController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Mobile Number (optional)',
            hintText: '9876543210',
            prefixText: '+91 ',
            prefixIcon: const Icon(Icons.phone_outlined),
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Provide either email or mobile number to sign up.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordRegController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password (min 6 characters)',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return ElevatedButton(
              onPressed: auth.isLoading ? null : _signUp,
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Create Account'),
            );
          },
        ),
      ],
    );
  }

  void _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailRegController.text.trim();
    final phone = _phoneRegController.text.trim();
    final password = _passwordRegController.text;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    if (email.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide email or mobile number')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter a valid 10-digit mobile number')),
        );
        return;
      }
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      name: name,
      password: password,
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else if (auth.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

// =============================================================================
// ExamVault - Login Screen
// =============================================================================
// User login: Mobile number → Firebase OTP → auto-register/login
// Admin login: HIDDEN — tap logo 7 times to open admin login door
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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  int _logoTapCount = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
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
              const SizedBox(height: 50),
              // Logo (secret admin entry — tap 7 times)
              GestureDetector(
                onTap: _onLogoTap,
                child: Container(
                  width: 84,
                  height: 84,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.school, size: 42, color: Colors.white),
                ),
              ),
              const Text(
                'Welcome to ExamVault',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Login with your mobile number to continue',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              _buildPhoneAuth(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== MOBILE OTP AUTH ====================
  Widget _buildPhoneAuth() {
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          Text(
            'Enter the 6-digit OTP sent to +91 ${_phoneController.text}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Pinput(
            controller: _otpController,
            length: 6,
            defaultPinTheme: PinTheme(
              width: 50,
              height: 56,
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onCompleted: (_) => _verifyOtp(),
          ),
        ],
        const SizedBox(height: 20),
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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
              });
            },
            child: const Text('Change mobile number'),
          ),
      ],
    );
  }

  void _sendOtp() {
    final rawPhone = _phoneController.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.sendOtp(
      phoneNumber: digits,
      onCodeSent: () {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to +91 $digits')),
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

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOtp(smsCode: _otpController.text);

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
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

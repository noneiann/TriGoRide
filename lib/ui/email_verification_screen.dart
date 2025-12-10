import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/login_screen.dart';
import '../services/auth_services.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String _message = '';

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final user = _authService.getUser();
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() {
          _message = 'Verification email sent! Please check your inbox.';
          _loading = false;
        });
      } else if (user != null && user.emailVerified) {
        setState(() {
          _message = 'Your email is already verified!';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to send verification email. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _loading = true);

    try {
      final user = _authService.getUser();
      if (user != null) {
        await user.reload();
        final updatedUser = _authService.getUser();

        if (updatedUser != null && updatedUser.emailVerified) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        } else {
          setState(() {
            _message = 'Email not verified yet. Please check your inbox.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to check verification status.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.getUser();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_unread,
                size: 100,
                color: Colors.orange,
              ),
              const SizedBox(height: 40),
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'A verification email has been sent to:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Please check your inbox and click the verification link to activate your account.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _message.contains('sent') ||
                            _message.contains('verified')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('sent') ||
                              _message.contains('verified')
                          ? Colors.green
                          : Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
              _loading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _checkVerificationStatus,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('I\'VE VERIFIED MY EMAIL'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _resendVerificationEmail,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('RESEND VERIFICATION EMAIL'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _logout,
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

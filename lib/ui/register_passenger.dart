import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/choose_user.dart';
import 'package:tri_go_ride/ui/login_screen.dart';
import 'package:tri_go_ride/ui/email_verification_screen.dart';
import '../services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_home_screen.dart';

class RegisterPassenger extends StatefulWidget {
  const RegisterPassenger({super.key});

  @override
  State<RegisterPassenger> createState() => _RegisterPassengerState();
}

/// TODO: Fucking implement this shit, for now it is a copy of the login splash screen
class _RegisterPassengerState extends State<RegisterPassenger> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _emergencyNumber = TextEditingController();
  final AuthService _authService = AuthService();

  String _error = '';
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  void _register() async {
    setState(() => _loading = true);
    try {
      // Validate emergency number
      if (_emergencyNumber.text.trim().isEmpty) {
        setState(() {
          _error = 'Emergency contact number is required';
          _loading = false;
        });
        return;
      }

      final pwd = _password.text.trim();
      final confirm = _confirmPassword.text.trim();
      if (pwd != confirm) {
        setState(() {
          _error = 'Register Failed: Passwords do not match';
        });
        return;
      }

      // Create user with Firebase Auth
      User? user = await _authService.register(
        _email.text.trim(),
        pwd,
      );
      if (user != null) {
        // Send email verification
        await user.sendEmailVerification();

        // Store additional profile info in Firestore
        await _authService.firestore.collection('users').doc(user.email).set({
          'uid': user.uid,
          'username': _username.text.trim(),
          'email': _email.text.trim(),
          'phone': _phoneNumber.text.trim(),
          'emergencyNum': _emergencyNumber.text.trim(),
          'password': _password.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'userType': "Passenger",
        });

        // Show verification dialog
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
          );
        }
      }
    } catch (e) {
      String errorMessage = 'Registration failed';

      // Parse Firebase auth errors
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account with this email already exists.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address format.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage =
            'Password is too weak. Please use at least 6 characters.';
      } else if (e.toString().contains('operation-not-allowed')) {
        errorMessage = 'Email/password accounts are not enabled.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Registration failed. Please try again.';
      }

      setState(() {
        _error = errorMessage;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme and brightness.
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final containerColor = isDark ? Colors.grey[800] : Colors.white;
    final borderColor = theme.dividerColor;
    final hintTextStyle = TextStyle(color: theme.hintColor);
    final iconColor = theme.iconTheme.color ?? Colors.grey;

    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Logo Container - always at the top.
            Container(
                padding: EdgeInsets.only(top: 64),
                height: 200, // set the image height
                alignment: Alignment.center,
                child: Image.asset(
                  isDark
                      ? 'assets/TriGoRideLogo1.png'
                      : 'assets/TriGoRideLogo.png',
                  height: 240, // set the image height
                  width: 240, // (optional) set the image width
                )),
            SizedBox(height: 50),
            // The rest of the login UI.
            Container(
                width: width,
                padding: EdgeInsets.symmetric(horizontal: 32),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Register",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineLarge?.color,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    Text("Please register to continue"),
                  ],
                )),

            SizedBox(height: 40),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Email Field with icon fixed using a Row and Expanded widget.
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.person,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _username,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Username',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.email,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _email,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Email',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.phone,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _phoneNumber,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Phone Number',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.emergency,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _emergencyNumber,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Emergency Contact Number*',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    // Password Field with show/hide functionality and centered IconButton.
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.lock,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _password,
                              obscureText: !_showPassword,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Password',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.02),
                          // Center the IconButton in its allocated space.
                          IconButton(
                            padding: EdgeInsets.all(0.01),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            color: iconColor,
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: width * 0.9,
                      height: height * 0.06,
                      padding: EdgeInsets.all(width * 0.03),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: containerColor,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.lock,
                            color: iconColor,
                          ),
                          SizedBox(width: width * 0.02),
                          Expanded(
                            child: TextField(
                              controller: _confirmPassword,
                              obscureText: !_showConfirmPassword,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Confirm Password',
                                hintStyle: hintTextStyle,
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.02),
                          // Center the IconButton in its allocated space.
                          IconButton(
                            padding: EdgeInsets.all(0.01),
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            color: iconColor,
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Display error if any.
                    SizedBox(height: 10),
                    if (_error.isNotEmpty)
                      Text(
                        _error,
                        style: TextStyle(color: Colors.red),
                      ),
                    SizedBox(height: 10),
                    // Login Button or Progress Indicator.
                    _loading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text("Register"),
                          ),
                    SizedBox(height: 10),
                    // Navigation to registration.
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LoginPage()),
                        );
                      },
                      child: Text(
                        "Already have an account? Login",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/choose_user.dart';
import '../services/auth_services.dart';
import './screens/passenger_home_screen.dart';

class RegisterDriver extends StatefulWidget {
  @override
  State<RegisterDriver> createState() => _RegisterDriverState();
}
/// TODO: Fucking implement this shit, for now it is a copy of the login splash screen
class _RegisterDriverState extends State<RegisterDriver> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final AuthService _authService = AuthService();

  String _error = '';
  bool _loading = false;
  bool _showPassword = false; // State variable for password visibility.
  bool _showConfirmPassword =false;
  void _login() async {
    setState(() => _loading = true);
    try {
      User? user = await _authService.signIn(
        _email.text.trim(),
        _password.text.trim(),
      );
      if (user != null) {
        // Navigate to Passenger home screen after successful login.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Login failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _register() async {
    setState(() => _loading = true);
    try {
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
        // Store additional profile info in Firestore
        await _authService.firestore
            .collection('users')
            .doc(user.email)
            .set({
          'uid': user.uid,
          'username': _username.text.trim(),
          'email': _email.text.trim(),
          'phone': _phoneNumber.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'userType': "Driver",
          'verified': false,
          'firstTimeLogIn': true
        });


        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Registration Successful"),
            content: Text("Welcome! Proceed to account setup to setup your driver profile."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen()),
                  );
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
      }


    } catch (e) {
      setState(() {
        _error = 'Registration failed: ${e.toString()}';
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
              height: 100,
              alignment: Alignment.center,
              child: Icon(
                Icons.electric_rickshaw,
                size: 100,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 100),
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
                )
            ),

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
                      child: Text("Register"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    // Navigation to registration.
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChooseUser()),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/choose_user.dart';
import 'package:tri_go_ride/ui/root_page_rider.dart';
import '../services/auth_services.dart';
import './screens/passenger_home_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();

  String _error = '';
  bool _loading = false;
  bool _showPassword = false; // State variable for password visibility.

  void _login() async {
    setState(() => _loading = true);
    CollectionReference<Map<String, dynamic>> users =
    FirebaseFirestore.instance.collection('users');


    try {
      User? user = await _authService.signIn(
        _email.text.trim(),
        _password.text.trim(),
      );
      if (user != null) {
        // Navigate to Passenger home screen after successful login.
        DocumentSnapshot<Map<String, dynamic>> userSnapshot =
        await users.doc(user.email).get();
        if (userSnapshot.exists) {
          final data = userSnapshot.data()!;

          // if (data["userType"] == 'Passenger'){
          //   Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(builder: (_) => RootPage()),
          //   );
          // }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RootPageRider()),
          );
        } else{
          showDialog(context: context, builder: (context) => AlertDialog(
            title: Text("User not found"),
            content: Text("No user exists in our database!"),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Okay'))
            ],
          ));
        }
      }
    } catch (e) {
      setState(() => _error = 'Login failed: ${e.toString()}');
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
              padding: EdgeInsets.only(top: 96),
              height: 100,
              alignment: Alignment.center,
              child: Icon(
                Icons.electric_rickshaw,
                size: 100,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 128),
            Container(
                width: width,
                padding: EdgeInsets.symmetric(horizontal: 32),
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineLarge?.color,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    Text("Please login to continue"),
                  ],
                )
            ),
            SizedBox(height: 40),
            // The rest of the login UI.
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
                    // Display error if any.
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
                      onPressed: _login,
                      child: Text("Login"),
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
                        "Don't have an account? Register",
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

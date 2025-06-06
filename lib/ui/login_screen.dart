import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/choose_user.dart';
import 'package:tri_go_ride/ui/first_time_profile_setup.dart';
import 'package:tri_go_ride/ui/root_page_passenger.dart';
import 'package:tri_go_ride/ui/root_page_rider.dart';
import '../services/auth_services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();

  String _error = '';
  bool _loading = false;
  bool _showPassword = false; // State variable for password visibility.


  Future<void> _login() async {
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

          if (data["userType"] == 'Passenger'){
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RootPagePassenger()),
            );
          } else {
            if (data["verified"] == false) {
              showDialog(context: context, builder: (context) => AlertDialog(
                title: Text("Driver not verified"),
                content: Text("Please wait until the admin verifies your account!\n Would You like to setup your account?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text("No")),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FirstTimeProfileSetup())), child: Text("Yes")),
                  ])
              );
            } else {

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => RootPageRider()),
              );
            }
          }

        } else {
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
              padding: const EdgeInsets.only(top: 60),
              height: 240,  // bigger container
              alignment: Alignment.center,
              child: Image.asset(
                'assets/TriGoRideLogo.png',
                height: 240,  // set the image height
                width: 240,   // (optional) set the image width
                color: Colors.orange,
                fit: BoxFit.contain,
              ),
            ),

            SizedBox(height: 64),
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
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Login"),
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_services.dart';
import 'passenger_home_screen.dart';
import 'register_screen.dart';

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

  void _login() async {
    setState(() => _loading = true);
    try {
      User? user = await _authService.signIn(_email.text.trim(), _password.text.trim());
      if (user != null) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Login failed: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[300],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.electric_rickshaw, size: 100, color: Colors.white),
                SizedBox(height: 20),
                TextField(
                  controller: _email,
                  decoration: InputDecoration(hintText: 'Email', filled: true, fillColor: Colors.white),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Password', filled: true, fillColor: Colors.white),
                ),
                SizedBox(height: 10),
                if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
                _loading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _login,
                  child: Text("Login"),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen())),
                  child: Text("Don't have an account? Register", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

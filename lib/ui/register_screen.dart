import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/ui/screens/passenger_home_screen.dart';
import '../services/auth_services.dart';


class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final AuthService _authService = AuthService();

  String _error = '';
  bool _loading = false;

  void _register() async {
    setState(() => _loading = true);
    try {
      User? user = await _authService.register(_email.text.trim(), _password.text.trim());
      if (user != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = 'Register failed: ${e.toString()}');
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
                Icon(Icons.person_add_alt_1, size: 100, color: Colors.white),
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
                  onPressed: _register,
                  child: Text("Register"),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Already have an account? Login", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

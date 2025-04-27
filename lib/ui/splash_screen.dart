import 'package:flutter/material.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/login_screen.dart';

import 'root_page_passenger.dart';
import 'root_page_rider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<Widget> _startScreenFuture;

  @override
  void initState() {
    super.initState();
    _startScreenFuture = _decideStartScreen();
  }

  Future<Widget> _decideStartScreen() async {
    final auth = AuthService();
    final user = auth.getUser();
    if (user == null) return const LoginPage();

    try {
      final doc = await auth.firestore
          .collection('users')
          .doc(user.email)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['userType'] == 'Passenger'
            ? const RootPagePassenger()
            : const RootPageRider();
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // let the keyboard inset instead of disabling it
      resizeToAvoidBottomInset: true,
      body: FutureBuilder<Widget>(
        future: _startScreenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Icon(
                Icons.electric_rickshaw,
                size: 64,
                color: Colors.orange,
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const LoginPage();
          }
          return snapshot.data!;
        },
      ),
    );
  }
}

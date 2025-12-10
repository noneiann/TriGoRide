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

    debugPrint('🔍 Checking auth state...');
    debugPrint('User: ${user?.email}');

    if (user == null) {
      debugPrint('❌ No user found, showing LoginPage');
      return const LoginPage();
    }

    // Check if email is verified
    await user.reload(); // Refresh user state
    final currentUser = auth.getUser();
    if (currentUser != null && !currentUser.emailVerified) {
      debugPrint('⚠️ Email not verified, logging out and showing LoginPage');
      await auth.signOut();
      return const LoginPage();
    }

    try {
      debugPrint('📡 Fetching user data from Firestore...');
      final doc =
          await auth.firestore.collection('users').doc(user.email).get();

      debugPrint('📥 Document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data()!;
        final userType = data['userType'];
        debugPrint('✅ UserType: $userType');

        return userType == 'Passenger'
            ? const RootPagePassenger()
            : const RootPageRider();
      } else {
        debugPrint('⚠️ User document not found in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Auto-login failed: $e');
    }

    debugPrint('⤵️ Falling back to LoginPage');
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

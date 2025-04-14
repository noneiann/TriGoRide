import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart'; // replace with your starting screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriGoRide',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

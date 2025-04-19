import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/splash_screen.dart'; // Replace with your starting screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable system overlays to ensure the status bar is shown.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;
    // Define your light and dark themes.
    final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.orange,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.black),
        iconTheme: IconThemeData(color: Colors.black54),

      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white, backgroundColor: Colors.orange,
        ),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.orange,
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.orange,
        titleTextStyle: TextStyle(color: Colors.orange)
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.orange,
        ),
      ),
    );

    // Use AnnotatedRegion to specify system UI style (e.g., dark icons) so the status bar remains visible.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDarkMode
          ? SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent, // Or any color you want
      )
          : SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: MaterialApp(
        title: 'TriGoRide',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system, // Automatically switch based on system setting.
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

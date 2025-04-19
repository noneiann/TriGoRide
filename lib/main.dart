import 'package:cloudinary_flutter/cloudinary_context.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/splash_screen.dart'; // Replace with your starting screen
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_flutter/cloudinary_object.dart';

final CloudinaryObject cloudinary =
CloudinaryObject.fromCloudName(cloudName: 'dm1zumkxl');

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
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;
    // Define your light and dark themes.
    final ThemeData lightTheme = ThemeData(
      useMaterial3: false,
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
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.grey[900],
      primaryColor: Colors.orange,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.orange,
        titleTextStyle: TextStyle(color: Colors.orange, fontSize: 20),
        iconTheme: IconThemeData(color: Colors.orange),
      ),
      colorScheme: ColorScheme.dark(
        primary: Colors.orange,
        secondary: Colors.deepOrangeAccent,
        surface: Colors.grey[850]!,
        background: Colors.grey[900]!,
        error: Colors.redAccent,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
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
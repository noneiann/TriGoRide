import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tri_go_ride/ui/choose_user.dart';
import 'package:tri_go_ride/ui/first_time_profile_setup.dart';
import 'package:tri_go_ride/ui/email_verification_screen.dart';
import '../services/auth_services.dart';
import '../services/cloudinary_service.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_home_screen.dart';
import 'package:tri_go_ride/ui/login_screen.dart';

class RegisterDriver extends StatefulWidget {
  const RegisterDriver({super.key});

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
  final TextEditingController _licensePlate = TextEditingController();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  String _error = '';
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  File? _profileImage;
  File? _licenseImage;

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _error = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking image: $e';
      });
    }
  }

  Future<void> _pickLicenseImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _licenseImage = File(image.path);
          _error = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking license image: $e';
      });
    }
  }

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
      String errorMessage = 'Login failed';

      // Parse Firebase auth errors
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email address.';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address format.';
      } else if (e.toString().contains('user-disabled')) {
        errorMessage = 'This account has been disabled.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage =
            'Too many failed login attempts. Please try again later.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('invalid-credential')) {
        errorMessage =
            'Invalid email or password. Please check your credentials.';
      } else {
        errorMessage = 'Login failed. Please try again.';
      }

      setState(() => _error = errorMessage);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _register() async {
    setState(() => _loading = true);
    try {
      // Validate required fields
      if (_profileImage == null) {
        setState(() {
          _error = 'Profile photo is required';
          _loading = false;
        });
        return;
      }

      if (_licensePlate.text.trim().isEmpty) {
        setState(() {
          _error = 'License plate number is required';
          _loading = false;
        });
        return;
      }

      if (_licenseImage == null) {
        setState(() {
          _error = 'Driver\'s license photo is required';
          _loading = false;
        });
        return;
      }

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
        // Upload images to Cloudinary
        Map<String, dynamic>? profileImageData;
        Map<String, dynamic>? licenseImageData;

        try {
          // Upload profile image with profile preset
          profileImageData = await CloudinaryService.uploadImage(
            _profileImage!,
            uploadPreset: 'profile-photos',
          );
          if (profileImageData == null) {
            throw Exception('Failed to upload profile image');
          }

          // Upload license image with license preset
          licenseImageData = await CloudinaryService.uploadImage(
            _licenseImage!,
            uploadPreset: 'license-photos',
          );
          if (licenseImageData == null) {
            throw Exception('Failed to upload license image');
          }
        } catch (e) {
          // Delete the created user if image upload fails
          await user.delete();
          setState(() {
            _error = 'Failed to upload images. Please try again.';
            _loading = false;
          });
          return;
        }

        // Send email verification
        await user.sendEmailVerification();

        // Store additional profile info in Firestore with Cloudinary URLs
        await _authService.firestore.collection('users').doc(user.email).set({
          'uid': user.uid,
          'username': _username.text.trim(),
          'email': _email.text.trim(),
          'phone': _phoneNumber.text.trim(),
          'plateNumber': _licensePlate.text.trim().toUpperCase(),
          'createdAt': FieldValue.serverTimestamp(),
          'userType': "Driver",
          'verified': false,
          'firstTimeLogIn': true,
          'profileImage': profileImageData,
          'licenseImage': licenseImageData,
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Verify Your Email"),
            content: Text(
                "A verification email has been sent to ${_email.text.trim()}. Please verify your email before logging in."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EmailVerificationScreen()),
                  );
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Registration failed';

      // Parse Firebase auth errors
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account with this email already exists.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address format.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage =
            'Password is too weak. Please use at least 6 characters.';
      } else if (e.toString().contains('operation-not-allowed')) {
        errorMessage = 'Email/password accounts are not enabled.';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Registration failed. Please try again.';
      }

      setState(() {
        _error = errorMessage;
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Fixed Logo Container - always at the top.
              Container(
                  padding: EdgeInsets.only(top: 64),
                  height: 200, // set the image height
                  alignment: Alignment.center,
                  child: Image.asset(
                    isDark
                        ? 'assets/TriGoRideLogo1.png'
                        : 'assets/TriGoRideLogo.png',
                    height: 240, // set the image height
                    width: 240, // (optional) set the image width
                  )),
              SizedBox(height: 50),
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
                  )),

              SizedBox(height: 40),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Photo Picker
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: containerColor,
                            border: Border.all(
                              color: _profileImage == null
                                  ? Colors.red
                                  : Colors.green,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _profileImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: iconColor,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add Photo*',
                                      style: TextStyle(
                                        color: theme.hintColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Profile Photo Required',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 24),
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
                              Icons.directions_car,
                              color: iconColor,
                            ),
                            SizedBox(width: width * 0.02),
                            Expanded(
                              child: TextField(
                                controller: _licensePlate,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration.collapsed(
                                  hintText: 'License Plate Number*',
                                  hintStyle: hintTextStyle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Driver's License Photo Picker
                      GestureDetector(
                        onTap: _pickLicenseImage,
                        child: Container(
                          width: width * 0.9,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: containerColor,
                            border: Border.all(
                              color: _licenseImage == null
                                  ? Colors.red
                                  : Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _licenseImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _licenseImage!,
                                    fit: BoxFit.cover,
                                    width: width * 0.9,
                                    height: 140,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      size: 48,
                                      color: iconColor,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Upload Driver\'s License*',
                                      style: TextStyle(
                                        color: theme.hintColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tap to select image',
                                      style: TextStyle(
                                        color: theme.hintColor.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Driver\'s License Photo Required',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 24),
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
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text("Register"),
                            ),
                      SizedBox(height: 10),
                      // Navigation to registration.
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LoginPage()),
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
      ),
    );
  }
}

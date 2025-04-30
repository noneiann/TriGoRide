// services/auth_services.dart

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Safely return the current user, or null if none signed in.
  User? getUser() {
    return _auth.currentUser;
  }

  Future<void> initFCM() async {
    // 1) request permissions
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2) get the FCM token
    final String? token = await _fcm.getToken();
    if (token == null) return;

    // 3) only update Firestore if someone is actually signed in
    final user = getUser();
    if (user?.email != null) {
      await firestore.collection('users').doc(user!.email).update({
        'fcmToken': token,
      });
    }
  }

  Future<String> getAccessToken() async {
    final jsonString =
    await rootBundle.loadString('assets/service-account.json');
    final serviceAccount =
    ServiceAccountCredentials.fromJson(json.decode(jsonString));

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client =
    await clientViaServiceAccount(serviceAccount, scopes);
    final token = client.credentials.accessToken.data;
    client.close();
    return token;
  }

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return result.user;
  }

  Future<User?> register(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return await u.getIdToken(forceRefresh);
  }
}

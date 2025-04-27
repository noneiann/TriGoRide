import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<String> getAccessToken() async {
    final jsonString = await rootBundle.loadString('assets/service-account.json');
    final serviceAccount = ServiceAccountCredentials.fromJson(json.decode(jsonString));

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(serviceAccount, scopes);
    final accessToken = client.credentials.accessToken.data;
    client.close();

    return accessToken;
  }


  Future<void> initFCM() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token and save to user document
    final String? token = await _fcm.getToken();
    if (token != null) {
      final user = getUser();
      if (user != null) {
        await firestore.collection('users').doc(user.email).update({
          'fcmToken': token,
        });
      }
    }
  }



  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result =
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      print('SignIn Error: $e');
      rethrow;
    }
  }

  // Register
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result =
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      print('Register Error: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
  void logUser(){
    _auth
        .authStateChanges()
        .listen((User? user) {
      if (user != null) {
        print(user.uid);
      }
    });
  }

  User? getUser(){
    try {
      return _auth.currentUser!;
    } catch (e) {
      print('Get User Error: $e');
      rethrow;
    }

  }
  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      print('Error fetching ID token: $e');
      return null;
    }
  }
}

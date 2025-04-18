import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


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

  User getUser(){
    try {
      return _auth.currentUser!;
    } catch (e) {
      print('Get User Error: $e');
      rethrow;
    }

  }
  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

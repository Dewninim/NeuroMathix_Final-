import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  bool isLoading = false;
  String? errorMessage;

  User? get user => FirebaseAuth.instance.currentUser;

  Stream<User?> get userStream => _auth.userStream;

  // LOGIN
  Future<void> login(String email, String password) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await _auth.login(email, password);
    } on FirebaseAuthException catch (e) {
      errorMessage = getFirebaseErrorMessage(e);
    } catch (e) {
      errorMessage = "Login failed";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // SIGNUP
  Future<void> signUp(String email, String password) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await _auth.signUp(email, password);
    } on FirebaseAuthException catch (e) {
      errorMessage = getFirebaseErrorMessage(e);
    } catch (e) {
      errorMessage = "Signup failed";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.logout();
  }

String getFirebaseErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return "No account found with this email.";
    case 'wrong-password':
      return "Incorrect password. Try again.";
    case 'email-already-in-use':
      return "This email is already registered.";
    case 'invalid-email':
      return "Enter a valid email address.";
    case 'weak-password':
      return "Password must be at least 6 characters.";
    case 'network-request-failed':
      return "Check your internet connection.";
    default:
      return "Something went wrong. Please try again.";
  }
}
}
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
      errorMessage = 'Login failed';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // SIGNUP — now accepts displayName and role
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      await _auth.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
    } on FirebaseAuthException catch (e) {
      errorMessage = getFirebaseErrorMessage(e);
    } catch (e) {
      errorMessage = 'Signup failed';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.logout();
  }

  // Firebase Auth SDK v10+ consolidates some codes into 'invalid-credential'.
  // Keep legacy codes as fallbacks for older SDK versions.
  String getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // ── Login errors ──────────────────────────────────────────────────────
      case 'invalid-credential':
        // SDK v10+ replaces user-not-found + wrong-password with this single code
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';

      // ── Signup errors ─────────────────────────────────────────────────────
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';

      // ── Shared ────────────────────────────────────────────────────────────
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

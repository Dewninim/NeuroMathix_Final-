import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();

  bool isLoading = false;

  Future<String?> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    String? result = await _auth.login(email, password);

    isLoading = false;
    notifyListeners();

    return result;
  }

  Future<String?> signUp(String email, String password) async {
    isLoading = true;
    notifyListeners();

    String? result = await _auth.signUp(email, password);

    isLoading = false;
    notifyListeners();

    return result;
  }

  Future<void> logout() async {
    await _auth.logout();
  }

  Stream<User?> get userStream => FirebaseAuth.instance.authStateChanges();
}
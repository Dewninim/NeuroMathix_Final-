import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // SIGN UP — creates Auth user, sets displayName, saves role to Firestore
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role, // 'student' | 'teacher'
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    // Set display name in Firebase Auth profile
    await user.updateDisplayName(displayName);

    final nameParts = displayName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isEmpty ? '' : nameParts.first;
    final lastName = nameParts.length <= 1 ? '' : nameParts.skip(1).join(' ');

    // Persist role + name to Firestore so it's readable app-wide
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'settings': {
        'difficulty': 'Adaptive (AI-controlled)',
        'focusMode': true,
        'reviewReminders': true,
        'weeklyReport': true,
        'newFeatures': false,
        'emailDigest': true,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // LOGIN
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // CURRENT USER
  User? get currentUser => _auth.currentUser;

  // AUTH STATE STREAM
  Stream<User?> get userStream => _auth.authStateChanges();
}

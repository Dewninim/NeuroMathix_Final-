import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthFlowException implements Exception {
  final String message;
  const AuthFlowException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  Future<void> signUpStudent({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim();
    if (cleanName.length < 2) {
      throw const AuthFlowException('Enter your full name.');
    }
    if (password.length < 8) {
      throw const AuthFlowException('Password must contain at least 8 characters.');
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(cleanName);

      final parts = cleanName.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': normalizedEmail,
        'emailLower': normalizedEmail,
        'displayName': cleanName,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'student',
        'teacherId': null,
        'accountStatus': 'active',
        'emailVerified': false,
        'settings': {
          'difficulty': 'Adaptive (AI-controlled)',
          'focusMode': true,
          'reviewReminders': true,
          'weeklyReport': true,
          'newFeatures': false,
          'emailDigest': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      await user.sendEmailVerification();
    } catch (_) {
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // The original Firebase error is more useful than cleanup errors.
        }
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user!;
    await user.reload();

    final userRef = _db.collection('users').doc(user.uid);
    final document = await userRef.get();
    if (!document.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'emailLower': user.email?.toLowerCase(),
        'displayName': user.displayName ?? user.email?.split('@').first,
        'role': 'student',
        'accountStatus': 'active',
        'emailVerified': user.emailVerified,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final status = document.data()?['accountStatus']?.toString() ?? 'active';
      if (status != 'active') {
        await _auth.signOut();
        throw const AuthFlowException('This account is not active. Contact the administrator.');
      }
      await userRef.update({
        'emailVerified': user.emailVerified,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFlowException('No signed-in user was found.');
    }
    await user.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    final verified = refreshed?.emailVerified ?? false;
    await _db.collection('users').doc(user.uid).set({
      'emailVerified': verified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return verified;
  }

  Future<void> logout() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();
}

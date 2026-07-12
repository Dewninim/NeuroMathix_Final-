import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UserRoleService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns: "teacher" | "student" (default "student")
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'student';

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    final role = (data?['role'] as String?)?.trim().toLowerCase();
    if (role == 'teacher') return 'teacher';
    return 'student';
  }
}
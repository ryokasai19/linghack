import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../main.dart';
import 'vocabulary_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ FIX: Use the 'standard' named constructor
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get currentUserId => _auth.currentUser?.uid;

  

  Future<UserProfile?> signInWithGoogle() async {
    try {
      // 1. (Existing Sign-in Logic...)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // --- NEW LINE: Trigger the Migration ---
        // We use the global 'vocabRepo' we created in main.dart
        await vocabRepo.migrateGuestDataToCloud(user.uid);
        // ---------------------------------------

        return await _syncUserProfile(user);
      }
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserProfile> _syncUserProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (doc.exists) {
      return UserProfile.fromMap(doc.data() as Map<String, dynamic>, user.uid);
    } else {
      final newUser = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        tier: UserTier.free,
        dailyScansUsed: 0,
        lastScanDate: DateTime.now(),
      );

      await userRef.set(newUser.toMap());
      return newUser;
    }
  }
}
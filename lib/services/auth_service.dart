// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Add this
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/user_profile.dart';
// import '../main.dart';
// import 'vocabulary_repository.dart';
//   // --- NEW: Sign in with Apple ---
// import 'dart:convert'; // Required for utf8
// import 'dart:math';    // Required for Random
// import 'package:crypto/crypto.dart'; // Required for sha256

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   Stream<User?> get authStateChanges => _auth.authStateChanges();
//   String? get currentUserId => _auth.currentUser?.uid;



// // Add this helper inside or outside your AuthService class
// String _generateNonce([int length = 32]) {
//   const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
//   final random = Random.secure();
//   return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
// }

// String _sha256Hash(String input) {
//   final bytes = utf8.encode(input);
//   final digest = sha256.convert(bytes);
//   return digest.toString();
// }

// // Update your function to this:
// Future<UserProfile?> signInWithApple() async {
//   try {
//     final rawNonce = _generateNonce();
//     final hashedNonce = _sha256Hash(rawNonce);

//     final appleCredential = await SignInWithApple.getAppleIDCredential(
//       scopes: [
//         AppleIDAuthorizationScopes.email,
//         AppleIDAuthorizationScopes.fullName,
//       ],
//       nonce: hashedNonce, // Send the hashed version to Apple
//     );

//     final OAuthCredential credential = OAuthProvider("apple.com").credential(
//       idToken: appleCredential.identityToken,
//       rawNonce: rawNonce, // Send the raw version to Firebase
//     );

//     final UserCredential userCredential = await _auth.signInWithCredential(credential);
    
//     // Use your existing private helper to handle the sync
//     if (userCredential.user != null) {
//       await vocabRepo.migrateGuestDataToCloud(userCredential.user!.uid);
//       return await _syncUserProfile(userCredential.user!);
//     }
//   } catch (e) {
//     print("Apple Sign In Error: $e");
//     return null;
//   }
//   return null;
// }

//   // --- NEW: Sign in with Email (For Apple Reviewer) ---
//   Future<UserProfile?> signInWithEmail(String email, String password) async {
//     try {
//       final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return await _handlePostSignIn(userCredential.user);
//     } catch (e) {
//       print("Email Sign In Error: $e");
//       return null;
//     }
//   }

//   // Helper to keep logic DRY (Don't Repeat Yourself)
//   Future<UserProfile?> _handlePostSignIn(User? user) async {
//     if (user != null) {
//       await vocabRepo.migrateGuestDataToCloud(user.uid);
//       return await _syncUserProfile(user);
//     }
//     return null;
//   }

//   // --- NEW: Mandatory Account Deletion ---
//   Future<void> deleteUserAccount() async {
//     try {
//       // Optional: Delete their Firestore data before the auth account
//       if (currentUserId != null) {
//         await _db.collection('users').doc(currentUserId).delete();
//       }
//       await _auth.currentUser?.delete();
//     } on FirebaseAuthException catch (e) {
//       if (e.code == "requires-recent-login") {
//         print("User needs to re-authenticate before deleting account.");
//       }
//     }
//   }

//   // Existing Google Logic (Updated to use _handlePostSignIn)
//   Future<UserProfile?> signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return null;

//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//       final AuthCredential credential = GoogleAuthProvider.credential(
//         idToken: googleAuth.idToken,
//         accessToken: googleAuth.accessToken,
//       );

//       final UserCredential userCredential = await _auth.signInWithCredential(credential);
//       return await _handlePostSignIn(userCredential.user);
//     } catch (e) {
//       print("Error signing in with Google: $e");
//       return null;
//     }
//   }

//   Future<void> signOut() async {
//     if (await _googleSignIn.isSignedIn()) {
//       await _googleSignIn.signOut();
//     }
//     await _auth.signOut();
//   }

//   Future<UserProfile> _syncUserProfile(User user) async {
//     final userRef = _db.collection('users').doc(user.uid);
//     final doc = await userRef.get();

//     if (doc.exists) {
//       return UserProfile.fromMap(doc.data() as Map<String, dynamic>, user.uid);
//     } else {
//       final newUser = UserProfile(
//         uid: user.uid,
//         email: user.email ?? '',
//         tier: UserTier.free,
//         dailyScansUsed: 0,
//         lastScanDate: DateTime.now(),
//       );
//       await userRef.set(newUser.toMap());
//       return newUser;
//     }
//   }
// }
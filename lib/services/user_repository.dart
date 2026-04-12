import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart'; // Ensure this points to your model file
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository extends ChangeNotifier {
  // --- 1. Dependencies ---
  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: kIsWeb ? '583408815077-5b6buj5uhq8qehv0p3jmd9epf3himf65.apps.googleusercontent.com' : null,
  );
  late SharedPreferences _prefs;

  // --- 2. State ---
  User? _user; // The logged-in Firebase User (if any)
  UserProfile _guestProfile = UserProfile(
    uid: 'guest',
    email: '',
    lastScanDate: DateTime.now(),
  );

  // --- 3. Getters ---
  User? get user => _user;
  int get dailyScansUsed => _guestProfile.dailyScansUsed;

  // --- 4. Initialization ---
  Future<void> initialize() async {
    // A. Setup Local Storage (The Notebook)
    _prefs = await SharedPreferences.getInstance();
    await _loadGuestProfile();

    // B. Listen for Login/Logout (The Watcher)
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners(); // Tell UI to update (show Avatar vs Login button)
    });
  }

  // --- 5. Authentication Methods ---

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 1. Sign In
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;

      if (user != null) {
        // 2. CHECK DATABASE: Does this user exist?
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // 3. CREATE NEW USER in Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'tier': 'free',
            'createdAt': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : 'mobile',
          });
          print("Created new user profile in Firestore.");
        }
      }
      
    } catch (e) {
      print("Login Error: $e");
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    print("User Signed Out");
  }

  // --- 6. Scan Logic (The "Clerk") ---

  Future<void> _loadGuestProfile() async {
    final int used = _prefs.getInt('guest_scans') ?? 0;
    final String? dateStr = _prefs.getString('last_scan_date');
    
    DateTime lastDate = DateTime.now();
    if (dateStr != null) {
      lastDate = DateTime.parse(dateStr);
    }

    _guestProfile = UserProfile(
      uid: 'guest',
      email: '',
      dailyScansUsed: used,
      lastScanDate: lastDate,
    );
    notifyListeners();
  }

  Future<void> incrementScanCount() async {
    // A. Check if it's a new day. If so, reset counter first.
    if (_guestProfile.isNewDay) {
      print("New Day detected! Resetting scan count.");
      _guestProfile = UserProfile(
        uid: 'guest',
        email: '',
        dailyScansUsed: 0,
        lastScanDate: DateTime.now(),
      );
    }

    // B. Increment the count
    final newCount = _guestProfile.dailyScansUsed + 1;
    
    // C. Update the object
    _guestProfile = UserProfile(
      uid: 'guest',
      email: '',
      dailyScansUsed: newCount,
      lastScanDate: DateTime.now(),
    );

    // D. Save to "The Notebook" (SharedPreferences)
    await _prefs.setInt('guest_scans', newCount);
    await _prefs.setString('last_scan_date', DateTime.now().toIso8601String());

    notifyListeners();
  }
}
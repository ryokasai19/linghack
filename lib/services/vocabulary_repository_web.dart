import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_pair.dart';

class VocabularyRepository {
  // Lazy load Firestore to avoid "Race Conditions"
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> init() async {
    print("🌐 Web Mode: Cloud Database Active");
  }

  // 1. SAVE (To User's Private Folder)
  Future<void> saveWord(WordPair word, String? userId,{String? languageCode}) async {
    if (userId == null) {
      print("⚠️ Error: Cannot save word. User not logged in.");
      return;
    }

    try {
      // Path: users/{userId}/vocabulary/{auto_generated_id}
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('vocabulary')
          .add({
            'foreignText': word.foreignText,
            'englishText': word.englishText,
            'isRemembered': word.isRemembered,
            'playlistIds': word.playlistIds, // Keep this
            'languageCode': 'hu', // <--- HARDCODE YOUR TARGET LANGUAGE FOR NOW (or pass it in)
            'userId': userId,     // <--- Keeps data portable/safe
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      print("✅ Word Saved to Cloud for user: $userId");
    } catch (e) {
      print("❌ Save Failed: $e");
    }
  }

  // 2. READ (From User's Private Folder)
  Stream<List<WordPair>> getWordsStream(String? userId,{required String languageCode}) {
    if (userId == null) {
      return Stream.value([]); // Return empty list if guest
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('vocabulary')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return WordPair(
              // Use the Firestore document ID (String) to match WordPair.id type
              id: doc.id.toString(),
              foreignText: data['foreignText'] ?? '',
              englishText: data['englishText'] ?? '',
              isRemembered: data['isRemembered'] ?? false,
            );
          }).toList();
        });
  }
}

// Global Instance
final vocabRepo = VocabularyRepository();
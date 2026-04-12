import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Index, Query; 

part 'local_vocabulary.g.dart';

@Collection(accessor: 'cachedWords')
class WordEntry { // <--- RENAMED from LocalWord
  WordEntry(); 

  Id?id; 

  @Index(type: IndexType.value)
  late String word;

  late String definition;
  late String languageCode; 
  late DateTime timestamp;

  bool isRemembered = false;

  List<String> playlistIds = [];

  String? originalContext;

  bool isSynced = false;

  @Index() 
  String? firestoreId;

  @Index()
  String? userId;

  // --- HELPER METHODS ---
  Map<String, dynamic> toFirestoreMap() {
    return {
      // Unifying to Web Logic Keys
      'foreignText': word, 
      'englishText': definition,
      'languageCode': languageCode,
      'userId': userId,
      'isRemembered': isRemembered, 
      'playlistIds': playlistIds, 
      
      // Let Firebase handle the exact server time just like the web does
      'timestamp': FieldValue.serverTimestamp(), 
    };
  }

  factory WordEntry.fromFirestore(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final ts = map['timestamp'] ?? map['createdAt'];
    if (ts is Timestamp) {
      parsedDate = ts.toDate();
    } else if (ts is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      parsedDate = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return WordEntry()
      ..firestoreId = docId
      // ✅ CHANGED: Now looking for the correct Firebase keys
      ..word = map['foreignText'] ?? '' 
      ..definition = map['englishText'] ?? ''
      ..languageCode = map['languageCode'] ?? 'en'
      ..timestamp = parsedDate
      ..originalContext = map['originalContext']
      ..userId = map['userId']
      // ✅ ADDED: Keep your playlists synced properly
      ..playlistIds = map['playlistIds'] != null ? List<String>.from(map['playlistIds']) : []
      ..isSynced = true; 
  }
}
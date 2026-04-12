import 'package:isar/isar.dart';

part 'local_playlist.g.dart';

@collection
class LocalPlaylist {
  LocalPlaylist();
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String playlistId;

  late String name;

  late String languageCode;

  late DateTime createdAt;

  @Index()
  late DateTime lastAccessed;

  // NEW FIELD
  bool isPinned = false; 

  factory LocalPlaylist.fromFirestore(Map<String, dynamic> map, String docId) {
    return LocalPlaylist()
      ..playlistId = docId
      ..name = map['name'] ?? 'Untitled'
      ..languageCode = map['languageCode'] ?? 'en'
      ..createdAt = (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now()
      ..lastAccessed = (map['lastAccessed'] as dynamic)?.toDate() ?? DateTime.now()
      ..isPinned = map['isPinned'] ?? false; // Include in Firestore sync
  }

  // Helper for toggling state in the UI
  LocalPlaylist copy() {
    return LocalPlaylist()
      ..id = id
      ..playlistId = playlistId
      ..name = name
      ..languageCode = languageCode
      ..createdAt = createdAt
      ..lastAccessed = lastAccessed
      ..isPinned = isPinned;
  }
}
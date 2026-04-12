class WordPair {
  final String? id; // This will be the Firebase ID (String)
  final String foreignText;
  final String englishText;
  bool isRemembered;
  final List<String> playlistIds;

  // --- NEW FIELDS FOR SYNC ---
  final String? userId; // To distinguish between User A and User B in the cloud
  final bool isSynced;  // true = safe in cloud, false = needs upload
  final DateTime? timestamp;

  WordPair({
    this.id,
    required this.foreignText,
    required this.englishText,
    this.isRemembered = false,
    this.playlistIds = const [],
    this.userId,
    this.isSynced = false, // Default to false so new words try to sync immediately
    this.timestamp
  });

  // 1. Add timestamp to copyWith
  WordPair copyWith({
    String? id,
    String? foreignText,
    String? englishText,
    bool? isRemembered,
    List<String>? playlistIds,
    String? userId,
    bool? isSynced,
    DateTime? timestamp, // <-- Add this
  }) {
    return WordPair(
      id: id ?? this.id,
      foreignText: foreignText ?? this.foreignText,
      englishText: englishText ?? this.englishText,
      isRemembered: isRemembered ?? this.isRemembered,
      playlistIds: playlistIds ?? this.playlistIds,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
      timestamp: timestamp ?? this.timestamp, // <-- Add this
    );
  }

  // 2. Add timestamp to toMap
  Map<String, dynamic> toMap() {
    return {
      'foreignText': foreignText,
      'englishText': englishText,
      'isRemembered': isRemembered,
      'playlistIds': playlistIds,
      'userId': userId,
      'timestamp': timestamp, // <-- Add this so Firestore saves the date!
    };
  }

  // --- HELPER: From Map (From Firebase) ---
  factory WordPair.fromMap(Map<String, dynamic> map, String id) {
    return WordPair(
      id: id,
      foreignText: map['foreignText'] ?? '',
      englishText: map['englishText'] ?? '',
      isRemembered: map['isRemembered'] ?? false,
      playlistIds: List<String>.from(map['playlistIds'] ?? []),
      userId: map['userId'],
      isSynced: true, // If we are reading it from Firebase, it is definitely synced!
      timestamp: map['timestamp'] != null
        ? (map['timestamp'] as dynamic).toDate()
        :null,
    );
  }
}
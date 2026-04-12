class Playlist {
  final String id;
  final String name;
  final bool isPinned; // NEW

  Playlist({
    required this.id, 
    required this.name, 
    this.isPinned = false, // Defaults to unpinned
  });

  // This helper is vital for updating just the pin status
  Playlist copyWith({
    String? id,
    String? name,
    bool? isPinned,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
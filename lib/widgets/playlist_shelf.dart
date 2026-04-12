import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../models/local_playlist.dart';


class PlaylistShelf extends StatelessWidget {
  final VoidCallback onCreatePlaylist;
  final Function(LocalPlaylist) onRenamePlaylist;
  final Function(LocalPlaylist) onDeletePlaylist;
  final Function(LocalPlaylist) onAddWords;
  const PlaylistShelf({
    super.key, 
    required this.onCreatePlaylist,
    required this.onRenamePlaylist,
    required this.onDeletePlaylist,
    required this.onAddWords,
  });
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);
    final playlists = provider.playlists;
    final double cardWidth = MediaQuery.of(context).size.width < 600 ? 105 : 130;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: cardWidth + 10,
          child: ListView.builder(
            key: const PageStorageKey('playlist_shelf_scroll'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: playlists.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
              return _AddPlaylistCard(
                onTap: onCreatePlaylist
              );
            }
              final p = playlists[index-1];
              final isSelected = provider.filterStatus == p.playlistId;
              final double width = MediaQuery.of(context).size.width < 600 ? 105 : 130;
              
              return PlaylistCard(
                width: width,
                name: p.name,
                isPinned: p.isPinned,
                isSelected: isSelected,
                onTap: () => provider.setFilterStatus(isSelected ? 'all' : p.playlistId),
                onTogglePin: () => provider.togglePlaylistPin(p),
                onRename: () => onRenamePlaylist(p),
                onDelete: () => onDeletePlaylist(p),
                onAddWords: () => onAddWords(p),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class PlaylistCard extends StatelessWidget {
  final double width;
  final String name;
  final bool isSelected;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin; // Added this
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddWords;

  const PlaylistCard({
    super.key,
    required this.width,
    required this.name,
    required this.isSelected,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin, // Added this
    required this.onRename,
    required this.onDelete,
    required this.onAddWords,
  });

  @override
  Widget build(BuildContext context) {
    final Color foregroundColor = isSelected ? Colors.white : Colors.black87;
    final Color iconColor = isSelected ? Colors.tealAccent : Colors.blue.shade700;
    final double width = MediaQuery.of(context).size.width < 600 ? 110 : 130;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueGrey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.blueGrey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Layer 1: The Main Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.folder : Icons.folder_open_rounded,
                        size: 28,
                        color: iconColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Layer 2: The Visual Pin Indicator (Visible on the card)
            if (isPinned)
              Positioned(
                top: 12,
                left: 12,
                child: Icon(
                  Icons.push_pin,
                  size: 16,
                  color: isSelected ? Colors.orangeAccent : Colors.orange,
                ),
              ),

            // Layer 3: The "..." Menu
            Positioned(
              top: 4,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: foregroundColor.withOpacity(0.6), size: 20),
                onSelected: (value) {
                  if (value == "pin") onTogglePin(); // Now works
                  if (value == 'add') onAddWords();
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(isPinned ? 'Unpin' : 'Pin to start'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.add_link),
                      title: Text('Add Words'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Rename'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaylistCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPlaylistCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width < 600 ? 105 : 130,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.transparent, // Keeps it light
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.blueGrey.shade200, 
            width: 2,
            style: BorderStyle.solid, // Note: For real dashes, use 'dotted_border' package
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 40,
              color: Colors.blueGrey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              "New List",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
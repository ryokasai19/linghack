import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/playlist_shelf.dart';
// Import your provider and models here, e.g.:
// import 'package:linghack/providers/language_provider.dart'; 
// import 'package:linghack/models/local_playlist.dart';

class AllPlaylistsPage extends StatelessWidget {
  const AllPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We don't use 'final' if we want to be safe with the context
    final provider = Provider.of<LanguageProvider>(context);
    final playlists = provider.playlists;

    return ListView.separated(
      padding: const EdgeInsets.all(16), // Added padding so it breathes
      itemCount: playlists.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
      itemBuilder: (context, index) {
        final p = playlists[index];
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Icon(Icons.folder_outlined, color: Colors.blue.shade700),
          ),
          title: Text(
            p.name, 
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Start Learning Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  foregroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text("Study", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  // Set the active filter to this playlist to start studying
                  provider.setFilterStatus(p.playlistId);
                },
              ),
              
              const SizedBox(width: 8),

              // 2. Options Menu (Three dots)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'pin') provider.togglePlaylistPin(p);
                  if (value == 'rename') {} // Add your rename logic
                  if (value == 'delete') {} // Add your delete logic
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin', 
                    child: Text(p.isPinned ? "Unpin Playlist" : "Pin Playlist")
                  ),
                  const PopupMenuItem(value: 'rename', child: Text("Rename")),
                  const PopupMenuItem(
                    value: 'delete', 
                    child: Text("Delete", style: TextStyle(color: Colors.red))
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            // Tapping the row just filters the list without automatically jumping views
            provider.setFilterStatus(p.playlistId);
          },
        );
      },
    );
  }
}
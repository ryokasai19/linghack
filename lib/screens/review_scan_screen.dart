import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_pair.dart';
import '../providers/language_provider.dart';

class ReviewScanScreen extends StatefulWidget {
  final List<WordPair> scannedWords;

  const ReviewScanScreen({super.key, required this.scannedWords});

  @override
  State<ReviewScanScreen> createState() => _ReviewScanScreenState();
}

class _ReviewScanScreenState extends State<ReviewScanScreen> {
  // 1. We split the scanned words into two separate lists
  final List<WordPair> _newWords = [];
  final List<WordPair> _duplicates = [];
  
  bool _isSaving = false; 
  String? _selectedPlaylistId;

  @override
  void initState() {
    super.initState();
    
    // 2. The Silent Check: Separate new words from duplicates
    final provider = context.read<LanguageProvider>();
    
    // Create a quick lookup map of existing words (lowercase for safety)
    final existingWordsMap = {
      for (var w in provider.displayWords) w.foreignText.toLowerCase(): w
    };

    for (var word in widget.scannedWords) {
      final lowerText = word.foreignText.toLowerCase();
      if (existingWordsMap.containsKey(lowerText)) {
        // DUPLICATE FOUND!
        // We attach the OLD ID to the NEW word. This ensures that if they hit
        // "Replace", the database knows exactly which old word to overwrite!
        final existingWord = existingWordsMap[lowerText]!;
        _duplicates.add(word.copyWith(id: existingWord.id, timestamp: existingWord.timestamp));
      } else {
        _newWords.add(word);
      }
    }
  }

  // --- DUPLICATE ACTIONS ---
  void _dismissAllDuplicates() {
    setState(() => _duplicates.clear());
  }

  void _dismissDuplicate(int index) {
    setState(() => _duplicates.removeAt(index));
  }

  void _replaceDuplicate(int index) {
    setState(() {
      // Move it down to the "New Words" list so it gets saved when they hit ADD ALL.
      // Because we attached the old ID in initState, this will overwrite the old word!
      _newWords.insert(0, _duplicates[index]); 
      _duplicates.removeAt(index);
    });
  }

  void _replaceAllDuplicates() {
    setState(() {
      _newWords.insertAll(0, _duplicates); 
      _duplicates.clear();
    });
  }

  // --- NEW WORD ACTIONS ---
  void _deleteNewWord(int index) {
    setState(() => _newWords.removeAt(index));
  }

  void _editNewWord(int index) {
    final provider = context.read<LanguageProvider>();
    final word = _newWords[index];
    final foreignCtrl = TextEditingController(text: word.foreignText);
    final englishCtrl = TextEditingController(text: word.englishText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Word"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: foreignCtrl, decoration: InputDecoration(labelText: provider.currentLanguage.name)),
            TextField(controller: englishCtrl, decoration: const InputDecoration(labelText: "English")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _newWords[index] = word.copyWith(
                  foreignText: foreignCtrl.text,
                  englishText: englishCtrl.text,
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- PLAYLIST & SAVING ---
  Widget _buildPlaylistSelector(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final playlists = provider.playlists;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 10),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text("New List"),
            onPressed: () => _handleCreateAndSelect(context),
          ),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          ...playlists.map((p) {
            final isSelected = p.playlistId == _selectedPlaylistId;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(p.name),
                selected: isSelected,
                onSelected: (val) {
                  setState(() => _selectedPlaylistId = val ? p.playlistId : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _handleCreateAndSelect(BuildContext context) async {
    final controller = TextEditingController();
    final provider = context.read<LanguageProvider>();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Playlist"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter name..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newId = await provider.createPlaylist(name);
      setState(() => _selectedPlaylistId = newId);
    }
  }

  Future<void> _confirmAddAll() async {
    if (_newWords.isEmpty) return;
    final provider = context.read<LanguageProvider>();
    
    for (var word in _newWords) {
      
      // THE CHECK: Does this word have an ID? (If yes, it came from the "Replace" pile)
      if (word.id != null) {
        
        // 1. Find the exact old word in the database and snipe it
        try {
          final oldWord = provider.displayWords.firstWhere((w) => w.id == word.id);
          provider.removeWord(oldWord); // Using your exact delete function from earlier!
        } catch (e) {
          debugPrint("Old word not found for deletion");
        }

        // 2. Create a brand new, clean WordPair (We can't use copyWith here because 
        // your copyWith doesn't allow setting an ID back to null!)
        final cleanWord = WordPair(
          foreignText: word.foreignText,
          englishText: word.englishText,
          playlistIds: _selectedPlaylistId != null ? [_selectedPlaylistId!] : [],
          timestamp: DateTime.now(), // Give it a fresh date!
        );

        // 3. Add the clean word
        await provider.addWord(cleanWord);

      } else {
        // IT'S A NORMAL NEW WORD
        final wordToSave = word.copyWith(
          playlistIds: _selectedPlaylistId != null ? [_selectedPlaylistId!] : [],
          timestamp: DateTime.now(),
        );
        await provider.addWord(wordToSave);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved ${_newWords.length} words!")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Review Scan (${_newWords.length + _duplicates.length})"),
      ),
      body: Column(
        children: [
          _buildPlaylistSelector(context),
          const Divider(height: 1),
          
          Expanded(
            // 3. We use a SingleChildScrollView so both lists scroll together naturally
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- SECTION 1: DUPLICATES ---
                  if (_duplicates.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Already in Vocabulary (${_duplicates.length})", 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _dismissAllDuplicates,
                                child: const Text("Dismiss All", style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _replaceAllDuplicates, 
                                child: const Text("Replace All", style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // We map through the duplicates list to build the cards
                    ..._duplicates.asMap().entries.map((entry) {
                      int idx = entry.key;
                      WordPair word = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.orange.shade300, width: 1),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: ListTile(
                          title: Text(word.foreignText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(word.englishText, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
                              if (word.timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Added ${word.timestamp!.month}/${word.timestamp!.day}/${word.timestamp!.year}",
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ]
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.sync, color: Colors.blue), 
                                label: const Text("Replace"),
                                onPressed: () => _replaceDuplicate(idx)
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey), 
                                onPressed: () => _dismissDuplicate(idx)
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 30),
                  ],

                  // --- SECTION 2: NEW WORDS ---
                  if (_newWords.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        "New Words (${_newWords.length})", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),
                    ..._newWords.asMap().entries.map((entry) {
                      int idx = entry.key;
                      WordPair word = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          title: Text(word.foreignText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(word.englishText),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editNewWord(idx)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteNewWord(idx)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else if (_duplicates.isEmpty) ...[
                     const Padding(
                       padding: EdgeInsets.all(40.0),
                       child: Center(child: Text("No words left to review.")),
                     )
                  ]
                ],
              ),
            ),
          ),

          // --- BOTTOM CONTROLS ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: (_newWords.isEmpty || _isSaving) 
                        ? null 
                        : () async {
                            setState(() => _isSaving = true);
                            await _confirmAddAll();
                          },
                    child: _isSaving 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("ADD ALL"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
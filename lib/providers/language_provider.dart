import 'dart:async';
import 'package:flutter/material.dart';
import '../models/word_pair.dart';
import '../models/target_language.dart';
import '../services/playback_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/local_playlist.dart';
// IMPORT YOUR REPOSITORY
import '../services/vocabulary_repository_mobile.dart'; 
import '../widgets/playlist_shelf.dart';
import 'package:intl/intl.dart';




class LanguageProvider with ChangeNotifier {
  LanguageProvider() {
    // This listens for Login/Logout events
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      print("👤 Auth Changed: ${user?.uid}"); // Debug print
      if (user != null) {
        // THE FIX: Run the migration, which will safely handle duplicates 
        // and then automatically call syncUser() for us when it's done.
        await vocabRepo.migrateGuestDataToCloud(user.uid);
      }
      
      // Initialize listeners ONLY after the database is fully merged and safe
      initializeListeners(); 
    });
  }
  String _selectedLanguage = 'hu'; 
  bool _isAutoPlayEnabled = false;
  int _currentIndex = 0;
  List<WordPair> _words = [];
  bool _isSoundOn = true;
  double _autoPlayDelay = 3.0;
  StreamSubscription? _wordSubscription;
  
  bool _isForeignFront = true; 
  bool _isLooping = true;

  String _memorizedFilter = 'all';
  bool _isCalendarMode = true;
  bool get isCalendarMode => _isCalendarMode;

  void toggleCalendarMode() {
    _isCalendarMode = !_isCalendarMode;
    notifyListeners(); // This tells the UI to rebuild when you click the icon
  }

  Map<String, List<WordPair>> get wordsByDate {
    // 1. Create a copy and sort the words by timestamp (Newest first)
    List<WordPair> sortedWords = List.from(filteredWords);
    sortedWords.sort((a, b) {
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!); 
    });

    // 2. Group the already-sorted words
    // Use LinkedHashMap (default) to preserve the sorted order of keys
    Map<String, List<WordPair>> grouped = {};

    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    
    for (var word in sortedWords) {
      String dateKey = word.timestamp != null 
          ? formatter.format(word.timestamp!)
          : "Earlier";
          
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(word);
    }
    
    return grouped;
  }
  // Add this to your LanguageProvider class
List<WordPair>? _tempStudyList;

void setStudyList(List<WordPair> words, {bool shuffle = false}) {
    // Create a copy so we don't accidentally mutate the original list
    List<WordPair> listToStudy = List.from(words);
    
    if (shuffle) {
      listToStudy.shuffle();
    }

    _tempStudyList = listToStudy;
    _currentIndex = 0; // CRITICAL: Start the study session at the first card
    notifyListeners();
  }

// Update your displayWords getter to check for the temp list
List<WordPair> get displayWords {
    // 1. Check if we are in the Playlist View
    if (_filterStatus == 'playlists_view') {
      return _words; 
    }

    // 2. THE FIX: If we have a daily review list, filter it by the active tab
    if (_tempStudyList != null) {
      if (_memorizedFilter == 'memorized') {
        return _tempStudyList!.where((w) => w.isRemembered).toList();
      } else if (_memorizedFilter == 'not_memorized') {
        return _tempStudyList!.where((w) => !w.isRemembered).toList();
      } else {
        return _tempStudyList!; // 'all' tab
      }
    }
    
    // 3. Otherwise, use the standard main list filters
    return filteredWords;
  }

// Add a clear method to reset when exiting study mode
void clearStudyList() {
  _tempStudyList = null;
  _currentIndex = 0;
  notifyListeners();
}

  
  

  TargetLanguage _currentLanguage = const TargetLanguage(
    name: 'Hungarian', 
    code: 'hu', 
    voiceCode: 'hu-HU'
  );

  TargetLanguage get currentLanguage => _currentLanguage;
  
  // FILTERING & PLAYLIST STATE
  String _filterStatus = 'all';
  List<LocalPlaylist> _playlists = [];
  List<LocalPlaylist> get playlists {
    final list = List<LocalPlaylist>.from(_playlists);

    list.sort((a, b) {
      // 1. Pinned items always come first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // 2. Otherwise, sort by last accessed (most recent first)
      return b.lastAccessed.compareTo(a.lastAccessed);
    });

    return list;
  }

  Future<void> togglePlaylistPin(LocalPlaylist playlist) async {
    final newStatus = !playlist.isPinned;
    
    // Update DB
    await vocabRepo.updatePlaylistAccess(playlist.playlistId, isPinned: newStatus);

    // Update Local UI
    playlist.isPinned = newStatus;
    notifyListeners();
  }
  
  Set<String> _unlockedLanguages = {'hu', 'fr', 'es','ja','zh','de','it','ru','pt','ko','hi'};

  // --- GETTERS ---
  String get selectedLanguage => _selectedLanguage;
  bool get isAutoPlayEnabled => _isAutoPlayEnabled;
  int get currentIndex => _currentIndex;
  List<WordPair> get words => _words;
  bool get isSoundOn => _isSoundOn;
  double get autoPlayDelay => _autoPlayDelay;
  bool get isForeignFront => _isForeignFront; 
  bool get isLooping => _isLooping;
  String get memorizedFilter => _memorizedFilter;
  String _searchQuery = ""; // The private variable
  String get searchQuery => _searchQuery; // The getter

  WordPair? get currentWord {
    // Use displayWords, not filteredWords
    if (displayWords.isEmpty) return null;
    if (_currentIndex >= displayWords.length) {
      _currentIndex = 0; 
    }
    return displayWords[_currentIndex];
  }
  String get filterStatus => _filterStatus;

  String getPlaylistName(String id) {
    try {
      // Trying to match by 'playlistId' which is the string ID
      return _playlists.firstWhere((p) => p.playlistId == id).name;
    } catch (e) {
      return "Unknown List";
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentIndex = 0; // Reset index to avoid out-of-bounds on filtered lists
    notifyListeners(); // Refresh the UI
  }


  List<String> get topPlaylists {
    // 1. Get all playlist IDs currently in use by your words
    final allIds = _words
        .expand((w) => w.playlistIds)
        .toSet()
        .toList();

    // 2. Sort them alphabetically for now 
    // (We will connect the "Last Accessed" sorting later once UI is working)
    allIds.sort();

    // 3. Return top 6
    return allIds.take(6).toList();
  }

  // 1. FILTERING LOGIC
  List<WordPair> get filteredWords {
    // Step A: Filter by Playlist
    List<WordPair> playlistWords;
    if (_filterStatus == 'all'||_filterStatus == 'memorized' || 
      _filterStatus == 'not_memorized' || _filterStatus == 'playlists_view') {
      playlistWords = _words;
    } else {
      playlistWords = _words.where((w) => w.playlistIds.contains(_filterStatus)).toList();
    }

    // Step B: Filter by Memorized Status
    List<WordPair> memorizedWords;
    if (_memorizedFilter == 'memorized') {
      memorizedWords = playlistWords.where((w) => w.isRemembered).toList();
    } else if (_memorizedFilter == 'not_memorized') {
      memorizedWords = playlistWords.where((w) => !w.isRemembered).toList();
    } else {
      memorizedWords = playlistWords;
    }

    // Step C: Filter by Search Query (NEW)
    if (_searchQuery.isEmpty) {
      return memorizedWords;
    } else {
      final query = _searchQuery.toLowerCase();
      return memorizedWords.where((w) => 
        w.foreignText.toLowerCase().contains(query) || 
        w.englishText.toLowerCase().contains(query)
      ).toList();
    }
  }

  void setMemorizedFilter(String filter) {
    _memorizedFilter = filter;
    _currentIndex = 0; // Reset to start of list to avoid crashes
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    _currentIndex = 0;
    notifyListeners();
  } 

  void setLanguage(TargetLanguage lang) {
    _currentLanguage = lang;
    initializeListeners();
    notifyListeners();
  }
  
  bool isLanguageLocked(String languageCode) {
    return !_unlockedLanguages.contains(languageCode);
  }
  
  void unlockLanguage(String languageCode) {
    _unlockedLanguages.add(languageCode);
    notifyListeners();
  }

  // --- TOGGLES ---
  void toggleAutoPlay() { _isAutoPlayEnabled = !_isAutoPlayEnabled; notifyListeners(); }
  void toggleSound() { _isSoundOn = !_isSoundOn; notifyListeners(); }
  void setAutoPlayDelay(double delay) { _autoPlayDelay = delay; notifyListeners(); }
  void toggleCardSide() { _isForeignFront = !_isForeignFront; notifyListeners(); }
  
  void previousCard() {
    if (_currentIndex > 0) { _currentIndex--; notifyListeners(); }
  }

  void nextCard() {
    if (_currentIndex < filteredWords.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0; // Boom! The loop back to the start.
    }
    notifyListeners();
  }

  // --- ACTIONS (Now connected to Repository) ---

  // 1. ADD WORD (Hybrid)
  Future<void> addWord(WordPair newWord) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    // Optimistic UI update handled by the Stream, 
    // but we can notify just in case.
    try {
      await vocabRepo.saveWord(newWord, userId, languageCode: _currentLanguage.code);
      print("✅ Saved to Repository");
    } catch (e) {
      print("❌ Error saving word: $e");
    }
  }
  
  // 2. REMOVE WORD (Hybrid)
  Future<void> removeWord(WordPair wordToRemove) async {
    if (wordToRemove.id == null) return; 
    
    final uiId = wordToRemove.id!; 
    final userId = FirebaseAuth.instance.currentUser?.uid; 

    // 1. Optimistic Update: Find the exact word by ID and remove it
    _words.removeWhere((w) => w.id == uiId);
    notifyListeners();

    // 2. Persist using the Repository
    await vocabRepo.deleteWord(uiId, userId);
  }

  // 3. EDIT WORD (Needs specific update logic)
  // For now, we will just delete and re-save if you edit text, 
  // or use direct Firestore for complicated edits until we upgrade the Repo further.
Future<void> editWord(int index, WordPair updatedWord) async {
  // 1. Optimistic Update (Instant UI change)
  _words[index] = updatedWord;
  notifyListeners();

  // 2. Persist using the Repository
  // Note: We cannot use updateWordStatus here because we changed the text.
  // We must send the whole updated word to the database.
  await vocabRepo.updateWord(updatedWord); 
}

  // 4. TOGGLE BOOKMARK
  Future<void> toggleRemembered(WordPair word) async {
  // 1. Optimistic Update (Instant UI change)
  word.isRemembered = !word.isRemembered;
  notifyListeners();

  // 2. Persist using the Repository 
  // (This handles Isar locally AND Firestore in the cloud)
  await vocabRepo.updateWordStatus(word, word.isRemembered);
}

  // --- AUTO-PLAY LOGIC ---
  void startAutoPlay({
    required Function onResetCard, 
    required Function onFlipToBack, 
    required PlaybackService playback
  }) {
    if (_words.isEmpty) return;
    _isAutoPlayEnabled = true;
    notifyListeners();
    _runAutoPlayLoop(onResetCard, onFlipToBack, playback);
  }

  void toggleLoopMode() {
    _isLooping = !_isLooping;
    notifyListeners();
  }

  void shuffleList() {
    // 1. If we are in Study Mode, shuffle the active study list
    if (_tempStudyList != null) {
      _tempStudyList!.shuffle();
    } 
    // 2. Otherwise, shuffle the main database list
    else {
      _words.shuffle(); 
    }
    
    _currentIndex = 0; // Resets to first card
    notifyListeners();
  }

  void stopAutoPlay() {
    _isAutoPlayEnabled = false;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners(); // This ensures the rest of the UI knows which card we are on
  }


  final PageController pageController = PageController();

  void goToNext() {
    if (_currentIndex < displayWords.length - 1) {
      _currentIndex++;
      // This tells the PageView to animate to the new index
      pageController.animateToPage(
        _currentIndex, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
      notifyListeners();
    }
  }


  void _runAutoPlayLoop(Function onResetCard, Function onFlipToBack, PlaybackService playback) async {
      // 1. FIXED: Changed filteredWords to displayWords
      if (!_isAutoPlayEnabled || displayWords.isEmpty) return;

      final word = currentWord; 
      if (word == null) return;
      
      final firstLang = isForeignFront ? _currentLanguage.voiceCode : "en-US";
      final firstText = isForeignFront ? word.foreignText : word.englishText;

      await playback.speak(firstText, firstLang, this);
      if (!_isAutoPlayEnabled) return;

      await Future.delayed(Duration(milliseconds: (autoPlayDelay * 1000).toInt()));

      onFlipToBack(); 
      await Future.delayed(const Duration(milliseconds: 600)); 

      if (!_isAutoPlayEnabled) return;

      final secondLang = isForeignFront ? "en-US" : _currentLanguage.voiceCode;
      final secondText = isForeignFront ? word.englishText : word.foreignText;

      await playback.speak(secondText, secondLang, this);

      if (!_isAutoPlayEnabled) return;
      await Future.delayed(const Duration(milliseconds: 1500));

      onResetCard();
      await Future.delayed(const Duration(milliseconds: 1000));

      // --- BUG 2 FIX: SMART INDEX PROGRESSION ---
      bool hadQueuedUpdate = await processQueuedUpdate();

      // Check if the word we just studied is STILL sitting at the current index
      bool wordIsStillHere = false;
      if (_currentIndex < displayWords.length) {
        wordIsStillHere = (displayWords[_currentIndex].id == word.id);
      }

      if (hadQueuedUpdate && !wordIsStillHere) {
        // The word vanished from the UI (e.g., filtered out). 
        // The next card automatically slid into our current index. Stay put!
        if (_currentIndex < displayWords.length) {
          _runAutoPlayLoop(onResetCard, onFlipToBack, playback);
        } else if (_isLooping) {
          _currentIndex = 0;
          notifyListeners();
          await Future.delayed(const Duration(seconds: 1));
          _runAutoPlayLoop(onResetCard, onFlipToBack, playback);
        } else {
          stopAutoPlay();
        }
      } 
      else {
        // The word is still here OR no button was pressed. Move forward!
        if (_currentIndex < displayWords.length - 1) {
          nextCard();
          _runAutoPlayLoop(onResetCard, onFlipToBack, playback); 
        } else if (_isLooping) {
          _currentIndex = 0;
          notifyListeners();
          await Future.delayed(const Duration(seconds: 1));
          _runAutoPlayLoop(onResetCard, onFlipToBack, playback);
        } else {
          stopAutoPlay();
        }
      }
  }

  void initializeListeners() {
    _wordSubscription?.cancel();
    
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // 1. Listen to Words
    _wordSubscription = vocabRepo.getWordsStream(userId, languageCode: _currentLanguage.code).listen((newWords) {
      _words = newWords; 
      
      // --- BUG 1 FIX: SYNC THE STUDY LIST WITHOUT LOSING SHUFFLE ---
      if (_tempStudyList != null) {
        for (int i = 0; i < _tempStudyList!.length; i++) {
          // Find the updated version of this exact word from the database
          final freshWord = newWords.firstWhere(
            (w) => w.id == _tempStudyList![i].id, 
            orElse: () => _tempStudyList![i]
          );
          // Update it in place to preserve the shuffled order
          _tempStudyList![i] = freshWord;
        }
      }
      // --------------------------------------------------------------

      notifyListeners();
    });

    // 2. Listen to Playlists
    vocabRepo.watchPlaylists(_currentLanguage.code).listen((newData) {
      _playlists = newData;
      notifyListeners();
    });
  }

  Future<String> createPlaylist(String name) async {
    // 1. Generate a unique ID (Timestamp is simple and effective)
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // 2. Use the repository to create it
    // This saves it to Isar (Offline) AND Firestore (Online)
    await vocabRepo.updatePlaylistAccess(newId, name: name, languageCode: _currentLanguage.code);
    
    return newId;
  }

  Future<void> togglePlaylistAssignment(String wordId, String playlistId, bool isActive) async {
    // 1. UPDATE THE SCREEN INSTANTLY (Optimistic Update)
    final index = _words.indexWhere((w) => w.id == wordId);
    if (index != -1) {
      // Create a copy of the current playlist IDs
      List<String> newPlaylists = List.from(_words[index].playlistIds);
      
      if (isActive) {
        newPlaylists.add(playlistId);
      } else {
        newPlaylists.remove(playlistId);
      }

      // Update the word in the list with the new playlist
      // (This uses the copyWith method we discussed earlier)
      _words[index] = _words[index].copyWith(playlistIds: newPlaylists);
      notifyListeners(); // Tells the UI to refresh
    }

    // 2. SAVE TO PHONE & CLOUD (Using the Repository)
    // This calls the method we added to your Repository earlier
    await vocabRepo.updatePlaylistAssignment(wordId, playlistId, isActive);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final index = _playlists.indexWhere((p) => p.playlistId == playlistId);
    
    if (index != -1) {
      // Direct mutation since fields are not final
      _playlists[index].name = newName;
      _playlists[index].lastAccessed = DateTime.now();
      
      notifyListeners();
      
      // Call the repository to persist the change
      await vocabRepo.updatePlaylistName(playlistId, newName);
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    // 1. Remove from local memory for instant UI update
    _playlists.removeWhere((p) => p.playlistId == playlistId);
    
    // 2. If the deleted playlist was the active filter, reset to 'all'
    if (_filterStatus == playlistId) {
      _filterStatus = 'all';
    }
    
    notifyListeners();

    // 3. Tell the repository to delete it from Isar and Firestore
    await vocabRepo.deletePlaylist(playlistId);
  }
  Future<void> bulkUpdatePlaylist(String playlistId, Set<String> selectedWordIds) async {
    // 1. Loop through all words and update them locally
    for (int i = 0; i < _words.length; i++) {
      final word = _words[i];
      final shouldBeInList = selectedWordIds.contains(word.id);
      final currentlyInList = word.playlistIds.contains(playlistId);

      if (shouldBeInList != currentlyInList) {
        List<String> newPlaylists = List.from(word.playlistIds);
        if (shouldBeInList) {
          newPlaylists.add(playlistId);
        } else {
          newPlaylists.remove(playlistId);
        }
        
        // Update local memory
        _words[i] = word.copyWith(playlistIds: newPlaylists);
        
        // 2. Persist each change to repository
        // (For high performance, you could add a batch method to Repo later)
        await vocabRepo.updatePlaylistAssignment(word.id!, playlistId, shouldBeInList);
      }
    }
    
    notifyListeners();
  }

  WordPair? _queuedWord;
  
  // NEW: Let the UI see what's queued so it can fake the icon
  WordPair? get queuedWord => _queuedWord; 

  void queueWordStatusUpdate(WordPair word) {
    _queuedWord = word;
    notifyListeners(); // Tells the UI to update the icon right now
  }

  Future<bool> processQueuedUpdate() async {
    if (_queuedWord != null) {
      final tempWord = _queuedWord!;
      _queuedWord = null; // Clear the queue FIRST
      await toggleRemembered(tempWord); // THEN actually mutate and update DB
      return true; 
    }
    return false;
  }

  // Call this when the auto-play loop finishes a card
  
}
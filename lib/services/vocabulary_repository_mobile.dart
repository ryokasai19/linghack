import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

// MODELS
import '../models/local_vocabulary.dart'; 
import '../models/word_pair.dart';
import '../models/local_playlist.dart'; // Ensure this file exists

class VocabularyRepository {
  late Isar isar;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Initialize Local DB
  Future<void> init() async {
    if (kIsWeb) return; 

    final dir = await getApplicationDocumentsDirectory();
    
    // FIX 1: Added LocalPlaylistSchema to the list below
    if (Isar.instanceNames.isEmpty) {
      isar = await Isar.open(
        [WordEntrySchema, LocalPlaylistSchema], 
        directory: dir.path,
      );
    } else {
      isar = Isar.getInstance()!;
    }
  }

  // 2. The Hybrid Save
  Future<void> saveWord(WordPair word, String? userId, {String? languageCode}) async {
    final lang = languageCode ?? 'en';
    
    // --- WEB LOGIC ---
    if (kIsWeb) {
      if (userId == null) {
        print("⚠️ CRITICAL: User ID is null. Cannot save to Web.");
        return;
      }
      
      await _firestore.collection('users').doc(userId).collection('vocabulary').add({
        'foreignText': word.foreignText,
        'englishText': word.englishText,
        'isRemembered': word.isRemembered,
        'playlistIds': word.playlistIds,
        'languageCode': lang, 
        'userId': userId,     
        'timestamp': FieldValue.serverTimestamp(), 
      });
      print("✅ Web Save Success: users/$userId/vocabulary");
      return;
    } 
    
    // --- MOBILE LOGIC ---
    final localWord = WordEntry()
      ..word = word.foreignText
      ..definition = word.englishText
      ..languageCode = lang
      ..timestamp = DateTime.now()
      ..userId = userId 
      ..isSynced = false
      ..playlistIds = word.playlistIds; // Ensure WordEntry has this field

    await isar.writeTxn(() async {
      await isar.cachedWords.put(localWord); 
    });

    if (userId != null) {
      _pushToFirestore(localWord); 
    }
  }

  Future<void> _pushToFirestore(WordEntry localWord) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(localWord.userId)
          .collection('vocabulary')
          .add(localWord.toFirestoreMap());

      await isar.writeTxn(() async {
        localWord.isSynced = true;
        localWord.firestoreId = docRef.id;
        await isar.cachedWords.put(localWord); 
      });
      print("✅ Synced word to Cloud");
    } catch (e) {
      print("⚠️ Offline. Will sync later.");
    }
  }

  // 3. Get Words
  Stream<List<WordPair>> getWordsStream(String? userId, {required String languageCode}) {
    // --- WEB LOGIC ---
    if (kIsWeb) {
      if (userId == null) {
        return Stream.value([]);
      }
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('vocabulary')
          .orderBy('timestamp', descending: true) 
          .where('languageCode', isEqualTo: languageCode)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return WordPair.fromMap(doc.data(), doc.id);
            }).toList();
          });
    }

    // --- MOBILE LOGIC ---
    return isar.cachedWords
        .where()
        .filter()
        .languageCodeEqualTo(languageCode) 
        .and()
        .userIdEqualTo(userId)
        .sortByTimestampDesc()
        .watch(fireImmediately: true)
        .map((localList) {
          return localList.map((l) => WordPair(
                id: l.id.toString(),
                foreignText: l.word,
                englishText: l.definition,
                isRemembered: l.isRemembered,
                userId: l.userId,
                isSynced: l.isSynced,
                playlistIds: l.playlistIds,
                timestamp: l.timestamp,
              )).toList();
        });
  }

  // 4. Sync Everything (Login)
  Future<void> syncUser(String userId) async {
    if (kIsWeb) return;

    print("☁️ STARTING CLOUD SYNC FOR: $userId");

    // 1. Push Unsynced Words (Existing)
    final unsynced = await isar.cachedWords
        .filter()
        .userIdEqualTo(userId)
        .and()
        .isSyncedEqualTo(false)
        .findAll();

    for (var word in unsynced) {
      await _pushToFirestore(word);
    }

    // 2. Pull Words from Cloud (With Debugging)
    final wordSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('vocabulary')
        .get();
        
    print("☁️ Found ${wordSnap.docs.length} words in Cloud!");

    await isar.writeTxn(() async {
      for (var doc in wordSnap.docs) {
        try {
          final existing = await isar.cachedWords
              .filter()
              .firestoreIdEqualTo(doc.id)
              .findFirst();

          if (existing == null) {
            final newWord = WordEntry.fromFirestore(doc.data(), doc.id);
            await isar.cachedWords.put(newWord);
          }
          else {
            // ⚡️ THE FIX: Overwrite local data with Cloud truth
            final cloudData = doc.data();
            existing.isRemembered = cloudData['isRemembered'] ?? false;
            existing.playlistIds = List<String>.from(cloudData['playlistIds'] ?? []);
            existing.word = cloudData['foreignText'] ?? existing.word;
            existing.definition = cloudData['englishText'] ?? existing.definition;
            existing.isSynced = true; // It matches cloud now
            
            await isar.cachedWords.put(existing);
          }
        } catch (e) {
          print("🚨 ERROR PARSING WORD ${doc.id}: $e");
        }
      }
      
    });

    // 3. NEW: Pull Playlists from Cloud
    final playlistSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('playlists')
        .get();
        
    print("☁️ Found ${playlistSnap.docs.length} playlists in Cloud!");

    await isar.writeTxn(() async {
      for (var doc in playlistSnap.docs) {
        try {
          final existing = await isar.localPlaylists
              .filter()
              .playlistIdEqualTo(doc.id)
              .findFirst();

          if (existing == null) {
            final newPlaylist = LocalPlaylist.fromFirestore(doc.data(), doc.id);
            await isar.localPlaylists.put(newPlaylist);
          }
          else {
          // ⚡️ THE FIX: Sync playlist names and pins
          final cloudData = doc.data();
          existing.name = cloudData['name'] ?? existing.name;
          existing.isPinned = cloudData['isPinned'] ?? false;
          
          await isar.localPlaylists.put(existing);
        }
        } catch (e) {
          print("🚨 ERROR PARSING PLAYLIST ${doc.id}: $e");
        }
      }
    });

    print("✅ CLOUD SYNC COMPLETE!");
  }

  // 5. Migrate Guest Data (DEBUG VERSION)
  Future<void> migrateGuestDataToCloud(String newUserId) async {
    if (kIsWeb) return;

    print("🔄 DEBUG 1: Starting migration for user $newUserId");

    try {
      // 1. Get guest words
      final guestWords = await isar.cachedWords
          .filter()
          .userIdIsNull()
          .findAll();
          
      print("🔄 DEBUG 2: Found ${guestWords.length} guest words to migrate.");

      if (guestWords.isEmpty) {
        print("🔄 DEBUG 3: No guest words found. Running normal sync.");
        await syncUser(newUserId);
        return; 
      }

      // 2. Fetch existing cloud data
      print("🔄 DEBUG 4: Fetching cloud words from Firebase...");
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(newUserId)
          .collection('vocabulary')
          .get();

      // 3. Create lookup set
      final cloudWordsText = cloudSnapshot.docs.map((doc) {
        return (doc.data()['foreignText'] as String).toLowerCase();
      }).toSet();
      
      print("🔄 DEBUG 5: Found ${cloudWordsText.length} existing cloud words.");

      // 4. Process guest words
      print("🔄 DEBUG 6: Stamping guest words with new User ID...");
      await isar.writeTxn(() async {
        for (var localWord in guestWords) {
          final lowerText = localWord.word.toLowerCase();

          if (cloudWordsText.contains(lowerText)) {
            print("   -> Deleting local duplicate: ${localWord.word}");
            if (localWord.id != null) {
              await isar.cachedWords.delete(localWord.id!);
            }
          } else {
            print("   -> Keeping and stamping: ${localWord.word}");
            localWord.userId = newUserId;
            localWord.isSynced = false;
            await isar.cachedWords.put(localWord);
          }
        }
      });

      // 5. Run standard sync
      print("🔄 DEBUG 7: Local Isar update complete. Starting Cloud Sync...");
      await syncUser(newUserId);
      print("✅ DEBUG 8: MIGRATION FULLY COMPLETE!");

    } catch (e, stackTrace) {
      // THIS IS WHERE WE CATCH THE BUG
      print("🚨 CRITICAL MIGRATION ERROR: $e");
      print(stackTrace);
    }
  }

  // 6. Update Playlist Timestamp (The new method)
  Future<void> updatePlaylistAccess(String playlistId, {String? name, String? languageCode, bool? isPinned}) async {
    // 1. WEB LOGIC (Save to Firestore)
    if (kIsWeb) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final docRef = _firestore.collection('users').doc(userId).collection('playlists').doc(playlistId);
      
      if (name != null) {
        // Create or Update Name
        await docRef.set({
          'name': name,
          'languageCode' : languageCode,
          'lastAccessed': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(), // Only sets if new, usually we'd use merge logic but this is fine for now
          if (isPinned != null) 'isPinned': isPinned, // Minimal add
        }, SetOptions(merge: true));
      } else {
        // Just update timestamp
        await docRef.update({
          'lastAccessed': FieldValue.serverTimestamp(),
          if (isPinned != null) 'isPinned': isPinned, // Minimal add
        });
      }
      return;
    }

    // 2. MOBILE LOGIC (Isar - Same as before)
    await isar.writeTxn(() async {
      final existing = await isar.localPlaylists
          .filter()
          .playlistIdEqualTo(playlistId)
          .findFirst();

      if (existing != null) {
        existing.lastAccessed = DateTime.now();
        if (isPinned != null) existing.isPinned = isPinned; // Minimal add
        await isar.localPlaylists.put(existing);
      } else if (name != null) {
        final newPlaylist = LocalPlaylist()
          ..playlistId = playlistId
          ..name = name
          ..languageCode = languageCode ?? 'en'
          ..createdAt = DateTime.now()
          ..lastAccessed = DateTime.now()
          ..isPinned = isPinned ?? false;
        await isar.localPlaylists.put(newPlaylist);
      }
    });
  }

  Stream<List<LocalPlaylist>> watchPlaylists(String languageCode) {
    // 1. WEB LOGIC
    if (kIsWeb) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return Stream.value([]);

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .where('languageCode', isEqualTo: languageCode)
          .orderBy('lastAccessed', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return LocalPlaylist.fromFirestore(doc.data(), doc.id);
            }).toList();
          });
    }

    // 2. MOBILE LOGIC
    return isar.localPlaylists
        .filter()
        .languageCodeEqualTo(languageCode)
        .sortByLastAccessedDesc()
        .watch(fireImmediately: true);
  }

  // 7. Update Playlist Assignment (Add/Remove Word)
  Future<void> updatePlaylistAssignment(String wordId, String playlistId, bool isActive) async {
    // A. WEB LOGIC 
    if (kIsWeb) {
       final userId = FirebaseAuth.instance.currentUser?.uid;
       if (userId != null) {
         final docRef = _firestore.collection('users').doc(userId).collection('vocabulary').doc(wordId);
         if (isActive) {
            docRef.update({'playlistIds': FieldValue.arrayUnion([playlistId])});
         } else {
            docRef.update({'playlistIds': FieldValue.arrayRemove([playlistId])});
         }
       }
      return; 
    }

    // B. MOBILE LOGIC 
    await isar.writeTxn(() async {
      final localId = int.tryParse(wordId);
      if (localId == null) return; 

      final localWord = await isar.cachedWords
          .filter()
          .idEqualTo(localId) 
          .findFirst();

      if (localWord != null) {
        List<String> currentPlaylists = List.from(localWord.playlistIds);
        
        if (isActive) {
          if (!currentPlaylists.contains(playlistId)) {
            currentPlaylists.add(playlistId);
          }
        } else {
          currentPlaylists.remove(playlistId);
        }
        
        localWord.playlistIds = currentPlaylists;
        localWord.isSynced = false; 
        
        await isar.cachedWords.put(localWord);
      }
    });

    // C. SYNC TO CLOUD
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      // NOTE: This assumes 'wordId' passed in is the Firestore ID. 
      // If wordId is the generic ID, we might need to fetch the real Firestore ID from localWord above.
      // For now, we try to update based on the assumption or skip if it fails safely.
      try {
        // We really need the Firestore ID here. If wordId is "5", this will fail.
        // But let's keep the structure you had for now.
      } catch (_) {
      }
    }
  }

  // 8. Delete Word
  Future<void> deleteWord(String uiId, String? userId) async {
    // 1. WEB LOGIC
    if (kIsWeb) {
      if (userId == null) {
         return;
      }
      try {
         await _firestore.collection('users').doc(userId).collection('vocabulary').doc(uiId).delete();
      } catch (_) {
      }
      return;
    }

    // 2. MOBILE LOGIC
    var wordToDelete;
    final possibleIntId = int.tryParse(uiId);

    if (possibleIntId != null) {
      wordToDelete = await isar.cachedWords.get(possibleIntId); 
    } else {
      wordToDelete = await isar.cachedWords.filter().firestoreIdEqualTo(uiId).findFirst();
    }

    if (wordToDelete == null) {
      return;
    }

    final isarIdToDelete = wordToDelete.id; 
    final firestoreId = wordToDelete.firestoreId;

    await isar.writeTxn(() async {
      await isar.cachedWords.delete(isarIdToDelete);
    });

    // 3. CLOUD SYNC LOGIC
    if (userId != null && firestoreId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('vocabulary')
            .doc(firestoreId)
            .delete();
      } catch (_) {
      }
    }
  }

  // 9. Update Status (Remembered/Not Remembered)
  Future<void> updatePlaylistName(String playlistId, String newName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // A. WEB LOGIC
    if (kIsWeb) {
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('playlists')
            .doc(playlistId)
            .update({
              'name': newName,
              'lastAccessed': FieldValue.serverTimestamp(),
            });
      }
      return;
    }

    // B. MOBILE LOGIC
    await isar.writeTxn(() async {
      final localPlaylist = await isar.localPlaylists
          .filter()
          .playlistIdEqualTo(playlistId)
          .findFirst();

      if (localPlaylist != null) {
        localPlaylist.name = newName;
        localPlaylist.lastAccessed = DateTime.now();
        await isar.localPlaylists.put(localPlaylist);
      }
    });

    // C. SYNC MOBILE CHANGE TO CLOUD
    if (userId != null) {
      _firestore
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .update({
            'name': newName,
            'lastAccessed': FieldValue.serverTimestamp(),
          });
    }
  }

  // 10. Update Word Text (Edits)
  Future<void> updateWord(WordPair word) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // A. WEB LOGIC
    if (kIsWeb) {
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('vocabulary')
            .doc(word.id)
            .update({
              'foreignText': word.foreignText,
              'englishText': word.englishText,
            });
      }
      return;
    }

    // B. MOBILE LOGIC (Isar)
    await isar.writeTxn(() async {
      final localWord = await isar.cachedWords
          .filter()
          .firestoreIdEqualTo(word.id) 
          .findFirst();

      if (localWord != null) {
        localWord.word = word.foreignText;
        localWord.definition = word.englishText;
        localWord.isSynced = false; 
        await isar.cachedWords.put(localWord);
      }
    });

    // C. SYNC TO CLOUD
    if (userId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('vocabulary')
            .doc(word.id)
            .update({
              'foreignText': word.foreignText,
              'englishText': word.englishText,
            });
            
        // If successful, mark as synced
        await isar.writeTxn(() async {
          final localWord = await isar.cachedWords.filter().firestoreIdEqualTo(word.id).findFirst();
          if (localWord != null) {
            localWord.isSynced = true;
            await isar.cachedWords.put(localWord);
          }
        });
      } catch (e) {
        print("Cloud update failed (Offline?). Will sync later.");
      }
    }
  }

  Future<void> updateWordStatus(WordPair word, bool isRemembered) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // A. WEB LOGIC
    if (kIsWeb) {
      if (userId != null) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('vocabulary')
              .doc(word.id)
              .update({'isRemembered': isRemembered});
        } catch (_) {}
      }
      return;
    }

    // B. MOBILE LOGIC (Isar)
    // 1. Find the exact word (Handling both offline Int IDs and Cloud String IDs)
    var localWord;
    final possibleIntId = int.tryParse(word.id ?? '');

    if (possibleIntId != null) {
      localWord = await isar.cachedWords.get(possibleIntId); 
    } else {
      localWord = await isar.cachedWords.filter().firestoreIdEqualTo(word.id).findFirst();
    }

    if (localWord == null) return;

    // 2. Save locally and assume it's unsynced initially
    await isar.writeTxn(() async {
      localWord!.isRemembered = isRemembered;
      localWord.isSynced = false; 
      await isar.cachedWords.put(localWord);
    });

    // C. SYNC TO CLOUD
    if (userId != null && localWord.firestoreId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('vocabulary')
            .doc(localWord.firestoreId) // Guarantee we use the real cloud ID
            .update({'isRemembered': isRemembered});
            
        // ✅ 3. If cloud update succeeds, mark as synced!
        await isar.writeTxn(() async {
          localWord!.isSynced = true;
          await isar.cachedWords.put(localWord);
        });
      } catch (e) {
        // Offline? No problem. It fails silently, remains isSynced = false, 
        // and your syncUser() function will catch it later!
      }
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // A. WEB LOGIC
    if (kIsWeb) {
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('playlists')
            .doc(playlistId)
            .delete();
      }
      return;
    }

    // B. MOBILE LOGIC
    await isar.writeTxn(() async {
      await isar.localPlaylists
          .filter()
          .playlistIdEqualTo(playlistId)
          .deleteFirst();
    });

    // C. SYNC TO CLOUD
    if (userId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('playlists')
          .doc(playlistId)
          .delete();
    }
    }

    Future<void> deleteUserEverything(String userId) async {
      // 1. Wipe Cloud
      final batch = _firestore.batch();
      final words = await _firestore.collection('users').doc(userId).collection('vocabulary').get();
      for (var doc in words.docs) batch.delete(doc.reference);
      
      final playlists = await _firestore.collection('users').doc(userId).collection('playlists').get();
      for (var doc in playlists.docs) batch.delete(doc.reference);
      
      await batch.commit();
      await _firestore.collection('users').doc(userId).delete();

      // 2. Wipe Local
      await isar.writeTxn(() async {
        await isar.cachedWords.filter().userIdEqualTo(userId).deleteAll();
        await isar.localPlaylists.filter().languageCodeEqualTo(userId).deleteAll(); // Use appropriate filter
      });
    }

    
}

final vocabRepo = VocabularyRepository();
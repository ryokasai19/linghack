import 'package:flutter/material.dart';
import 'widgets/filter_chips.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'widgets/flashcard_view.dart';
import 'package:flip_card/flip_card.dart';
import 'services/playback_service.dart';
import 'services/image_service.dart';
import 'services/ocr_service.dart';
import 'models/word_pair.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'services/translation_service.dart';
import 'package:flutter/foundation.dart'; // Contains kIsWeb
import 'widgets/crop_selection_view.dart';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/review_scan_screen.dart';
import 'widgets/language_selector.dart';
import 'services/ai_service.dart';
import 'services/ai/language_factory.dart';
import 'services/vocabulary_repository.dart';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'services/user_repository.dart';
import 'services/remote_config_service.dart';

import 'package:google_sign_in/google_sign_in.dart'; // Required if you use types from it
import 'package:firebase_auth/firebase_auth.dart'; // Required if you use types from it

import 'auth_gate.dart';

import 'widgets/playlist_shelf.dart';

import '../models/local_playlist.dart';
import '../widgets/all_playlists_view.dart';
import 'package:intl/intl.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firebase_options.dart';

final userRepo = UserRepository();
void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Try to initialize all dependencies
    await dotenv.load(fileName: ".env");
    
    print("🚨 1. Starting Firebase...");
    if (kIsWeb){
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBgdq8-vFRR7_Y1Ut5-gLvUYKTDiB9jjuI",
          authDomain: "linghack2-f7610.firebaseapp.com",
          projectId: "linghack2-f7610",
          storageBucket: "linghack2-f7610.firebasestorage.app",
          messagingSenderId: "583408815077",
          appId: "1:583408815077:web:645fcb426747c076d2fd0c"
        ),
      );
    } else {
        await Firebase.initializeApp(
         options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    print("✅ 1. Firebase Done!");

    print("🚨 2. Starting Isar...");
    await vocabRepo.init(); 
    print("✅ 2. Isar Done!");

    print("🚨 3. Starting User Repo...");
    await userRepo.initialize();
    print("✅ 3. User Repo Done!");

    print("🚨 4. Starting Remote Config...");
    // We add a specific timeout/try-catch here because network calls on launch are risky
    try {
      await RemoteConfigService().initialize().timeout(const Duration(seconds: 5));
    } catch (e) {
      print("⚠️ Remote Config failed or timed out, but continuing anyway: $e");
    }
    print("✅ 4. Remote Config Done!");

    print("🚨 5. RUNNING APP NOW!");
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: userRepo), 
        ],
        child: const MyApp(),
      ),
    );

  } catch (e, stackTrace) {
    // 6. THE SAFETY NET: If anything fatally crashes, show an error UI instead of a white screen
    print("🚨 FATAL LAUNCH ERROR: $e");
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text("Launch Error", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LingHack!!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: AuthGate(
        child: HomeScreen(), // Or whatever your main scaffold widget is named
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  final PlaybackService _playbackService = PlaybackService();
  final ImageService _imageService = ImageService();
  final OcrService _ocrService = OcrService();
  final TranslationService _translationService = TranslationService();
  bool _isStudyMode = false;
  bool _isProcessing = false;
  bool _isSearching = false;
  final GlobalKey<FlipCardState> _flashcardKey = GlobalKey<FlipCardState>();
  String _statusMessage = "Scanning...";
  Uint8List? _scannedImageBytes;
  final AiService _aiService = AiService(dotenv.env['AI_API_KEY'] ?? '');

  final ScrollController _scrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LanguageProvider>();
      // provider.initializeListeners();
      
      // FIX: Pass the current language voice code to warmup
      _playbackService.warmUp(provider.currentLanguage.voiceCode); 
    });
  }


  void _showReauthDialog(BuildContext context, dynamic userRepo) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Security Verification"),
      content: const Text(
          "For your security, you must verify your identity before deleting your account. Please log in again."),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            userRepo.signOut(); // Log them out to force a fresh Apple Sign-In
          },
          child: const Text("Log Out & Verify"),
        ),
      ],
    ),
  );
}

  void _showAccountDeleteConfirmation(BuildContext context, dynamic userRepo) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Account?"),
      content: const Text(
          "This is permanent. All your flashcards and progress will be wiped from the cloud and this device."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close the first dialog

            try {
              // 1. Delete all flashcard data (Keep this in your LanguageProvider)
              final provider = context.read<LanguageProvider>();
              await provider.deleteAccount(); // Make sure this only deletes vocab now!

              // 2. Delete Auth and Firestore profile
              await userRepo.deleteAccount();

            } catch (e) {
              // 3. Catch the specific Apple/Firebase security error
              if (e.toString().contains('requires-recent-login')) {
                if (context.mounted) {
                  _showReauthDialog(context, userRepo);
                }
              } else {
                print("General Deletion Error: $e");
              }
            }
          },
          child: const Text("DELETE", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}


  // 1. Changed to Future<void> and added async
Future<void> _showPickerOptions(BuildContext context, LanguageProvider provider) async {
    
    // 2. THE REAL NETWORK CHECK
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    bool isOffline = connectivityResult.contains(ConnectivityResult.none);

    // 3. THE BANNER
    if (isOffline) {
      if (context.mounted) { // Always check mounted after an await!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No internet connection. Please connect to scan."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Stops here if offline
    }

    // 4. IF ONLINE, SHOW THE MENU
    if (!context.mounted) return; // Safety check
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _processImage(fromCamera: false, provider: provider);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _processImage(fromCamera: true, provider: provider);
                  },
                ),
            ],
          ),
        );
      },
    );
}

  Future<void> _runAIPipeline(Uint8List imageBytes, LanguageProvider provider) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Analyzing Selection...";
    });

    try {
      // 1. Convert the cropped bytes back to an XFile
      final xFile = XFile.fromData(imageBytes);

      // 2. Get Raw Text 
      final List<String> rawLines = await _ocrService.getTextFromImage(
        xFile, 
        provider.currentLanguage.code
      );
      
      // 3. Clean the text
      final strategy = LanguageFactory.getStrategy(provider.currentLanguage.code);
      final String fullText = strategy.cleanOcrText(rawLines.join('\n'));

      if (fullText.isEmpty) {
         throw Exception("No text found in selection.");
      }

      // 4. Send to AI for extraction
      final List<WordPair> aiExtractedWords = await _aiService.extractWords(
        text: fullText, 
        prompt: strategy.getSystemPrompt() 
      );

      // 5. Navigate directly to Review Screen (Let the screen handle duplicates!)
      if (aiExtractedWords.isNotEmpty) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewScanScreen(scannedWords: aiExtractedWords),
            ),
          );
        }
      } else {
        _showSnack("No readable words found.");
      }

    } catch (e) {
      print("Error: $e");
      _showSnack("Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  Future<void> _processImage({required bool fromCamera, required LanguageProvider provider}) async {
    // 1. Pick the file (Keep this)
    final XFile? file = await _imageService.pickImage(fromCamera: fromCamera);

    if (file != null) {
      // 2. Read bytes (New: needed for Web cropping)
      final bytes = await file.readAsBytes();

      setState(() {
        _scannedImageBytes = bytes; // <--- This triggers the UI to show the Crop Screen
        _isProcessing = false;  // Ensure spinner is OFF so user can see the crop screen
      });
    }
  }
  
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final displayWords = provider.filteredWords;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final Map<String, List<WordPair>> groupedWords = provider.wordsByDate;
    final List<String> groupedKeys = groupedWords.keys.toList();

    return Scaffold(
      appBar: AppBar(
        leading: provider.isAutoPlayEnabled ? const SizedBox.shrink() : null,
        title: (isMobile && _isSearching && !_isStudyMode)
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search words...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                style: const TextStyle(color: Colors.black87),
                onChanged: (val) => provider.setSearchQuery(val),
              )
            : const Text("LingHack"),
        actions: [
          if (isMobile && !_isStudyMode)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  // Clear the search when closing it
                  if (!_isSearching) provider.setSearchQuery("");
                });
              },
            ),
          // 1. LANGUAGE SWITCHER
          if (!_isStudyMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (context) => const LanguageSelector(),
                  );
                },
                icon: const Icon(Icons.language, color: Colors.blueGrey),
                label: Text(
                  provider.currentLanguage.code.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),
            ),

          // 2. USER LOGIN / AVATAR
          Consumer<UserRepository>(
            builder: (context, userRepo, child) {
              // A. If Logged In -> Show Avatar with Logout Option
              if (userRepo.user != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: PopupMenuButton(
                    offset: const Offset(0, 40),
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundImage: () {
                        final photoUrl = userRepo.user?.photoURL;
                        // Only use NetworkImage if the URL actually starts with http/https
                        if (photoUrl != null && photoUrl.startsWith('http')) {
                          return NetworkImage(photoUrl);
                        }
                        return null;
                      }(), // Calling the function immediately
                      child: (userRepo.user?.photoURL == null || userRepo.user!.photoURL!.isEmpty)
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row( // Row is usually better than Wrap inside menus
                          children: [
                            Icon(Icons.logout, color: Colors.black54),
                            SizedBox(width: 12),
                            Text("Logout"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.redAccent),
                            SizedBox(width: 12),
                            Text("Delete Account", style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'logout') {
                        userRepo.signOut();
                      } else if (value == 'delete') {
                        _showAccountDeleteConfirmation(context, userRepo);
                      }
                    },
                  ),
                );
              }
              // B. If Guest -> Show "Login" Button
              else {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: const Icon(Icons.login, color: Colors.blueGrey),
                    tooltip: "Sign In to Save",
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Sign In",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),

                              // Unified Google Button
                              // Unified Google Button with White Background
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white, // Forces white background
                                  minimumSize: const Size(double.infinity, 44),
                                  side: const BorderSide(color: Colors.black, width: 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  userRepo.signInWithGoogle();
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                                    const SizedBox(width: 8),
                                    const Text(
                                    "Continue with Google",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 17, // Apple's default font size for this button
                                      fontWeight: FontWeight.w600, // Matches the semi-bold look of the Apple button
                                      letterSpacing: -0.41, // Mimics iOS system font tracking
                                    ),
                                  ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Apple Button
                              SignInWithAppleButton(
                                style: SignInWithAppleButtonStyle.whiteOutlined,
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await userRepo.signInWithApple();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
        ],
      ),

      // THE FIX: The entire body is now one Master Stack
      body: Stack(
        children: [
          
          // ==========================================
          // LAYER 1: BASE UI (Welcome Screen OR Main List)
          // ==========================================
          provider.words.isEmpty
              // 1A. THE WELCOME SCREEN (If 0 words)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_outlined,
                            size: 80, color: Colors.blueGrey.shade200),
                        const SizedBox(height: 24),
                        const Text("Welcome to LingHack! 🎉",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text(
                          "Your vocabulary list is currently empty.\nStart building your deck by scanning a page or adding words manually!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey,
                              height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            // PRIMARY ACTION: Scan
                            Expanded(
                              child: SizedBox(
                                height: isMobile ? 36 : 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(Icons.camera_alt,
                                      size: isMobile ? 18 : 24),
                                  label: Text("Scan",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 13 : 14)),
                                  onPressed: () async =>
                                      await _showPickerOptions(
                                          context, provider),
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // SECONDARY ACTION: Manual Add
                            Expanded(
                              child: SizedBox(
                                height: isMobile ? 36 : 50,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
                                    side: BorderSide(
                                        color: Colors.blueGrey.shade300),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: Icon(Icons.add,
                                      size: isMobile ? 18 : 24),
                                  label: Text("Add Manual",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 13 : 14)),
                                  onPressed: () =>
                                      _showWordDialog(context, provider),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              // 1B. THE MAIN LIST UI (If words exist)
              : Column(
                  children: [
                    // Fixed Header Section
                    if (!provider.isAutoPlayEnabled &&
                        !(_isSearching && isMobile)) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: FilterChips(),
                      ),
                    ],

                    // SEARCH AND CALENDAR HEADER
                    if (!isMobile &&
                        !_isStudyMode &&
                        provider.filterStatus != 'playlists_view')
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Search words...",
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: provider.searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => provider
                                              .setSearchQuery(""),
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onChanged: (val) =>
                                    provider.setSearchQuery(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: "Jump to Date",
                              icon: const Icon(Icons.calendar_month,
                                  color: Colors.blue),
                              onPressed: () async {
                                final Map<String, List<WordPair>> grouped =
                                    provider.wordsByDate;

                                final Set<DateTime> activeDates = grouped.keys
                                    .where((key) => key != "Earlier")
                                    .map((key) => DateFormat('MMMM d, yyyy')
                                        .parse(key))
                                    .toSet();

                                DateTime initialCalendarDate =
                                    activeDates.isNotEmpty
                                        ? activeDates.reduce((a, b) =>
                                            a.isAfter(b) ? a : b)
                                        : DateTime.now();

                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: initialCalendarDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  selectableDayPredicate: (DateTime day) {
                                    return activeDates.any((activeDay) =>
                                        activeDay.year == day.year &&
                                        activeDay.month == day.month &&
                                        activeDay.day == day.day);
                                  },
                                );

                                if (picked != null) {
                                  String targetDate =
                                      DateFormat('MMMM d, yyyy')
                                          .format(picked);
                                  _jumpToDate(targetDate, grouped);
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                    // MAIN LIST AREA
                    Expanded(
                      child: provider.filterStatus == 'playlists_view'
                          ? const AllPlaylistsPage()
                          : _isStudyMode && displayWords.isNotEmpty
                              ? FlashcardView(cardKey: _flashcardKey)
                              : provider.isCalendarMode
                                  ? ListView.builder(
                                      controller: _scrollController,
                                      key: const PageStorageKey(
                                          'calendar_list_view'),
                                      padding: const EdgeInsets.only(
                                          bottom: 100),
                                      itemCount: provider
                                              .wordsByDate.keys.length +
                                          1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return Padding(
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 8.0),
                                            child: PlaylistShelf(
                                              onCreatePlaylist: () =>
                                                  _createNewPlaylistOnly(
                                                      context),
                                              onRenamePlaylist: (p) =>
                                                  _showRenameDialog(
                                                      context, p),
                                              onDeletePlaylist: (p) =>
                                                  _showDeleteConfirmation(
                                                      context, p),
                                              onAddWords: (p) =>
                                                  _showBulkWordPicker(
                                                      context, p),
                                            ),
                                          );
                                        }

                                        final String dateKey =
                                            groupedKeys[index - 1];
                                        final List<WordPair> wordsForDate =
                                            groupedWords[dateKey]!;

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // THE HEADER WITH STUDY BUTTON
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 16,
                                                  vertical: 8),
                                              color: dateKey == "Earlier"
                                                  ? Colors.amber.shade50
                                                  : Colors.blueGrey.shade50,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8.0),
                                                    child: Text(
                                                      dateKey,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold,
                                                        color: dateKey ==
                                                                "Earlier"
                                                            ? Colors.orange
                                                                .shade900
                                                            : Colors.blueGrey
                                                                .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.play_circle_fill,
                                                        color: Colors.blue,
                                                        size: 24),
                                                    tooltip:
                                                        "Study words from $dateKey",
                                                    onPressed: () {
                                                      provider.setStudyList(
                                                          wordsForDate);
                                                      setState(() {
                                                        _isStudyMode = true;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // THE WORDS
                                            ...wordsForDate.map((word) {
                                              return Card(
                                                margin: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 16,
                                                    vertical: 4),
                                                child: ListTile(
                                                  title: Text(
                                                    word.foreignText,
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold),
                                                  ),
                                                  subtitle:
                                                      Text(word.englishText),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize
                                                        .min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          word.isRemembered
                                                              ? Icons.bookmark
                                                              : Icons
                                                                  .bookmark_border,
                                                          color: Colors.amber,
                                                        ),
                                                        onPressed: () =>
                                                            provider
                                                                .toggleRemembered(
                                                                    word),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.playlist_add,
                                                            color: Colors
                                                                .green),
                                                        onPressed: () =>
                                                            _showPlaylistDialog(
                                                                context,
                                                                word),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.edit,
                                                            color: Colors
                                                                .blue),
                                                        onPressed: () =>
                                                            _showWordDialog(
                                                                context,
                                                                provider,
                                                                word: word),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.delete,
                                                            color: Colors
                                                                .red),
                                                        onPressed: () =>
                                                            _confirmDelete(
                                                                context,
                                                                provider,
                                                                word),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),

                                            const SizedBox(height: 12),
                                          ],
                                        );
                                      },
                                    )
                                  : ListView.builder(
                                      key: const PageStorageKey(
                                          'word_list_view'),
                                      padding: const EdgeInsets.only(
                                          bottom: 100),
                                      itemCount: displayWords.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                top: 8.0, bottom: 8.0),
                                            child: PlaylistShelf(
                                              onCreatePlaylist: () =>
                                                  _createNewPlaylistOnly(
                                                      context),
                                              onRenamePlaylist: (playlist) =>
                                                  _showRenameDialog(
                                                      context, playlist),
                                              onDeletePlaylist: (playlist) =>
                                                  _showDeleteConfirmation(
                                                      context, playlist),
                                              onAddWords: (playlist) =>
                                                  _showBulkWordPicker(
                                                      context, playlist),
                                            ),
                                          );
                                        }

                                        final word =
                                            displayWords[index - 1];

                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                          child: ListTile(
                                            title: Text(
                                              word.foreignText,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                            subtitle:
                                                Text(word.englishText),
                                          ),
                                        );
                                      },
                                    ),
                    ),

                    // BOTTOM CONTROLS (Fixed Footer)
                    if (!_isStudyMode && !_isSearching)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;

                          return SafeArea(
                            bottom: true,
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 10 : 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (displayWords.isNotEmpty)
                                    SizedBox(
                                      height: isMobile ? 40 : 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: provider
                                                  .filteredWords.isEmpty
                                              ? Colors.grey
                                              : Colors.green,
                                          foregroundColor: Colors.white,
                                          minimumSize: Size(
                                              double.infinity,
                                              isMobile ? 40 : 50),
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: provider
                                                .filteredWords.isEmpty
                                            ? null
                                            : () {
                                                provider.setStudyList(
                                                    provider.filteredWords,
                                                    shuffle: true);
                                                setState(() =>
                                                    _isStudyMode = true);
                                              },
                                        child: Text(
                                          provider.filteredWords.isEmpty
                                              ? "Add words before start learning"
                                              : "Start Learning",
                                          style: TextStyle(
                                              fontSize: isMobile ? 13 : 14),
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: isMobile ? 8 : 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: isMobile ? 36 : 50,
                                          child: ElevatedButton.icon(
                                            icon: Icon(Icons.add_a_photo,
                                                size: isMobile ? 18 : 24),
                                            label: Text("Scan",
                                                style: TextStyle(
                                                    fontSize: isMobile
                                                        ? 13
                                                        : 14)),
                                            onPressed: () async =>
                                                await _showPickerOptions(
                                                    context, provider),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: isMobile ? 36 : 50,
                                          child: OutlinedButton.icon(
                                            icon: Icon(Icons.add,
                                                size: isMobile ? 18 : 24),
                                            label: Text("Add Manual",
                                                style: TextStyle(
                                                    fontSize: isMobile
                                                        ? 13
                                                        : 14)),
                                            onPressed: () =>
                                                _showWordDialog(
                                                    context, provider),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 4 : 10),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    if (_isStudyMode)
                      SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: TextButton.icon(
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Back to List"),
                                onPressed: () {
                                  provider.clearStudyList();
                                  setState(() {
                                    _isStudyMode = false;
                                  });
                                }),
                          ),
                        ),
                      ),
                  ],
                ),

          // ==========================================
          // LAYER 2: CROP SELECTION VIEW
          // ==========================================
          if (_scannedImageBytes != null)
            Positioned.fill(
              child: PopScope(
                canPop: false,
                onPopInvoked: (didPop) {
                  if (didPop) return;
                  setState(() => _scannedImageBytes = null);
                },
                child: CropSelectionView(
                  imageBytes: _scannedImageBytes!,
                  onCancel: () => setState(() => _scannedImageBytes = null),
                  onScanStarted: () => setState(() => _isProcessing = true),
                  onCropConfirmed: (croppedBytes) {
                    setState(() => _scannedImageBytes = null);
                    _runAIPipeline(croppedBytes, provider);
                  },
                ),
              ),
            ),

          // ==========================================
          // LAYER 3: SPINNER OVERLAY
          // ==========================================
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.8),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  Text(_statusMessage,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "The extraction might be inaccurate if the image contains handwriting or is unclear.\n\nIt might take a while depending on the complexity of the image structure.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _jumpToDate(String targetDate, Map<String, List<WordPair>> groupedData) {
  int targetIndex = -1;
  double offset = 0;

  // Find the index of the date key
  final keys = groupedData.keys.toList();
  for (int i = 0; i < keys.length; i++) {
    if (keys[i] == targetDate) {
      targetIndex = i;
      break;
    }
    
    // Estimate height: Header (~40px) + (Number of words * Card height ~72px)
    offset += 40 + (groupedData[keys[i]]!.length * 72);
  }

  if (targetIndex != -1) {
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No words found for this date")),
    );
  }
}

  Future<void> _showWordDialog(BuildContext context, LanguageProvider provider,
      {WordPair? word}) async {
    final isEditing = word != null;
    final foreignController =
        TextEditingController(text: word?.foreignText ?? '');
    final englishController =
        TextEditingController(text: word?.englishText ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Word" : "Add New Word"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: foreignController,
              decoration: InputDecoration(labelText: provider.currentLanguage.name),
            ),
            TextField(
              controller: englishController,
              decoration: const InputDecoration(labelText: "English"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newPair = WordPair(
                id: word?.id,
                foreignText: foreignController.text,
                englishText: englishController.text,
                isRemembered: word?.isRemembered ?? false,
              );

              if (isEditing) {
                int idx = provider.words.indexWhere((w) => w.id == word.id);
                provider.editWord(idx, newPair);
              } else {
                provider.addWord(newPair);
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewPlaylistOnly(BuildContext context) async {
    final provider = context.read<LanguageProvider>();
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New List"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter list name..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await provider.createPlaylist(name);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, LocalPlaylist playlist) async {
    final provider = context.read<LanguageProvider>();
    // Pre-fill the controller with the current name
    final controller = TextEditingController(text: playlist.name);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Playlist"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new name..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != playlist.name) {
                // Assuming your provider has a rename method
                await provider.renamePlaylist(playlist.playlistId, newName);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, LocalPlaylist playlist) async {
    final provider = context.read<LanguageProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: Text("Are you sure you want to delete '${playlist.name}'? The words inside will not be deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // We will create this provider method next
              await provider.deletePlaylist(playlist.playlistId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkWordPicker(BuildContext context, LocalPlaylist playlist) async {
    final provider = context.read<LanguageProvider>();
    final allWords = provider.words;
    
    // Track which words are currently selected in the dialog
    // We initialize it with words already in this playlist
    Set<String> selectedWordIds = allWords
        .where((w) => w.playlistIds.contains(playlist.playlistId))
        .map((w) => w.id!)
        .toSet();

    String searchQuery = "";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter words based on search
            final filtered = allWords.where((w) {
              final query = searchQuery.toLowerCase();
              return w.foreignText.toLowerCase().contains(query) || 
                    w.englishText.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Text("Add to ${playlist.name}"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: "Search words...",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final word = filtered[index];
                          final isAdded = selectedWordIds.contains(word.id);

                          return CheckboxListTile(
                            title: Text(word.foreignText),
                            subtitle: Text(word.englishText),
                            value: isAdded,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedWordIds.add(word.id!);
                                } else {
                                  selectedWordIds.remove(word.id!);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Perform the batch update
                    await provider.bulkUpdatePlaylist(playlist.playlistId, selectedWordIds);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, var provider, var word) async {
    // 1. Show the pop-up and wait for their answer
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Word"),
        content: Text("Are you sure you want to delete '${word.foreignText}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // User tapped Cancel
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true), // User tapped Delete
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    // 2. If they said yes, fire the exact word sniper we built earlier!
    if (shouldDelete == true) {
      provider.removeWord(word);
    }
  }

  Future<void> _showPlaylistDialog(BuildContext context, WordPair word) async {
    final provider = context.read<LanguageProvider>();
    final playlists = provider.playlists;
    final newPlaylistController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be full-screen
      useSafeArea: true, // Keeps it out of the device notch/status bar
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // This grabs the height of the keyboard so we can push the UI up
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: FractionallySizedBox(
                heightFactor: 0.9, // Takes up 90% of the screen height
                child: Column(
                  children: [
                    // 1. Drag Handle & Header (Spotify Style)
                    const SizedBox(height: 12),
                    Container(
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            "Add to Lists",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context), // Close button
                        ),
                      ],
                    ),
                    const Divider(),

                    // 2. Playlists List (Expanded to fill available space)
                    Expanded(
                      child: playlists.isNotEmpty
                          ? ListView(
                              shrinkWrap: true,
                              children: playlists.map((playlist) {
                                // 1. Get the LIVE version of the word from the provider's list
                                final liveWord = provider.words.firstWhere(
                                  (w) => w.id == word.id, 
                                  orElse: () => word
                                );
                                
                                // 2. Use the liveWord to check selection
                                final isSelected = liveWord.playlistIds.contains(playlist.playlistId);

                                return CheckboxListTile(
                                  title: Text(playlist.name),
                                  value: isSelected,
                                  onChanged: (bool? value) async {
                                    if (word.id != null && value != null) {
                                      // 3. Trigger the update
                                      await provider.togglePlaylistAssignment(word.id!, playlist.playlistId, value);
                                      // 4. Refresh the sheet
                                      setModalState(() {});
                                    }
                                  },
                                );
                              }).toList(),
                            )
                          : const Center(
                              child: Text(
                                "No playlists yet. Create one below!",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                    ),

                    const Divider(height: 1),

                    // 3. New Playlist Input (Fixed safely above the keyboard)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: newPlaylistController,
                        decoration: InputDecoration(
                          hintText: "New Playlist Name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                            onPressed: () async {
                              final text = newPlaylistController.text.trim();
                              if (text.isNotEmpty && word.id != null) {
                                String newId = await provider.createPlaylist(text);
                                await provider.togglePlaylistAssignment(word.id!, newId, true);
                                newPlaylistController.clear();
                                setModalState(() {});
                              }
                            },
                          ),
                        ),
                        onSubmitted: (_) async {
                          final text = newPlaylistController.text.trim();
                          if (text.isNotEmpty && word.id != null) {
                            String newId = await provider.createPlaylist(text);
                            await provider.togglePlaylistAssignment(word.id!, newId, true);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import '../providers/language_provider.dart';

class PlaybackService {
  static final FlutterTts _tts = FlutterTts();
  Timer? _timer;
  // 1. Add the tracking variable
  bool isSpeaking = false;

  // 2. Add this constructor to listen to the TTS engine
  PlaybackService() {
    // --- NEW: BYPASS iOS MUTE SWITCH ---
    _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
    // -----------------------------------

    _tts.setStartHandler(() {
      isSpeaking = true;
    });
    
    _tts.setCompletionHandler(() {
      isSpeaking = false;
    });
    
    _tts.setCancelHandler(() {
      isSpeaking = false;
    });
    
    _tts.setErrorHandler((msg) {
      isSpeaking = false;
    });
  }

  Future<void> logAvailableVoices() async {
    await _tts.getVoices;
  }
  
  // Custom settings
  
  final int _nextCardDelay = 2; // Seconds to wait before moving to next card

  // NEW: Helper to wake up the engine
  Future<void> warmUp(String voiceCode) async {
    try {
    //   await _tts.awaitSpeakCompletion(true); // Ensure it waits for commands
      await _tts.setLanguage(voiceCode);       // Pre-set Hungarian
      await _tts.setVolume(1.0);             // Dummy command to force initialization
      
    } catch (e) {
      print("TTS Warmup error: $e");
    }
  }

  Future<void> startLoop(LanguageProvider provider, GlobalKey<FlipCardState> cardKey) async {
    stop();

    Future<void> playSequence() async {
      if (!provider.isAutoPlayEnabled) return;
      final word = provider.currentWord;
      if (word == null) return;

      // Speak Front
      await speak(word.foreignText, provider.currentLanguage.voiceCode, provider); 

      // Use provider.autoPlayDelay instead of fixed 3 seconds
      _timer = Timer(Duration(milliseconds: (provider.autoPlayDelay * 1000).toInt()), () async {
        if (!provider.isAutoPlayEnabled) return;
        
        cardKey.currentState?.toggleCard();
        
        // Speak Back
        await speak(word.englishText, "en-US", provider);

        _timer = Timer(const Duration(seconds: 2), () async { // Delay before next card
           if (!provider.isAutoPlayEnabled) return;
           
           if (cardKey.currentState?.isFront == false) {
             cardKey.currentState?.toggleCard();
           }
           
           if (provider.currentIndex < provider.words.length - 1) {
             provider.nextCard();
             playSequence(); 
           } else {
             provider.toggleAutoPlay();
           }
        });
      });
    }
    playSequence();
  }

  Map? _findBestVoice(List<dynamic> voices, String langCode) {
    try {
      // 1. Filter for the right locale
      final langVoices = voices.where((v) => v['locale'].toString().contains(langCode)).toList();
      if (langVoices.isEmpty) return null;

      // 2. HARDCODED FAVORITES (Highest Quality)
      // We search for these specific names from your console log
      final bestNames = [
      // Japanese (O-Ren and Hattori are high-quality iOS/macOS picks)
      'O-Ren', 'Hattori', 'Kyoko', 'Google 日本語',
      
      // English (Samantha is the gold standard; Eddy/Flo/Reed are Neural)
      'Samantha', 'Eddy (English (United States))', 'Flo (English (United States))', 'Reed (English (United States))',
      
      // Hungarian (Tünde is your best match)
      'Tünde', 'Google magyar',
      
      // French (Thomas and Amélie are classic high-quality voices)
      'Thomas', 'Amélie', 'Google français', 'Marie',
      
      // Spanish (Mónica and Paulina are very clear)
      'Mónica', 'Paulina', 'Google español',
      
      // Chinese (Li-Mu and Tingting are the modern standards)
      'Li-Mu', 'Tingting', 'Google 普通话（中国大陆）',
      
      // German (Anna and Helena are very natural)
      'Anna', 'Helena', 'Google Deutsch',
      
      // Italian (Alice is the best-known natural Italian voice)
      'Alice', 'Google italiano',
      
      // Korean (Yuna is the standard high-quality pick)
      'Yuna', 'Google 한국의',
      
      // Portuguese (Luciana for Brazil; Joana for Portugal)
      'Luciana', 'Joana', 'Google português do Brasil',
      
      // Hindi (Lekha is the high-quality choice)
      'Lekha', 'Google हिन्दी'
    ];

      for (var name in bestNames) {
        try {
          return langVoices.firstWhere((v) => v['name'] == name);
        } catch (_) {}
      }

      // 3. FALLBACK: If our favorites aren't there, try keywords
      final keywords = ['neural', 'premium', 'enhanced'];
      for (var key in keywords) {
        try {
          return langVoices.firstWhere((v) => v['name'].toString().toLowerCase().contains(key));
        } catch (_) {}
      }

      // 4. LAST RESORT: Google or the first available
      return langVoices.firstWhere(
        (v) => v['name'].toString().contains('Google'),
        orElse: () => langVoices.first,
      );
    } catch (e) {
      return null;
    }
  }


  // 2. Add this helper for Manual TTS
 Future<void> speak(String text, String lang, LanguageProvider provider) async {
  if (!provider.isSoundOn) return;

  if (text.trim().isEmpty) {
    print("🛡️ TTS Blocked: Prevented iOS crash from empty string!");
    return;
  }

  try {
    // 1. Force fetch voices
    List<dynamic> voices = await _tts.getVoices;

    var bestVoice = _findBestVoice(voices, lang);

    if (bestVoice != null) {
      await _tts.setVoice({"name": bestVoice['name'], "locale": bestVoice['locale']});
    } else {
      await _tts.setLanguage(lang);
    }
    
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
    
  } catch (e) {
    print("❌ TTS Error: $e");
  }
}

  void stop() {
    _timer?.cancel();
    _tts.stop();
  }
}
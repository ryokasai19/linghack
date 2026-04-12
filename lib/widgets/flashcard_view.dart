import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';
import '../providers/language_provider.dart';
import '../services/playback_service.dart';
import '../models/word_pair.dart';

class FlashcardView extends StatefulWidget {
  final GlobalKey<FlipCardState> cardKey;

  FlashcardView({super.key, required this.cardKey});

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> {
  final PlaybackService _playback = PlaybackService();
  bool _isShowingFront = true;
  bool _isProcessing = false;
  bool _isUpdatingStatus = false;


  // FIX 1: Keep a reference to provider to stop it safely when closing
  LanguageProvider? _providerRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<LanguageProvider>();
      await _playback.warmUp(provider.currentLanguage.voiceCode);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _speakCurrentSide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference so we can stop auto-play in dispose()
    _providerRef = Provider.of<LanguageProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // FIX 1: Stop EVERYTHING when the user leaves this screen
    _playback.stop();
    Future.microtask(() {
      _providerRef?.stopAutoPlay();
    });
    super.dispose();
  }

  void _speakCurrentSide() {
    final provider = context.read<LanguageProvider>();
    final word = provider.currentWord;
    if (word == null) return;

    final frontLang = provider.isForeignFront ? provider.currentLanguage.voiceCode : "en-US";
    final backLang = provider.isForeignFront ? "en-US" : provider.currentLanguage.voiceCode;
    final frontText = provider.isForeignFront ? word.foreignText : word.englishText;
    final backText = provider.isForeignFront? word.englishText : word.foreignText;

    if (_isShowingFront) {
      _playback.speak(frontText, frontLang, provider);
    } else {
      _playback.speak(backText, backLang, provider);
    }
  }

  Future<void> _navigate(bool isNext) async {
    if(_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    final provider = context.read<LanguageProvider>();
    _playback.stop();

    final currentState = widget.cardKey.currentState;
    if (currentState != null && !currentState.isFront) {
      currentState.toggleCard();
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _isShowingFront = true);
    }

    if (isNext) provider.nextCard(); else provider.previousCard();

    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
        _speakCurrentSide();
        setState(() {
          _isProcessing = false; 
        });
    }
  }

  void _showAutoSettingsModal(BuildContext context, LanguageProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // StatefulBuilder ensures the slider updates smoothly inside the modal
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Auto-Play Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // 1. SPEED BAR
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.blueGrey),
                      const SizedBox(width: 10),
                      const Text("Delay: 🐆"),
                      Expanded(
                        child: Slider(
                          value: provider.autoPlayDelay,
                          min: 0.5,
                          max: 5.5,
                          divisions: 5,
                          label: "${provider.autoPlayDelay}s",
                          onChanged: (val) {
                            provider.setAutoPlayDelay(val);
                            setModalState(() {}); // Update the slider visually
                          },
                        ),
                      ),
                      const Text("🐢"),
                    ],
                  ),
                  const Divider(),

                  // 2. LOOP TOGGLE
                  SwitchListTile(
                    title: const Text("Loop Playlist"),
                    subtitle: const Text("Restart automatically when finished"),
                    secondary: const Icon(Icons.loop, color: Colors.blue),
                    value: provider.isLooping,
                    onChanged: (val) {
                      provider.toggleLoopMode();
                      setModalState(() {});
                    },
                  ),
                  const Divider(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  
@override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final word = provider.currentWord;

    if (word == null) return const SizedBox.shrink();

    final String frontText = provider.isForeignFront ? word.foreignText : word.englishText;
    final String backText = provider.isForeignFront ? word.englishText : word.foreignText;
    final String frontLang = provider.isForeignFront ? provider.currentLanguage.voiceCode : "en-US";
    final String backLang = provider.isForeignFront ? "en-US" : provider.currentLanguage.voiceCode;
    final Color frontColor = provider.isForeignFront ? Colors.blue.shade100 : Colors.green.shade100;
    final Color backColor = provider.isForeignFront ? Colors.green.shade100 : Colors.blue.shade100;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        // LAYER 1: The Main Content (Card + Bottom Controls)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // COUNTER
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  "Card ${provider.currentIndex + 1} / ${provider.displayWords.length}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),

              // FLASHCARD
              SizedBox(
                width: 300,
                height: 200,
                child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (provider.isAutoPlayEnabled || _isProcessing) return;
                      if (details.primaryVelocity! < -300) {
                        _navigate(true); // Removed the boundary check so it always fires!
                      } else if (details.primaryVelocity! > 300) {
                        if (provider.currentIndex > 0) _navigate(false);
                      }
                    },
                    onTap: () async {
                      if (provider.isAutoPlayEnabled || _isProcessing) return;
                      setState(() => _isProcessing = true);

                      _playback.stop();
                      await Future.delayed(const Duration(milliseconds: 50));
                      
                      if (_isShowingFront) {
                          String lang = provider.isForeignFront ? "en-US" : provider.currentLanguage.voiceCode;
                          _playback.speak(backText, lang, provider);
                      } else {
                          String lang = provider.isForeignFront ? provider.currentLanguage.voiceCode : "en-US";
                          _playback.speak(frontText, lang, provider);
                      }

                      widget.cardKey.currentState?.toggleCard();
                      setState(() => _isShowingFront = !_isShowingFront);
                      
                      await Future.delayed(const Duration(milliseconds:600));
                      if (mounted) setState(() => _isProcessing = false);
                    },
                    child: FlipCard(
                      key: widget.cardKey,
                      flipOnTouch: false,
                      front: _buildCardSide(frontText, frontColor, word),
                      back: _buildCardSide(backText, backColor, word),
                    ),
                ),
              ),

              const SizedBox(height: 30),

              // BOTTOM CONTROLS
              if (provider.isAutoPlayEnabled)
                 Column(
                   children: [
                     const Text("Auto-Play Running...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                     const SizedBox(height: 10),
                     ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.stop),
                        label: const Text("STOP AUTO"),
                        onPressed: () {
                           provider.stopAutoPlay();
                           _playback.stop();
                        },
                     ),
                   ],
                 )
              else
                Column(
                  children: [
                    // 1. Navigation & Play Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 30),
                          onPressed: (_isProcessing || provider.currentIndex <= 0) 
                              ? null 
                              : () => _navigate(false),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green,
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("START AUTO"),
                          onPressed: _isProcessing ? null : () async {
                            setState(() => _isProcessing = true);

                            if (!_isShowingFront) {
                                widget.cardKey.currentState?.toggleCard();
                                setState(() => _isShowingFront = true);
                                await Future.delayed(const Duration(milliseconds: 600));
                            }

                            provider.startAutoPlay(
                                playback: _playback,
                                onFlipToBack: () {
                                    if (_isShowingFront) {
                                        widget.cardKey.currentState?.toggleCard();
                                        _isShowingFront = false; 
                                    }
                                },
                                onResetCard: () {
                                    if (!_isShowingFront) {
                                        widget.cardKey.currentState?.toggleCard();
                                        _isShowingFront = true; 
                                    }
                                },
                            );

                            if (mounted) {
                              await Future.delayed(const Duration(milliseconds: 500));
                              setState(() => _isProcessing = false);
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 30),
                          onPressed: _isProcessing ? null : () => _navigate(true),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 2. Settings Trigger Button
                    TextButton.icon(
                      onPressed: _isProcessing ? null : () => _showAutoSettingsModal(context, provider),
                      icon: const Icon(Icons.tune, color: Colors.blueGrey),
                      label: const Text("Auto-Play Settings", style: TextStyle(color: Colors.blueGrey)),
                    ),
                  ],
                )
            ],
          ),
        ),

        // LAYER 2: Top Left Controls
        if (!provider.isAutoPlayEnabled)
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PLAYLIST TEXT
                if (provider.filterStatus != 'all' && 
                    provider.filterStatus != 'memorized' && 
                    provider.filterStatus != 'not_memorized' && 
                    provider.filterStatus != 'playlists_view')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 12), // Aligns nicely with the buttons below
                    child: Text(
                      "Playlist: ${provider.getPlaylistName(provider.filterStatus)}",
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.blueGrey.shade700
                      ),
                    ),
                  ),

                // 2. ICON CONTROLS
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 30, color: Colors.blueGrey),
                      tooltip: "Switch Language",
                      onPressed: () {
                        if (!_isShowingFront) {
                           widget.cardKey.currentState?.toggleCard();
                           setState(() => _isShowingFront = true);
                        }
                        provider.toggleCardSide();
                        Future.delayed(const Duration(milliseconds: 300), () {
                           if (mounted) _speakCurrentSide();
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        provider.isSoundOn ? Icons.volume_up : Icons.volume_off,
                        size: 28,
                        color: provider.isSoundOn ? Colors.deepPurple : Colors.grey,
                      ),
                      tooltip: "Toggle Sound",
                      onPressed: () => provider.toggleSound(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.shuffle, size: 28, color: Colors.blueGrey),
                      tooltip: "Shuffle Order",
                      onPressed: _isProcessing ? null : () async {
                        setState(() => _isProcessing = true);
                        provider.shuffleList();
                        await Future.delayed(const Duration(milliseconds: 400));
                        if (mounted) setState(() => _isProcessing = false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCardSide(String text, Color color, WordPair? word) {
  return Card(
    elevation: 4,
    color: color,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Stack( // Stack is now INSIDE the card
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // The Bookmark Tag
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () async {
              // Prevent double-taps and crashes while updating
              if (word == null || _isUpdatingStatus) return; 

              final provider = context.read<LanguageProvider>();

              // --- 1. AUTO-PLAY MODE ---
              if (provider.isAutoPlayEnabled) {
                // Queue the word to be deleted from the database LATER by the auto-play loop
                provider.queueWordStatusUpdate(word); 
                return; 
              }

              // --- 2. MANUAL MODE ---
              setState(() => _isUpdatingStatus = true); // Lock the button

              bool willVanish = (provider.filterStatus == 'memorized' && word.isRemembered) ||
                                (provider.filterStatus == 'not_memorized' && !word.isRemembered);

              if (willVanish) {
                // If it's on the back, flip it to the front so the NEXT card starts fresh
                if (!_isShowingFront) {
                  widget.cardKey.currentState?.toggleCard();
                  setState(() => _isShowingFront = true);
                  // Wait 400ms strictly for the visual flip animation to complete
                  await Future.delayed(const Duration(milliseconds: 400));
                }
                
                // Wait for the TTS to finish speaking before removing the card
                // (Note: Adjust this line to match whatever method your PlaybackService uses)
                while (_playback.isSpeaking) {
                  await Future.delayed(const Duration(milliseconds: 100));
                }
              }

              // Update the database (this removes the word and slides the next one in)
              await provider.toggleRemembered(word);

              if (mounted) {
                setState(() => _isUpdatingStatus = false); // Unlock the button
              }
              },
              child: Builder(
                builder: (context) {
                  final provider = context.watch<LanguageProvider>();
                  
                  bool isRememberedUI = word?.isRemembered == true;
                  
                  // If it's queued, flip the visual state instantly!
                  if (provider.queuedWord == word) {
                    isRememberedUI = !isRememberedUI; 
                  }

                  return Icon(
                    isRememberedUI ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.amber,
                    size: 30,
                  );
                }
              ),
          ),
        ),
      ],
    ),
  );
}
}
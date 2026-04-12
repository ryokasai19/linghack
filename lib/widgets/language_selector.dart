import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../constants/languages.dart';
import '../models/target_language.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  void _showVoiceHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Voice Sound Robotic?"),
        content: const Text(
          "For the best experience, enable 'Enhanced' voices in your phone settings:\n\n"
          "iOS: Settings > Accessibility > Spoken Content > Voices\n\n"
          "Android: Settings > Accessibility > Text-to-speech output"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))
        ],
      ),
    );
  }

  void _handleLanguageTap(BuildContext context, LanguageProvider provider, TargetLanguage lang) {
    bool isLocked = provider.isLanguageLocked(lang.code);

    if (isLocked) {
      // PURCHASE FLOW (Placeholder)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Unlock ${lang.name}?"),
          content: Text("Purchase ${lang.name} to start scanning and learning."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                // TODO: Connect this to Stripe/IAP later
                provider.unlockLanguage(lang.code); // Unlocks instantly for testing now
                Navigator.pop(context);
              },
              child: const Text("Buy for \$4.99"),
            )
          ],
        ),
      );
    } else {
      // SWITCH FLOW
      provider.setLanguage(lang);
      Navigator.pop(context); // Close the selector
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Select Language", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.blue),
                  onPressed: () => _showVoiceHelp(context),
                  tooltip: "Voice Settings Help",
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: () {
                // 1. Create a copy of the list so we can sort it
                var sortedList = List<TargetLanguage>.from(AppLanguages.availableLanguages);
                
                // 2. Sort: Owned languages first, then alphabetical
                sortedList.sort((a, b) {
                  bool aOwned = !provider.isLanguageLocked(a.code);
                  bool bOwned = !provider.isLanguageLocked(b.code);
                  
                  if (aOwned && !bOwned) return -1; // a comes first
                  if (!aOwned && bOwned) return 1;  // b comes first
                  return a.name.compareTo(b.name);  // Otherwise alphabetical
                });

                // 3. Map to Widgets
                return sortedList.map((lang) {
                  final isSelected = provider.currentLanguage.code == lang.code;
                  final isLocked = provider.isLanguageLocked(lang.code);

                  return ListTile(
                    title: Text(lang.name, style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue : Colors.black
                    )),
                    trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : isLocked 
                            ? const Icon(Icons.lock, color: Colors.grey)
                            : null,
                    onTap: () => _handleLanguageTap(context, provider, lang),
                  );
                }).toList();
              }(),
            ),
          ),
        ],
      ),
    );
  }
}
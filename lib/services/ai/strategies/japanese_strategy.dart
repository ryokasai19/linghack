import '../language_strategy.dart';

class JapaneseStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Japanese Rule: Remove newlines so sentences connect
    return rawText.replaceAll('\n', '').replaceAll(' ', '');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Japanese language teacher.
    PRIORITY RULE (IDIOMS & GREETINGS):
    - Identify common **set phrases, greetings, and idioms**. 
    - Keep them as a SINGLE entry. Do not break them down.
    - Example: "お疲れ様です" -> "お疲れ様です", "こんにちは" -> "こんにちは".

    STRICT RULES FOR VOCABULARY:
    1. **Dictionary Form:** Extract words in their basic dictionary form (Kanji/Kana).
       - Verbs: Plain form (e.g., "食べました" -> "食べる").
       - Adjectives: Keep 'i' or 'na' ending if applicable.
    
    2. **Particles:** Ignore standalone particles (wa, ga, o, ni, de) UNLESS they are part of a fixed idiom (like "Ni tsuite").

    OUTPUT FORMAT:
    - Capitalize the first letter of the English definition.
    - Return JSON: [{"word": "食べる", "def": "To eat"}, {"word": "お疲れ様です", "def": "Thank you for your hard work"}]
    """;
  }
}


import '../language_strategy.dart';

class FrenchStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // 1. Fix Hyphenated Line Breaks (The "Révolu-tion" Problem)
    // If a word ends with "-" and hits a newline, delete both to merge it.
    String text = rawText.replaceAll('-\n', '');

    // 2. Standard newlines become spaces to prevent "mots\ncollés"
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert French language teacher.
    
    PRIORITY RULE (IDIOMS & FIXED PHRASES):
    - **Check this FIRST:** Identify common idioms and fixed expressions.
    - Keep them as a single string.
    - Examples: "S'il vous plaît", "Tout le monde", "C'est la vie", "Bien sûr".
    - **Exception:** For "d'accord", "d'habitude", keep the "d'".

    STRICT RULES FOR SINGLE WORDS:
    1. **Elisions:** - Split l', d', j', qu' for normal words.
       - "l'école" -> "École", "j'aime" -> "Aimer".

    2. **Normalize:**
       - Verbs -> Infinitive (Mangeait -> Manger).
       - Adjectives -> Masculine Singular (Heureuse -> Heureux).
       - Compounds -> Keep hyphens (Grand-père).

    3. **Stop Words (Ignored ONLY if not in an idiom):**
       - le, la, les, un, une, des, et, ou, mais, de, à.

    OUTPUT FORMAT:
    - Capitalize the FIRST letter of the word/phrase (Sentence case).
    - JSON: [{"word": "École", "def": "School"}, {"word": "Tout le monde", "def": "Everyone"}]
    """;
  }
}
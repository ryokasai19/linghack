import '../language_strategy.dart';

class ItalianStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    String text = rawText.replaceAll('-\n', '');
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Italian language teacher.
    
    PRIORITY RULE (IDIOMS):
    - Identify idioms FIRST (e.g., "Mamma mia", "Per favore", "In bocca al lupo").
    - Keep them as single entries.

    STRICT RULES FOR VOCABULARY:
    1. **Elisions (L', Dell', Un'):**
       - Split apostrophes. Extract the main word.
       - Example: "l'amico" -> "Amico", "dell'albero" -> "Albero".

    2. **Enclitics (Attached Pronouns):**
       - Separate pronouns attached to the end of verbs.
       - Example: "Dimmi" -> "Dire", "Guardalo" -> "Guardare", "Vattene" -> "Andarsene".

    3. **Stemming:**
       - Nouns/Adj -> Masculine Singular (e.g., "Rosse" -> "Rosso", "Case" -> "Casa").
       - Verbs -> Infinitive.

    4. **Stop Words:** - Ignore: il, lo, la, i, gli, le, un, uno, una, di, a, da, in, con, su, per, tra, fra.

    OUTPUT FORMAT:
    - Capitalize First letter.
    - JSON: [{"word": "Dire", "def": "To say"}, {"word": "Amico", "def": "Friend"}]
    """;
  }
}
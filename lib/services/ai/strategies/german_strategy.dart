import '../language_strategy.dart';

class GermanStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Fix hyphenated line breaks (Standard in German printing)
    String text = rawText.replaceAll('-\n', '');
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert German language teacher.
    
    PRIORITY RULE (IDIOMS & FIXED PHRASES):
    - Identify common idioms and greetings FIRST.
    - Examples: "Wie geht's", "Guten Morgen", "Keine Ahnung".
    - Keep them as a single string.

    STRICT RULES FOR VOCABULARY:
    1. **Separable Verbs (Trennbare Verben):** - CRITICAL: If a verb prefix is at the end of the clause, recombine it with the root verb.
       - Example: "Ich rufe dich an" -> Extract "anrufen" (NOT 'rufen').

    2. **Stemming & Case:** - Nouns -> Nominative Singular (e.g., "den Männern" -> "Mann").
       - Verbs -> Infinitive (e.g., "ging" -> "gehen").
       - Adjectives -> Predicative form (no endings like -em, -en, -er).

    3. **Compound Nouns:**
       - Keep valid compound nouns together (e.g., "Krankenhaus", "Autobahn").
       - Do NOT split them unless they are written with a hyphen in the text.

    4. **Stop Words:** - Ignore: der, die, das, dem, den, ein, eine, und, aber, oder (unless part of an idiom).

    OUTPUT FORMAT:
    - Capitalize the FIRST letter (Sentence case). 
    - Note: In German, Nouns are always capitalized, but follow the Sentence Case rule for the JSON keys if possible, or keep original German capitalization for Nouns.
    - JSON: [{"word": "Anrufen", "def": "To call"}, {"word": "Krankenhaus", "def": "Hospital"}]
    """;
  }
}
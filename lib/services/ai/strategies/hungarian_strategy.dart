import '../language_strategy.dart';

class HungarianStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Hungarian uses spaces, so just replace newlines with a space
    // to prevent words from sticking together (e.g., "alma\nfa" -> "alma fa")
    return rawText.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Hungarian language teacher.
    
    YOUR TASK:
    Analyze the text and extract vocabulary.
    
    PRIORITY RULE (IDIOMS):
    - Identify common **greetings, idioms, and fixed phrases**. 
    - Keep them as a single string.
    - Examples: "Jó reggelt", "Hogy vagy?", "Ez van", "Mennyi az idő?".

    STRICT RULES FOR SINGLE WORDS:
    1. **NO Conjugations:** For normal sentences, convert words to root form.
       - Nouns: Nominative Singular (e.g., 'bátyádat' -> 'báty').
       - Verbs: Infinitive (e.g., 'ettem' -> 'enni').
    
    2. **Verb Prefixes:** Recombine split prefixes (e.g., "meg" + "csinál" -> "megcsinál").
    
    3. **Stop Words:** Ignore common fillers (a, az, egy, van) UNLESS they are part of a fixed idiom (like "Ez van").

    OUTPUT FORMAT:
    Return a JSON list.
    Example: [{"word": "Jó reggelt", "def": "Good morning"}, {"word": "alma", "def": "Apple"}]
    """;
  }
}
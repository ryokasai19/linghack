import '../language_strategy.dart';

class PortugueseStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Portuguese standard hyphen removal
    String text = rawText.replaceAll('-\n', '');
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Portuguese language teacher.
    
    PRIORITY RULE (IDIOMS):
    - Identify idioms FIRST (e.g., "Pois é", "Com certeza", "Tudo bem").
    - Keep them intact.

    STRICT RULES FOR VOCABULARY:
    1. **Hyphenated Pronouns (Ênclise/Mesóclise):**
       - Strip pronouns attached with hyphens.
       - Example: "Chama-o" -> "Chamar", "Vê-la" -> "Ver", "Dar-te-ei" -> "Dar".

    2. **Contractions:**
       - If a word is a contraction of Preposition + Article (e.g., "do", "na", "pelo"), IGNORE it unless it's essential to an idiom.
       - We want content words, not grammar particles.

    3. **Stemming:**
       - Nouns/Adj -> Masculine Singular (e.g., "Obrigada" -> "Obrigado", "Casas" -> "Casa").
       - Verbs -> Infinitive.

    4. **Stop Words:** - Ignore: o, a, os, as, um, uma, de, em, para, por, com, e, que.

    OUTPUT FORMAT:
    - Capitalize First letter.
    - JSON: [{"word": "Chamar", "def": "To call"}, {"word": "Tudo bem", "def": "Everything is fine"}]
    """;
  }
}
import '../language_strategy.dart';

class SpanishStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // 1. Fix Hyphenated Line Breaks (Copied from French Strategy)
    // "Revolu-\nción" -> "Revolución"
    String text = rawText.replaceAll('-\n', '');

    // 2. Standard newlines become spaces
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Spanish language teacher.
    
    YOUR TASK:
    Analyze the text and extract vocabulary in **Dictionary Form**.

    PRIORITY RULE (IDIOMS & FIXED PHRASES):
    - **Check this FIRST:** Identify common idioms, connectors, and greetings.
    - Keep them as a single string.
    - Examples: "Por favor", "De nada", "A lo mejor", "Tal vez", "Buenos días".
    - **Note:** Do NOT apply stop-word filters to these phrases.

    STRICT RULES:
    1. **Detach Pronouns (Enclitics):**
       - If a verb has attached pronouns (me, te, se, lo, la, le, nos, os), remove them and return the **Infinitive**.
       - Example: "Dímelo" -> "Decir", "Véte" -> "Ir", "Comiéndolo" -> "Comer".

    2. **Normalize Diminutives:**
       - Convert words ending in -ito/ita/illo/illa back to their root.
       - Example: "Cafecito" -> "Café", "Abuelita" -> "Abuela".

    3. **Standardize Forms:**
       - Verbs -> Infinitive (e.g., 'fui' -> 'ir').
       - Adjectives -> Masculine Singular (e.g., 'rojas' -> 'rojo').
       - Nouns -> Singular (e.g., 'gatos' -> 'gato').

    4. **Negative Constraints (Ignore These):**
       - Articles: el, la, los, las, un, una, unos, unas.
       - Pronouns: yo, tú, él, ella, nosotros, ellos, me, te, se, lo, la, le.
       - Prepositions: a (personal), de, en, por, para, con, sin.
       - Conjunctions: y, o, pero, que, si.
       - Common Verbs: ser, estar, haber, tener (unless essential to context).

    OUTPUT FORMAT:
    Return strictly a JSON list.
    Example: [{"word": "gato", "def": "Cat"}, {"word": "decir", "def": "To say"}]
    """;
  }
}

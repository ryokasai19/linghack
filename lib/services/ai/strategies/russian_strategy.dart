import '../language_strategy.dart';

class RussianStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Fix hyphenated line breaks (common in Russian books)
    String text = rawText.replaceAll('-\n', '');
    return text.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Russian language teacher.
    
    PRIORITY RULE (IDIOMS):
    - Identify fixed expressions FIRST.
    - Examples: "Как дела", "Доброе утро", "Всё равно".
    - Keep them intact.

    STRICT RULES FOR VOCABULARY:
    1. **Noun Declension (Cases):**
       - Convert all nouns to **Nominative Singular** (Dictionary Form).
       - Example: "книгу" (Accusative) -> "книга" (Book), "домом" (Instrumental) -> "дом" (House).

    2. **Verb Conjugation:**
       - Convert to **Infinitive** (usually ending in -ть).
       - Example: "читаю" -> "читать", "пошел" -> "пойти".

    3. **Stop Words:**
       - Ignore: и, а, но, в, на, с, по, к, у, о, за, что, это (unless "это" is the main subject).

    OUTPUT FORMAT:
    - Capitalize First letter (Sentence case).
    - JSON: [{"word": "Дом", "def": "House"}, {"word": "Читать", "def": "To read"}]
    """;
  }
}
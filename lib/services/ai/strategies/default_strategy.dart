import '../language_strategy.dart';

class DefaultStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Default behavior: Just trim whitespace, don't remove newlines (safe for English/European)
    return rawText.trim();
  }

  @override
  String getSystemPrompt() {
    return """
    - Extract vocabulary words from the text.
    - If the word is conjugated, return the infinitive/dictionary form.
    - OUTPUT FORMAT: Return a JSON list: [{"word": "example", "def": "definition"}]
    """;
  }
}
abstract class LanguageStrategy {
  // 1. Every language must know how to clean its specific OCR mess
  String cleanOcrText(String rawText);

  // 2. Every language defines its own System Prompt for the AI
  String getSystemPrompt();
}
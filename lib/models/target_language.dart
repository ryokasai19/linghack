class TargetLanguage {
  final String name;       // e.g., "Hungarian"
  final String code;       // e.g., "hu" (for translation API)
  final String voiceCode;  // e.g., "hu-HU" (for Text-to-Speech)

  const TargetLanguage({
    required this.name,
    required this.code,
    required this.voiceCode,
  });
}
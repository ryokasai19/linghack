import '../models/target_language.dart';

class AppLanguages {
  static const List<TargetLanguage> availableLanguages = [
    // --- THE "BIG 6" (Most Popular) ---
    TargetLanguage(name: 'Hungarian', code: 'hu', voiceCode: 'hu-HU'),
    TargetLanguage(name: 'Spanish', code: 'es', voiceCode: 'es-ES'),
    TargetLanguage(name: 'French', code: 'fr', voiceCode: 'fr-FR'),
    TargetLanguage(name: 'German', code: 'de', voiceCode: 'de-DE'),
    TargetLanguage(name: 'Italian', code: 'it', voiceCode: 'it-IT'),
    TargetLanguage(name: 'Portuguese', code: 'pt', voiceCode: 'pt-BR'),

    // --- ASIAN GIANTS (High Demand) ---
    // Note: Chinese (Simplified) is the standard for learners
    TargetLanguage(name: 'Chinese', code: 'zh', voiceCode: 'zh-CN'), 
    TargetLanguage(name: 'Cantonese', code: 'yue', voiceCode: 'zh-HK'),
    TargetLanguage(name: 'Japanese', code: 'ja', voiceCode: 'ja-JP'),
    TargetLanguage(name: 'Korean', code: 'ko', voiceCode: 'ko-KR'),
    TargetLanguage(name: 'Hindi', code: 'hi', voiceCode: 'hi-IN'),
    TargetLanguage(name: 'Thai', code: 'th', voiceCode: 'th-TH'),
    TargetLanguage(name: 'Indonesian', code: 'id', voiceCode: 'id-ID'),

    // --- CENTRAL & EASTERN EUROPE (Your Niche) ---
    TargetLanguage(name: 'Russian', code: 'ru', voiceCode: 'ru-RU'),
    TargetLanguage(name: 'Czech', code: 'cs', voiceCode: 'cs-CZ'),
    TargetLanguage(name: 'Polish', code: 'pl', voiceCode: 'pl-PL'),
    TargetLanguage(name: 'Romanian', code: 'ro', voiceCode: 'ro-RO'),
    TargetLanguage(name: 'Slovak', code: 'sk', voiceCode: 'sk-SK'),
    TargetLanguage(name: 'Croatian', code: 'hr', voiceCode: 'hr-HR'),
    TargetLanguage(name: 'Greek', code: 'el', voiceCode: 'el-GR'),
    TargetLanguage(name: 'Turkish', code: 'tr', voiceCode: 'tr-TR'),

    // --- NORTHERN EUROPE (Wealthy Markets) ---
    TargetLanguage(name: 'Dutch', code: 'nl', voiceCode: 'nl-NL'),
    TargetLanguage(name: 'Swedish', code: 'sv', voiceCode: 'sv-SE'),
    TargetLanguage(name: 'Danish', code: 'da', voiceCode: 'da-DK'),
    TargetLanguage(name: 'Finnish', code: 'fi', voiceCode: 'fi-FI'),
    TargetLanguage(name: 'Norwegian', code: 'no', voiceCode: 'no-NO'),
  ];

  // Helper to get a language by code
  static TargetLanguage getByCode(String code) {
    return availableLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => availableLanguages[0], // Default to Hungarian
    );
  }
}
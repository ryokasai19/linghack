import 'language_strategy.dart';
import 'strategies/japanese_strategy.dart';
import 'strategies/hungarian_strategy.dart';
import 'strategies/default_strategy.dart';
import 'strategies/french_strategy.dart';
import 'strategies/spanish_strategy.dart';
import 'strategies/chinese_strategy.dart';
import 'strategies/german_strategy.dart';
import 'strategies/italian_strategy.dart';
import 'strategies/portuguese_strategy.dart';
import 'strategies/korean_strategy.dart';
import 'strategies/russian_strategy.dart';
import 'strategies/hindi_strategy.dart';

class LanguageFactory {
  static LanguageStrategy getStrategy(String languageCode) {
    switch (languageCode) {
      case 'ja': return JapaneseStrategy();
      case 'hu': return HungarianStrategy();
      case 'fr': return FrenchStrategy();
      case 'es': return SpanishStrategy();
      case 'zh': return ChineseStrategy();

      // STRATEGIES UNCONFIRMED!!
      case 'de': return GermanStrategy();
      case 'it': return ItalianStrategy();
      case 'pt': return PortugueseStrategy();
      case 'ko': return KoreanStrategy();
      case 'ru': return RussianStrategy();
      case 'hi': return HindiStrategy();
      default:
        return DefaultStrategy();
    }
  } 
}
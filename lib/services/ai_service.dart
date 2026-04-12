import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/word_pair.dart';

class AiService {
  final GenerativeModel _model;

  AiService(String apiKey) 
      : _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

  Future<List<WordPair>> extractWords({required String text, required String prompt}) async {
    // 1. The "Universal" Instructions (Applies to ALL languages)
    const String universalRules = """
    You are a helpful language teacher. 
    Analyze the text provided and extract vocabulary.
    
    UNIVERSAL RULES:
    - Do NOT include numbers, dates, or time (e.g. 2024, 10am).
    - Do NOT include names of people or places unless they are useful common nouns.
    - Do NOT include short "garbage" text (symbols, random letters).
    - Ignore grammatical stop words (particles, articles, prepositions) unless they are key to the meaning.
    - Capitalize the FIRST letter of the entry (Sentence Case). Example: "apple" -> "Apple", "jó reggelt" -> "Jó reggelt".
    - Provide the English translation for every word.
    """;

    // 2. The Final Prompt (Universal + Language Specific)
    final content = [
      Content.text("$universalRules\n\nLANGUAGE SPECIFIC RULES:\n$prompt\n\nINPUT TEXT:\n$text")
    ];

    try {
      final response = await _model.generateContent(content);
      String? jsonString = response.text;

      // 3. Clean the response (Remove Markdown ```json ... ``` if present)
      if (jsonString != null) {
        jsonString = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // 4. Parse JSON
        List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((item) => WordPair(
          foreignText: item['word'], 
          englishText: item['def']
        )).toList();
      }
      return [];
    } catch (e) {
      print("AI Extraction Error: $e");
      return [];
    }
  }
}
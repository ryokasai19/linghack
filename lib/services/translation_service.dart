import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslationService {
  static String get _apiKey =>
      (dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '').trim();

  // 1. Translate Text
  Future<String> translate(String text, String targetLang) async {
    final url = 'https://translation.googleapis.com/language/translate/v2?key=$_apiKey';
    
    final response = await http.post(
      Uri.parse(url),
      body: {
        'q': text,
        'target': targetLang,
        'format': 'text',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data']['translations'][0]['translatedText'];
    } else {
      return "Error";
    }
  }

  // 2. Detect Language (For filtering)
  Future<String?> detectLanguage(String text) async {
    final url = 'https://translation.googleapis.com/language/translate/v2/detect?key=$_apiKey';
    
    final response = await http.post(
      Uri.parse(url),
      body: {'q': text},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Returns language code (e.g., 'en', 'hu')
      return json['data']['detections'][0][0]['language'];
    }
    return null;
  }
}
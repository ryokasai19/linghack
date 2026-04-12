import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class OcrService {
  static String get _apiKey =>
      (dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '').trim();

  Future<List<String>> getTextFromImage(XFile file, String languageCode) async {
    if (_apiKey.isEmpty) {
      print('OCR: set GOOGLE_VISION_API_KEY in .env');
      return [];
    }

    // 1. Convert image to Base64
    final bytes = await file.readAsBytes();
    final String base64Image = base64Encode(bytes);

    // 2. Prepare the Request
    final String url = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';
    
    final body = {
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "TEXT_DETECTION"}
          ],
          // ADD THIS SECTION:
          "imageContext": {
            "languageHints": [languageCode] // Forces Google to look for Hungarian
          }
        }
      ]
    };

    // 3. Send to Google
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    // 4. Parse Response
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      
      // Google returns a lot of data. We just want the first full text block.
      try {
        final String fullText = json['responses'][0]['fullTextAnnotation']['text'];
        
        // Split by lines so we get a list of words/phrases
        return fullText.split('\n').where((s) => s.isNotEmpty).toList();
      } catch (e) {
        return []; // No text found
      }
    } else {
      print("Error: ${response.body}");
      return [];
    }
  }
}
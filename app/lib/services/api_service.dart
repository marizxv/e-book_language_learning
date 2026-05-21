import 'dart:convert';
import 'package:http/http.dart' as http;

// Use 10.0.2.2 on Android emulator, localhost on iOS simulator / real device
const _baseUrl = 'http://localhost:8000';

class ApiService {
  static Future<Map<String, dynamic>> translateWord({
    required String word,
    required String context,
    String sourceLang = 'en',
    String targetLang = 'pl',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/translate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'word': word,
        'context': context,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      }),
    );
    if (res.statusCode != 200) throw Exception('Translation failed');
    return jsonDecode(res.body);
  }

  static Future<void> saveWord({
    required String word,
    required String translation,
    required String context,
    required String cefrLevel,
    String sourceLang = 'en',
    String targetLang = 'pl',
  }) async {
    await http.post(
      Uri.parse('$_baseUrl/vocabulary'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'word': word,
        'translation': translation,
        'context': context,
        'cefr_level': cefrLevel,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      }),
    );
  }

  static Future<List<Map<String, dynamic>>> getVocabulary() async {
    final res = await http.get(Uri.parse('$_baseUrl/vocabulary'));
    if (res.statusCode != 200) throw Exception('Failed to load vocabulary');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<List<Map<String, dynamic>>> getFlashcards() async {
    final res = await http.get(Uri.parse('$_baseUrl/flashcards'));
    if (res.statusCode != 200) throw Exception('Failed to load flashcards');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<void> reviewFlashcard(int id, {required bool known}) async {
    await http.patch(
      Uri.parse('$_baseUrl/flashcards/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'known': known}),
    );
  }

  static Future<Map<String, dynamic>> analyzeLevel(List<String> words) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/analyze-level'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'words': words, 'lang': 'en'}),
    );
    if (res.statusCode != 200) throw Exception('Analysis failed');
    return jsonDecode(res.body);
  }
}

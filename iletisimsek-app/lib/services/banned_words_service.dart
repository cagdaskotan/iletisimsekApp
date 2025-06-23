import 'dart:convert';
import 'package:http/http.dart' as http;

class BannedWordService {
  static const String baseUrl = 'http://10.20.10.30:3002/api/bannedwords';

  static Future<List<String>> fetchBannedWords() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> words = jsonData['bannedWords'];
        return words.map((e) => e.toString().toLowerCase()).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}

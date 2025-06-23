import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

class MessageService {
  static String baseUrl = 'http://10.20.10.30:3002/api/messages';

  static Future<List<MessageModel>> getMessages(
    String user1,
    String user2,
  ) async {
    final res = await http.get(Uri.parse('$baseUrl/$user1/$user2'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MessageModel.fromJson(e)).toList();
    } else {
      throw Exception('Mesajlar yüklenemedi');
    }
  }

  static Future<void> sendMessage(
    String from,
    String to,
    String content,
  ) async {
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': to,
        'content': content,
        'type': 'text',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Metin mesajı gönderilemedi');
    }
  }

  static Future<Map<String, dynamic>> sendMedia({
    required String from,
    required String to,
    required File file,
    required String type, // 'image' veya 'file'
  }) async {
    final uri = Uri.parse('$baseUrl/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['senderId'] = from
      ..fields['receiverId'] = to
      ..fields['type'] = type
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // 🔁 chat.dart için gerekli
    } else {
      throw Exception('Dosya gönderilemedi: ${response.statusCode}');
    }
  }

  static Future<void> markAsRead(String from, String to) async {
    final uri = Uri.parse('$baseUrl/mark-as-read');

    final res = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'from': from, 'to': to}),
    );

    if (res.statusCode != 200) {
      throw Exception('Mesaj okunmuş olarak işaretlenemedi');
    }
  }
}

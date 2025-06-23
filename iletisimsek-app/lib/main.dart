import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/socket_service.dart';
import 'pages/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');

  if (token != null) {
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final payloadMap = json.decode(decoded);

      final userId =
          payloadMap['id'] ?? payloadMap['_id'] ?? payloadMap['userId'];

      if (userId != null && userId is String) {
        SocketService().connect(userId);
      } else {
        print('❗ Kullanıcı ID bulunamadı (token içinde)');
      }
    }
  }

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

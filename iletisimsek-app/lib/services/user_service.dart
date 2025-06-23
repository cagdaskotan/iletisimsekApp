import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class UserService {
  static const String baseUrl = 'http://10.20.10.30:3002/api/users';

  static Future<List<UserModel>> getUsers() async {
    final res = await http.get(Uri.parse(baseUrl));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => UserModel.fromJson(e)).toList();
    } else {
      throw Exception('Kullanıcılar yüklenemedi');
    }
  }
}

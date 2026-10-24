
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://10.150.101.58:3000/api/auth';
  static const String _tokenKey = 'scamsathi_auth_token';

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _authenticate('/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _authenticate('/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> _authenticate(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response from server.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ?? 'Authentication failed.',
      );
    }

    final token = decoded['token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Login token was not received.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    return decoded;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

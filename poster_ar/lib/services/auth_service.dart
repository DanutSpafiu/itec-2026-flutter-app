import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/auth_user.dart';

class AuthResult {
  final String token;
  final AuthUser user;

  const AuthResult({required this.token, required this.user});
}

class AuthService {
  static String get _apiBaseUrl {
    final envDot = dotenv.env['API_BASE_URL'];
    if (envDot != null && envDot.isNotEmpty) return envDot;

    const envDefine = String.fromEnvironment('API_BASE_URL');
    if (envDefine.isNotEmpty) return envDefine;

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:3000';
      } catch (_) {
        // Fallback handled below.
      }
    }

    return 'http://localhost:3000';
  }

  Uri _uri(String path) => Uri.parse('$_apiBaseUrl$path');

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    return _parseAuthResponse(response);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    return _parseAuthResponse(response);
  }

  AuthResult _parseAuthResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = body['error'] as String? ?? 'Authentication failed.';
      throw Exception(errorMessage);
    }

    final token = body['token'] as String?;
    final userJson = body['user'] as Map<String, dynamic>?;

    if (token == null || userJson == null) {
      throw Exception('Invalid auth response from server.');
    }

    return AuthResult(token: token, user: AuthUser.fromJson(userJson));
  }
}

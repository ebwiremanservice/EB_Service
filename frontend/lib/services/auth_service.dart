library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'eb_auth_token';
  static const String _emailKey = 'eb_user_email';
  static const String _nameKey = 'eb_user_name';
  static const String _countKey = 'eb_houses_count';
  static const String _subStatusKey = 'eb_sub_status';

  static String? _cachedToken;
  static String? _cachedEmail;
  static String? _cachedName;

  // Initialize cached token from SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedEmail = prefs.getString(_emailKey);
    _cachedName = prefs.getString(_nameKey);
  }

  static bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  static String? get token => _cachedToken;
  static String get userEmail => _cachedEmail ?? '';
  static String get userName => _cachedName ?? 'Wireman';

  // ─────────────────────────────────────────────────────────────────────────
  // Send OTP code to email
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> sendOtp(String email, {String? name}) async {
    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return body['otp'] as String?;
      }

      throw ApiException(
        body['message'] as String? ?? 'Failed to send verification code.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeoutexception') || msg.contains('timed out')) {
        throw const ApiException('Server is waking up from sleep. Please tap "Send Verification Code" again.');
      }
      throw ApiException('Network error while requesting code: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verify OTP and persist session
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.trim(),
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['token'] as String;
        final user = body['user'] as Map<String, dynamic>;

        _cachedToken = token;
        _cachedEmail = user['email'] as String? ?? email;
        _cachedName = user['name'] as String? ?? 'Wireman';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_emailKey, _cachedEmail!);
        await prefs.setString(_nameKey, _cachedName!);
        await prefs.setInt(_countKey, (user['registeredHousesCount'] as num?)?.toInt() ?? 0);
        await prefs.setString(_subStatusKey, (user['subscription']?['status'] as String?) ?? 'free');

        return user;
      }

      throw ApiException(
        body['message'] as String? ?? 'Verification failed.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeoutexception') || msg.contains('timed out')) {
        throw const ApiException('Verification timed out. Please check your internet connection and try again.');
      }
      throw ApiException('Network error during verification: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch fresh profile from server
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchProfile() async {
    if (!isAuthenticated) throw const ApiException('Not authenticated.');

    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cachedToken',
            },
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final user = body['user'] as Map<String, dynamic>;
        _cachedEmail = user['email'] as String? ?? _cachedEmail;
        _cachedName = user['name'] as String? ?? _cachedName;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_countKey, (user['registeredHousesCount'] as num?)?.toInt() ?? 0);
        await prefs.setString(_subStatusKey, (user['subscription']?['status'] as String?) ?? 'free');

        return user;
      }

      if (response.statusCode == 401) {
        await logout();
      }

      throw ApiException(
        body['message'] as String? ?? 'Failed to load profile.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to load profile: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout & Clear Session
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    _cachedToken = null;
    _cachedEmail = null;
    _cachedName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_countKey);
    await prefs.remove(_subStatusKey);
  }
}


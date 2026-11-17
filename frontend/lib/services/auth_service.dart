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
  static const String _subPlanKey = 'eb_sub_plan';
  static const String _subEndKey = 'eb_sub_end';

  static String? _cachedToken;
  static String? _cachedEmail;
  static String? _cachedName;
  static String? _cachedPlan;
  static String? _cachedEnd;
  static int _cachedCount = 0;

  // Initialize cached token from SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedEmail = prefs.getString(_emailKey);
    _cachedName = prefs.getString(_nameKey);
    _cachedPlan = prefs.getString(_subPlanKey);
    _cachedEnd = prefs.getString(_subEndKey);
    _cachedCount = prefs.getInt(_countKey) ?? 0;
  }

  static bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  static String? get token => _cachedToken;
  static String get userEmail => _cachedEmail ?? '';
  static String get userName => _cachedName ?? 'Wireman';
  static String get subscriptionPlan => _cachedPlan ?? 'free_10';
  static String get subscriptionEnd => _cachedEnd ?? '';
  static int get housesCount => _cachedCount;
  static bool get isLifetime =>
      _cachedPlan == 'lifetime' || _cachedEmail == 'mathavan479@gmail.com';

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
        _cachedCount = (user['registeredHousesCount'] as num?)?.toInt() ?? 0;
        final sub = user['subscription'] as Map<String, dynamic>?;
        _cachedPlan = sub?['plan'] as String? ?? 'free_10';
        _cachedEnd = sub?['endDate'] as String? ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_emailKey, _cachedEmail!);
        await prefs.setString(_nameKey, _cachedName!);
        await prefs.setInt(_countKey, _cachedCount);
        await prefs.setString(_subStatusKey, (sub?['status'] as String?) ?? 'free');
        await prefs.setString(_subPlanKey, _cachedPlan!);
        await prefs.setString(_subEndKey, _cachedEnd!);

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
        _cachedCount = (user['registeredHousesCount'] as num?)?.toInt() ?? _cachedCount;
        final sub = user['subscription'] as Map<String, dynamic>?;
        _cachedPlan = sub?['plan'] as String? ?? _cachedPlan;
        _cachedEnd = sub?['endDate'] as String? ?? _cachedEnd;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_countKey, _cachedCount);
        await prefs.setString(_subStatusKey, (sub?['status'] as String?) ?? 'free');
        if (_cachedPlan != null) await prefs.setString(_subPlanKey, _cachedPlan!);
        if (_cachedEnd != null) await prefs.setString(_subEndKey, _cachedEnd!);

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
  // Update Profile Name
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> updateProfile(String newName) async {
    if (!isAuthenticated) throw const ApiException('Not authenticated.');
    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cachedToken',
            },
            body: jsonEncode({'name': newName.trim()}),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        _cachedName = newName.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_nameKey, _cachedName!);
        return;
      }
      throw ApiException(body['message'] as String? ?? 'Failed to update name.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error updating name: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete Account Permanently (Google Play Policy)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> deleteAccount(String email) async {
    if (!isAuthenticated) throw const ApiException('Not authenticated.');
    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/auth/delete-account'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cachedToken',
            },
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        await logout();
        return;
      }
      throw ApiException(body['message'] as String? ?? 'Failed to delete account.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error deleting account: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Verify & Activate Purchase (Google Play Billing or Direct Payment)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyPurchase({
    String? paymentId,
    String? purchaseToken,
    String? productId,
    int amount = 699,
  }) async {
    if (!isAuthenticated) throw const ApiException('Not authenticated.');
    final baseUrl = ApiService.baseUrl;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-purchase'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cachedToken',
            },
            body: jsonEncode({
              'paymentId': paymentId,
              'purchaseToken': purchaseToken,
              'productId': productId ?? 'wireman_pro_yearly_699',
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final user = body['user'] as Map<String, dynamic>;
        final sub = user['subscription'] as Map<String, dynamic>?;
        _cachedPlan = sub?['plan'] as String? ?? 'pro_yearly';
        _cachedEnd = sub?['endDate'] as String? ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_subStatusKey, 'active');
        await prefs.setString(_subPlanKey, _cachedPlan!);
        if (_cachedEnd != null) await prefs.setString(_subEndKey, _cachedEnd!);

        return user;
      }
      throw ApiException(body['message'] as String? ?? 'Failed to activate subscription.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during purchase activation: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Logout & Clear Session
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    _cachedToken = null;
    _cachedEmail = null;
    _cachedName = null;
    _cachedPlan = null;
    _cachedEnd = null;
    _cachedCount = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_countKey);
    await prefs.remove(_subStatusKey);
    await prefs.remove(_subPlanKey);
    await prefs.remove(_subEndKey);
  }
}


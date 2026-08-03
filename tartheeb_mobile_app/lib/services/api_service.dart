import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String primaryBaseUrl = 'http://localhost:3000';
  static const String fallbackBaseUrl = 'http://13.233.246.171:3000';

  /// Get current configured server base URL
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_base_url') ?? primaryBaseUrl;
  }

  /// Update and save server base URL
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    await prefs.setString('server_base_url', cleanUrl);
  }

  /// Save session data
  static Future<void> saveSession({
    required String tenantId,
    required String madrasaName,
    required String adminName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenant_id', tenantId);
    await prefs.setString('madrasa_name', madrasaName);
    await prefs.setString('admin_name', adminName);
  }

  /// Get saved session
  static Future<Map<String, String?>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tenant_id': prefs.getString('tenant_id'),
      'madrasa_name': prefs.getString('madrasa_name'),
      'admin_name': prefs.getString('admin_name'),
    };
  }

  /// Logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Send POST helper with multi-host fallback
  static Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    final configuredUrl = await getBaseUrl();
    final urlsToTry = [
      configuredUrl,
      if (configuredUrl != primaryBaseUrl) primaryBaseUrl,
      if (configuredUrl != fallbackBaseUrl) fallbackBaseUrl,
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000',
    ];

    http.Response? lastResponse;

    for (final baseUrl in urlsToTry) {
      try {
        final uri = Uri.parse('$baseUrl$path');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          await setBaseUrl(baseUrl);
          return res;
        }
        lastResponse = res;
      } catch (_) {
        // Continue trying next host candidate
      }
    }

    return lastResponse ?? http.Response(jsonEncode({'error': 'Server unreachable'}), 503);
  }

  /// Send GET helper with multi-host fallback
  static Future<http.Response> _getWithFallback(String pathWithQuery) async {
    final configuredUrl = await getBaseUrl();
    final urlsToTry = [
      configuredUrl,
      if (configuredUrl != primaryBaseUrl) primaryBaseUrl,
      if (configuredUrl != fallbackBaseUrl) fallbackBaseUrl,
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000',
    ];

    http.Response? lastResponse;

    for (final baseUrl in urlsToTry) {
      try {
        final uri = Uri.parse('$baseUrl$pathWithQuery');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          return res;
        }
        lastResponse = res;
      } catch (_) {}
    }

    return lastResponse ?? http.Response(jsonEncode({'error': 'Server unreachable'}), 503);
  }

  /// Login API
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final body = {'username': email, 'password': password};

      // 1. Try /api/auth/login
      var res = await _postWithFallback('/api/auth/login', body);

      // 2. If 404, try /api/login
      if (res.statusCode == 404) {
        res = await _postWithFallback('/api/login', body);
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          await saveSession(
            tenantId: data['username'] ?? data['tenant_id'] ?? email,
            madrasaName: data['madrasa_name'] ?? 'Tartheeb Madrasa',
            adminName: data['username'] ?? 'Admin',
          );
        }
        return data;
      } else {
        try {
          final errorData = jsonDecode(res.body);
          final msg = errorData['error'] ?? errorData['message'] ?? 'Invalid credentials (${res.statusCode})';
          return {'success': false, 'message': msg};
        } catch (_) {
          return {'success': false, 'message': 'Invalid credentials (${res.statusCode})'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: Please check server connection.'};
    }
  }

  /// Get Dashboard Attendance Summary
  static Future<Map<String, dynamic>> getAttendanceSummary(String tenantId, String date) async {
    try {
      final res = await _getWithFallback('/api/attendance?tenant_id=$tenantId&date=$date');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }
    return {'records': [], 'total': 0, 'present': 0, 'late': 0, 'absent': 0};
  }

  /// Get Connected eSSL Devices
  static Future<List<dynamic>> getDevices() async {
    try {
      final res = await _getWithFallback('/api/devices');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['devices'] ?? [];
      }
    } catch (e) {
      print('Error fetching devices: $e');
    }
    return [];
  }

  /// Send Push Notification FCM Token
  static Future<void> registerFcmToken(String tenantId, String token) async {
    try {
      await _postWithFallback('/api/register-fcm-token', {'tenant_id': tenantId, 'fcm_token': token});
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://13.233.246.171:3000/api';
  static const Duration timeoutDuration = Duration(seconds: 10);

  // Headers helper
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Handle errors
  static String _handleError(dynamic error) {
    if (error is TimeoutException) {
      return 'Connection timed out. Please check your internet connection.';
    }
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot connect to server. Please check your internet.';
    }
    return msg.replaceAll('Exception: ', '');
  }

  // --- Auth ---
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': email, 'password': password}),
      ).timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] != false) {
        await _saveSession(data);
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  static Future<Map<String, dynamic>> memberLogin(
      String role, String institutionCode, String userId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/member-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': role,
          'institution_code': institutionCode,
          'user_id': userId,
          'password': password,
        }),
      ).timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] != false) {
        await _saveSession(data);
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String madrasaName,
    required String syllabus,
    required String adminName,
    required String phone,
    required String email,
    required String password,
    String place = '',
    String landmark = '',
    String district = '',
    String state = '',
    String country = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'madrasa_name': madrasaName,
          'syllabus': syllabus,
          'admin_name': adminName,
          'phone': phone,
          'email': email,
          'password': password,
          'place': place,
          'landmark': landmark,
          'district': district,
          'state': state,
          'country': country,
        }),
      ).timeout(timeoutDuration);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  // --- Session Management ---
  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['token'] != null) await prefs.setString('auth_token', data['token'].toString());
    if (data['tenant_id'] != null) await prefs.setString('tenant_id', data['tenant_id'].toString());
    if (data['username'] != null) await prefs.setString('username', data['username'].toString());
    if (data['madrasa_name'] != null) await prefs.setString('madrasa_name', data['madrasa_name'].toString());
    if (data['role'] != null) await prefs.setString('role', data['role'].toString());
    if (data['institution_code'] != null) await prefs.setString('institution_code', data['institution_code'].toString());
    if (data['permissions'] != null) await prefs.setString('permissions', jsonEncode(data['permissions']));
  }

  static Future<Map<String, String>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tenant_id': prefs.getString('tenant_id') ?? '',
      'username': prefs.getString('username') ?? '',
      'madrasa_name': prefs.getString('madrasa_name') ?? '',
      'role': prefs.getString('role') ?? '',
      'institution_code': prefs.getString('institution_code') ?? '',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- Generic helpers ---
  static Future<dynamic> _get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
      ).timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw Exception('Request failed: ${response.statusCode}');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  static Future<dynamic> _post(String path, [dynamic body]) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw Exception('Request failed: ${response.statusCode}');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  static Future<dynamic> _delete(String path) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
      ).timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      throw Exception('Request failed: ${response.statusCode}');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- Students ---
  static Future<dynamic> getStudents(String tenantId) => _get('/students?tenant_id=$tenantId');
  static Future<dynamic> createStudent(String tenantId, Map<String, dynamic> data) =>
      _post('/students', {...data, 'tenant_id': tenantId});
  static Future<dynamic> deleteStudent(String tenantId, String id) => _delete('/students/$id');

  // --- Teachers ---
  static Future<dynamic> getTeachers(String tenantId) => _get('/teachers?tenant_id=$tenantId');
  static Future<dynamic> createTeacher(String tenantId, Map<String, dynamic> data) =>
      _post('/teachers', {...data, 'tenant_id': tenantId});
  static Future<dynamic> deleteTeacher(String tenantId, String id) => _delete('/teachers/$id');

  // --- Batches ---
  static Future<dynamic> getBatches(String tenantId) => _get('/batches?tenant_id=$tenantId');
  static Future<dynamic> createBatch(String tenantId, Map<String, dynamic> data) =>
      _post('/batches', {...data, 'tenant_id': tenantId});
  static Future<dynamic> deleteBatch(String tenantId, String id) => _delete('/batches/$id');

  // --- Shifts ---
  static Future<dynamic> getShifts(String tenantId) => _get('/shifts?tenant_id=$tenantId');

  // --- Attendance ---
  static Future<dynamic> getAttendance(String tenantId, String date) =>
      _get('/attendance?tenant_id=$tenantId&date=$date');
  static Future<dynamic> submitManualAttendance(
      String tenantId, String date, String batchId, List<Map<String, dynamic>> records) =>
      _post('/attendance/manual', {
        'tenant_id': tenantId,
        'date': date,
        'batch_id': batchId,
        'records': records,
      });

  // --- Devices ---
  static Future<dynamic> getDevices(String tenantId) => _get('/devices?tenant_id=$tenantId');

  // --- Reports ---
  static Future<dynamic> getDashboardCandlestick(String tenantId) =>
      _get('/reports/dashboard-candlestick?tenant_id=$tenantId');

  // --- Notifications ---
  static Future<dynamic> registerToken(String token) =>
      _post('/notifications/register-token', {'token': token});
  static Future<dynamic> sendBroadcast(Map<String, dynamic> data) =>
      _post('/notifications/send-broadcast', data);
}

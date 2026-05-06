import 'dart:convert';
import 'package:http/http.dart' as http;

/// API client for communicating with the worktime backend server.
/// Works on all platforms (web, iOS, Android) via package:http.
class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient(this.baseUrl);

  bool get hasToken => _token != null;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Register a new user
  Future<ApiResult> register(String phone, String password, String nickname) async {
    return _post('/api/auth/register', {
      'phone': phone,
      'password': password,
      'nickname': nickname,
    });
  }

  /// Login with phone and password
  Future<ApiResult> login(String phone, String password) async {
    return _post('/api/auth/login', {
      'phone': phone,
      'password': password,
    });
  }

  /// Get work logs since a given timestamp
  Future<ApiResult> getWorkLogs({int sinceMs = 0}) async {
    return _get('/api/worklogs?since=$sinceMs');
  }

  /// Create a work log on the server
  Future<ApiResult> createWorkLog(Map<String, dynamic> log) async {
    return _post('/api/worklogs', log);
  }

  /// Update a work log on the server
  Future<ApiResult> updateWorkLog(String id, Map<String, dynamic> log) async {
    return _put('/api/worklogs/$id', log);
  }

  /// Delete a work log on the server
  Future<ApiResult> deleteWorkLog(String id) async {
    return _delete('/api/worklogs/$id');
  }

  /// Batch sync: push local changes + pull remote changes
  Future<ApiResult> sync(List<Map<String, dynamic>> changes, int lastSyncAt) async {
    return _post('/api/sync', {
      'changes': changes,
      'lastSyncAt': lastSyncAt,
    });
  }

  /// Get user settings
  Future<ApiResult> getSettings() async {
    return _get('/api/settings');
  }

  /// Update user settings
  Future<ApiResult> updateSettings(Map<String, dynamic> config) async {
    return _put('/api/settings', config);
  }

  Future<ApiResult> _get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      return _parseResponse(res, uri);
    } catch (e) {
      return ApiResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<ApiResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _parseResponse(res, uri);
    } catch (e) {
      return ApiResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<ApiResult> _put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _parseResponse(res, uri);
    } catch (e) {
      return ApiResult(ok: false, error: 'Network error: $e');
    }
  }

  Future<ApiResult> _delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final res = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15));
      return _parseResponse(res, uri);
    } catch (e) {
      return ApiResult(ok: false, error: 'Network error: $e');
    }
  }

  ApiResult _parseResponse(http.Response res, Uri uri) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResult(ok: true, data: body);
    }

    final msg = body?['error']?.toString() ?? 'HTTP ${res.statusCode}';
    return ApiResult(ok: false, error: msg, statusCode: res.statusCode, data: body);
  }
}

class ApiResult {
  final bool ok;
  final String? error;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiResult({
    required this.ok,
    this.error,
    this.statusCode,
    this.data,
  });

  T? get<T>(String key) => data?[key] as T?;
}

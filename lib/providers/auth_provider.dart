import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final ApiClient _api;
  final SyncService _syncService;
  User? _user;
  bool _isLoggedIn = false;
  bool _autoLoginAttempted = false;

  AuthProvider(this._api, this._syncService);

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get autoLoginAttempted => _autoLoginAttempted;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> login(String phone, String password,
      {bool rememberMe = false, bool autoLogin = false}) async {
    // Try API login first (with error handling for offline)
    bool apiOk = false;
    if (_api.hasToken) {
      try {
        final result = await _api.login(phone, password);
        if (result.ok) {
          apiOk = true;
          final token = result.get<String>('token') ?? '';
          _api.setToken(token);
          _syncService.markServerAvailable();

          // Save token locally
          final localUser = await _db.login(phone, password);
          if (localUser != null) {
            _user = localUser.copyWith(token: token, serverId: result.get<String>('serverId'));
            await _db.updateUser(_user!);
          }
        }
      } catch (_) {
        // API unreachable, continue with local login
      }
    }

    // Fallback to local login (always works offline)
    final user = await _db.login(phone, password);
    if (user != null) {
      _user = user;
      _isLoggedIn = true;
      // Restore API token if available
      if (user.token.isNotEmpty && !apiOk) {
        _api.setToken(user.token);
        _syncService.markServerAvailable();
      }

      // Save credentials if "remember me" is checked
      if (rememberMe) {
        await _db.saveCredentials(phone, _hashPassword(password), autoLogin: autoLogin);
        await _db.saveRememberPassword(password);
      }

      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> register(String phone, String password, String nickname) async {
    // Try API register first (with error handling for offline)
    try {
      final result = await _api.register(phone, password, nickname);
      if (result.ok) {
        final token = result.get<String>('token') ?? '';
        _api.setToken(token);
        _syncService.markServerAvailable();

        // Also save locally
        final localUser = await _db.register(phone, password, nickname);
        if (localUser != null) {
          _user = localUser.copyWith(token: token);
          await _db.updateUser(_user!);
          _isLoggedIn = true;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // API unreachable, continue with local registration
    }

    // Fallback: local only (offline registration)
    final user = await _db.register(phone, password, nickname);
    if (user != null) {
      _user = user;
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Attempt auto-login from saved credentials
  Future<bool> autoLogin() async {
    if (_autoLoginAttempted) return false;
    _autoLoginAttempted = true;

    // 快速短路：先检查是否启用了自动登录，避免不必要查询
    final autoLoginEnabled = await _db.isAutoLoginEnabled();
    if (!autoLoginEnabled) return false;

    final creds = await _db.getSavedCredentials();
    if (creds.isEmpty) return false;

    final phone = creds['phone'];
    final savedHash = creds['passwordHash'];
    if (phone == null || savedHash == null) return false;

    // Look up user by phone + hashed password directly (no double-hashing)
    final user = await _db.loginByHash(phone, savedHash);
    if (user != null) {
      _user = user;
      _isLoggedIn = true;
      if (user.token.isNotEmpty) {
        _api.setToken(user.token);
        _syncService.markServerAvailable();
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> clearSavedCredentials() async {
    await _db.clearCredentials();
  }

  Future<void> logout() async {
    _api.setToken(null);
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> updateProfile(String nickname) async {
    if (_user == null) return;
    _user = _user!.copyWith(nickname: nickname);
    await _db.updateUser(_user!);
    notifyListeners();
  }

  Future<void> updateConfig(String config) async {
    if (_user == null) return;
    _user = _user!.copyWith(config: config);
    await _db.updateUser(_user!);
    notifyListeners();
  }
}

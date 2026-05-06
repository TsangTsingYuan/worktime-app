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

  AuthProvider(this._api, this._syncService);

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String phone, String password) async {
    // Try API login first
    bool apiOk = false;
    if (_api.hasToken) {
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
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<bool> register(String phone, String password, String nickname) async {
    // Try API register first
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

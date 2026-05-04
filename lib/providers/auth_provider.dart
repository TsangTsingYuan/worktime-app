import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  User? _user;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String phone, String password) async {
    final user = await _db.login(phone, password);
    if (user != null) {
      _user = user;
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register(String phone, String password, String nickname) async {
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

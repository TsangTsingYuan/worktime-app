import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;
  bool _autoLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final db = DatabaseHelper();
    final phone = await db.getPref('remembered_phone');
    final pwd = await db.getRememberPassword();
    if (phone != null) {
      _phoneCtrl.text = phone;
      _rememberMe = true;
      if (pwd != null) {
        _passwordCtrl.text = pwd;
      }
      // Also check auto-login preference
      final autoLogin = await db.isAutoLoginEnabled();
      if (autoLogin) _autoLogin = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入手机号和密码');
      return;
    }
    if (!_isLogin && nickname.isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    bool ok;
    try {
      final auth = context.read<AuthProvider>();
      ok = _isLogin
          ? await auth.login(phone, password, rememberMe: _rememberMe, autoLogin: _autoLogin)
          : await auth.register(phone, password, nickname);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '操作失败，请稍后重试';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() {
        _error = _isLogin ? '登录失败，请检查手机号和密码' : '注册失败，手机号可能已存在';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width > 600 ? 400.0 : double.infinity;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  _isLogin ? '登录' : '注册',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Flexible(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nicknameCtrl,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
                if (_isLogin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        height: 32,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) => setState(() {
                            _rememberMe = v ?? false;
                            if (!_rememberMe) _autoLogin = false;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _rememberMe = !_rememberMe;
                          if (!_rememberMe) _autoLogin = false;
                        }),
                        child: const Text('记住密码', style: TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        height: 32,
                        child: Checkbox(
                          value: _autoLogin,
                          onChanged: _rememberMe
                              ? (v) => setState(() => _autoLogin = v ?? false)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      GestureDetector(
                        onTap: _rememberMe
                            ? () => setState(() => _autoLogin = !_autoLogin)
                            : null,
                        child: Text('自动登录',
                            style: TextStyle(
                                fontSize: 14,
                                color: _rememberMe ? null : Colors.grey)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_isLogin ? Icons.login : Icons.person_add),
                              const SizedBox(width: 8),
                              Text(_isLogin ? '登录' : '注册'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz, size: 18),
                      const SizedBox(width: 4),
                      Text(_isLogin ? '没有账号？去注册' : '已有账号？去登录'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

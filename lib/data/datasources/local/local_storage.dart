import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();

  static final LocalStorage instance = LocalStorage._();

  static const String _keyRegisteredUsername = 'registered_username';
  static const String _keyRegisteredPassword = 'registered_password';
  static const String _keySessionUser = 'session_user_json';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveRegisteredCredentials({
    required String username,
    required String password,
  }) async {
    await init();
    await _prefs!.setString(_keyRegisteredUsername, username.trim());
    await _prefs!.setString(_keyRegisteredPassword, password);
  }

  Future<({String username, String password})?>
  getRegisteredCredentials() async {
    await init();
    final username = _prefs!.getString(_keyRegisteredUsername);
    final password = _prefs!.getString(_keyRegisteredPassword);

    if (username == null || password == null) return null;
    return (username: username, password: password);
  }

  Future<bool> verifyLocalCredentials({
    required String username,
    required String password,
  }) async {
    final creds = await getRegisteredCredentials();
    if (creds == null) return false;

    return creds.username == username.trim() && creds.password == password;
  }

  Future<void> saveSessionUser(Map<String, dynamic> userJson) async {
    await init();
    await _prefs!.setString(_keySessionUser, jsonEncode(userJson));
  }

  Future<Map<String, dynamic>?> getSessionUser() async {
    await init();
    final raw = _prefs!.getString(_keySessionUser);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<void> clearSessionUser() async {
    await init();
    await _prefs!.remove(_keySessionUser);
  }
}

import 'package:flutter/foundation.dart';

import '../auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService.instance;

  AuthUser? _currentUser;
  bool _isLoading = false;

  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> loadSession() async {
    _setLoading(true);
    _currentUser = await _authService.getCurrentUser();
    _setLoading(false);
  }

  Future<void> loginLocal({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _currentUser = await _authService.loginLocal(
      username: username,
      password: password,
    );
    _setLoading(false);
  }

  Future<void> loginWithGoogle() async {
    _setLoading(true);
    _currentUser = await _authService.loginWithGoogle();
    _setLoading(false);
  }

  Future<void> logout() async {
    _setLoading(true);
    await _authService.logout();
    _currentUser = null;
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

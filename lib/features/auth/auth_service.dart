import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/datasources/local/local_storage.dart';

enum AuthProviderType { local, google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    required this.provider,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final AuthProviderType provider;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'provider': provider.name,
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      provider: AuthProviderType.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AuthProviderType.local,
      ),
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final LocalStorage _localStorage = LocalStorage.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: <String>['email']);

  bool _isFirebaseAvailable = false;

  void setFirebaseAvailability(bool value) {
    _isFirebaseAvailable = value;
  }

  Future<void> init() async {
    await _localStorage.init();
    // No-op for GoogleSignIn package initialization.
  }

  Future<void> registerLocal({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Username và password không được để trống.');
    }
    if (password.length < 6) {
      throw const AuthException('Password phải có ít nhất 6 ký tự.');
    }

    await _localStorage.saveRegisteredCredentials(
      username: username.trim(),
      password: password,
    );
  }

  Future<AuthUser> loginLocal({
    required String username,
    required String password,
  }) async {
    final valid = await _localStorage.verifyLocalCredentials(
      username: username,
      password: password,
    );

    if (!valid) {
      throw const AuthException('Sai tài khoản hoặc mật khẩu.');
    }

    final user = AuthUser(
      id: username.trim().toLowerCase(),
      name: username.trim(),
      provider: AuthProviderType.local,
    );

    await _localStorage.saveSessionUser(user.toJson());
    return user;
  }

  Future<AuthUser> loginWithGoogle() async {
    if (!_isFirebaseAvailable) {
      throw const AuthException(
        'Google Login chưa sẵn sàng. Cần cấu hình Firebase cho project.',
      );
    }

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Bạn đã huỷ đăng nhập Google.');
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw const AuthException('Đăng nhập Google thất bại.');
    }

    final user = AuthUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Google User',
      email: firebaseUser.email,
      avatarUrl: firebaseUser.photoURL,
      provider: AuthProviderType.google,
    );

    await _localStorage.saveSessionUser(user.toJson());
    return user;
  }

  Future<AuthUser?> getCurrentUser() async {
    final sessionJson = await _localStorage.getSessionUser();
    if (sessionJson == null) return null;
    return AuthUser.fromJson(sessionJson);
  }

  Future<bool> isLoggedIn() async {
    return (await getCurrentUser()) != null;
  }

  Future<void> logout() async {
    if (_isFirebaseAvailable) {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    }
    await _localStorage.clearSessionUser();
  }
}

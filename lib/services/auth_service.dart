import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { student, teacher }

class AuthUser {
  final String id;
  final String displayName;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.displayName,
    required this.role,
  });
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthRepository {
  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthUser?> loadPersistedUser();

  Future<void> signOut();
}

class MockAuthRepository implements AuthRepository {
  static const _storageKey = 'readright.auth.user';
  final SharedPreferences _prefs;

  MockAuthRepository(this._prefs);

  static final Map<String, _MockUser> _users = {
    'student@readright.app': _MockUser(
      id: 'student-001',
      email: 'student@readright.app',
      password: 'student123',
      displayName: 'Student Reader',
      role: UserRole.student,
    ),
    'teacher@readright.app': _MockUser(
      id: 'teacher-001',
      email: 'teacher@readright.app',
      password: 'teacher123',
      displayName: 'Teacher Coach',
      role: UserRole.teacher,
    ),
  };

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _users[normalizedEmail];
    if (user == null || user.password != password.trim()) {
      throw const AuthException('Invalid credentials');
    }

    await _prefs.setString(_storageKey, user.email);
    return user.toAuthUser();
  }

  @override
  Future<AuthUser?> loadPersistedUser() async {
    final storedEmail = _prefs.getString(_storageKey);
    if (storedEmail == null) return null;

    final user = _users[storedEmail];
    return user?.toAuthUser();
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_storageKey);
  }
}

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;

  AuthController({required AuthRepository repository})
      : _repository = repository;

  AuthUser? _currentUser;
  bool _initializing = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitializing => _initializing;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _initializing = true;
    notifyListeners();
    _currentUser = await _repository.loadPersistedUser();
    _initializing = false;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setSubmitting(true);
    try {
      final user = await _repository.signIn(email: email, password: password);
      _currentUser = user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setSubmitting(bool value) {
    if (_isSubmitting != value) {
      _isSubmitting = value;
      notifyListeners();
    }
  }
}

class _MockUser {
  final String id;
  final String email;
  final String password;
  final String displayName;
  final UserRole role;

  const _MockUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
  });

  AuthUser toAuthUser() => AuthUser(
        id: id,
        displayName: displayName,
        role: role,
      );
}

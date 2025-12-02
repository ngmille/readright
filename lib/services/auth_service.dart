import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<AuthUser> register({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  });

  Future<AuthUser?> loadPersistedUser();

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final String collectionName;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.collectionName = 'users',
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          'Unable to sign in right now. Please try again.',
        );
      }
      return _fetchOrCreateProfile(user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    }
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    try {
      final normalizedEmail = email.trim();
      final existingProfiles = await _collection
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (existingProfiles.docs.isNotEmpty) {
        throw const AuthException('An account with this email already exists');
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Unable to finish sign up. Please try again.');
      }

      final profile = _buildProfilePayload(
        email: normalizedEmail,
        role: role,
        displayName: displayName,
      );

      await _collection.doc(user.uid).set(profile);
      return AuthUser(
        id: user.uid,
        displayName: profile['displayName'] as String,
        role: role,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    }
  }

  @override
  Future<AuthUser?> loadPersistedUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _fetchOrCreateProfile(user);
    } on AuthException {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AuthUser> _fetchOrCreateProfile(User user) async {
    final docRef = _collection.doc(user.uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      final fallbackRole = UserRole.student;
      final payload = _buildProfilePayload(
        email: _resolveEmail(user),
        role: fallbackRole,
        displayName: user.displayName,
      );
      await docRef.set(payload);
      return AuthUser(
        id: user.uid,
        displayName: payload['displayName'] as String,
        role: fallbackRole,
      );
    }

    final data = snapshot.data();
    if (data == null) {
      throw const AuthException(
        'Account profile is missing. Please contact support.',
      );
    }

    final bool retainAudio = data['retainAudio'] as bool? ?? false;

    return AuthUser(
      id: user.uid,
      displayName: (data['displayName'] as String?) ??
          user.displayName ??
          user.email ??
          'Reader',
      role: _mapRole(data['role'] as String?),
    );
  }

  UserRole _mapRole(String? rawRole) {
    switch (rawRole?.toLowerCase()) {
      case 'teacher':
        return UserRole.teacher;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  String _roleToString(UserRole role) =>
      role == UserRole.teacher ? 'teacher' : 'student';

  String _resolveEmail(User user) => user.email ?? '${user.uid}@readright.app';

  Map<String, dynamic> _buildProfilePayload({
    required String email,
    required UserRole role,
    String? displayName,
  }) {
    return {
      'email': email.trim(),
      'role': _roleToString(role),
      'displayName': _resolveDisplayName(displayName, email),
      'createdAt': FieldValue.serverTimestamp(),
      'retainAudio': false,
    };
  }

  String _resolveDisplayName(String? provided, String email) {
    final candidate = provided?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    final namePart = email.split('@').first;
    if (namePart.isEmpty) return email;
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'weak-password':
        return 'Please choose a stronger password';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
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
  Future<AuthUser> register({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_users.containsKey(normalizedEmail)) {
      throw const AuthException('An account with this email already exists');
    }

    final user = _MockUser(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      email: normalizedEmail,
      password: password.trim(),
      displayName: displayName?.trim().isEmpty ?? true
          ? normalizedEmail
          : displayName!.trim(),
      role: role,
    );

    _users[normalizedEmail] = user;
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

  Future<bool> register({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    _setSubmitting(true);
    try {
      final user = await _repository.register(
        email: email,
        password: password,
        role: role,
        displayName: displayName,
      );
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

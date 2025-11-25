import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/attempt_model.dart';
import 'auth_service.dart';

abstract class AttemptRepository {
  Future<List<Attempt>> fetchAttempts({required String userId});

  Future<Attempt> saveAttempt({
    required String userId,
    required Attempt attempt,
    String? audioFilePath,
  });
}

class MockAttemptRepository implements AttemptRepository {
  final Map<String, List<Attempt>> _attempts;

  MockAttemptRepository({Map<String, List<Attempt>>? seed})
      : _attempts = seed != null
            ? seed.map((key, value) => MapEntry(key, List.of(value)))
            : {};

  @override
  Future<List<Attempt>> fetchAttempts({required String userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_attempts[userId] ?? const []);
  }

  @override
  Future<Attempt> saveAttempt({
    required String userId,
    required Attempt attempt,
    String? audioFilePath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final enrichedAttempt =
        audioFilePath != null ? attempt.copyWith(audioUrl: audioFilePath) : attempt;
    final userAttempts = _attempts.putIfAbsent(userId, () => []);
    userAttempts.insert(0, enrichedAttempt);
    return enrichedAttempt;
  }
}

class FirestoreAttemptRepository implements AttemptRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;

  FirestoreAttemptRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _attemptCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('attempts');
  }

  @override
  Future<List<Attempt>> fetchAttempts({required String userId}) async {
    final snapshot = await _attemptCollection(userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    return snapshot.docs
        .map((doc) => Attempt.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<Attempt> saveAttempt({
    required String userId,
    required Attempt attempt,
    String? audioFilePath,
  }) async {
    var enrichedAttempt = attempt;
    if (audioFilePath != null) {
      final audioUrl = await _uploadRecording(userId, attempt.id, audioFilePath);
      if (audioUrl == null) {
        throw Exception('Recording upload failed');
      }
      enrichedAttempt = attempt.copyWith(audioUrl: audioUrl);
    }
    await _attemptCollection(userId).doc(enrichedAttempt.id).set(enrichedAttempt.toMap());
    return enrichedAttempt;
  }

  Future<String?> _uploadRecording(
    String userId,
    String attemptId,
    String localPath,
  ) async {
    final storage = _storage;
    if (storage == null) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    final ref = storage.ref('users/$userId/attempts/$attemptId.m4a');
    try {
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/m4a'),
      );
      return await ref.getDownloadURL();
    } finally {
      unawaited(file.delete().catchError((_) => file));
    }
  }
}

class AttemptController extends ChangeNotifier {
  final AttemptRepository _repository;
  List<Attempt> _attempts = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  String? _authUserId;
  UserRole? _authUserRole;
  String? _activeStudentId;

  AttemptController({required AttemptRepository repository}) : _repository = repository;

  List<Attempt> get attempts => List.unmodifiable(_attempts);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _error;
  int get totalAttempts => _attempts.length;
  double get averageScore {
    if (_attempts.isEmpty) return 0;
    final sum = _attempts.fold<int>(0, (total, attempt) => total + attempt.score);
    return sum / _attempts.length;
  }

  String? get activeStudentId => _activeStudentId;
  UserRole? get currentRole => _authUserRole;

  void updateAuthenticatedUser(AuthUser? user) {
    _authUserId = user?.id;
    _authUserRole = user?.role;
    _error = null;

    if (user == null) {
      _activeStudentId = null;
      _attempts = const [];
      notifyListeners();
      return;
    }

    if (user.role == UserRole.student) {
      _activeStudentId = user.id;
      _loadAttemptsFor(user.id);
    } else {
      _activeStudentId = null;
      _attempts = const [];
      notifyListeners();
    }
  }

  Future<void> loadAttemptsForStudent(String studentId) async {
    if (_authUserRole != UserRole.teacher) return;
    if (_activeStudentId == studentId && _attempts.isNotEmpty) return;
    _activeStudentId = studentId;
    await _loadAttemptsFor(studentId);
  }

  Future<void> addAttempt({
    required String word,
    required int score,
    required String feedback,
    String? transcript,
    double? accuracy,
    DateTime? timestamp,
    Duration? duration,
    String? audioFilePath,
  }) async {
    final targetUserId = _authUserRole == UserRole.teacher ? _activeStudentId : _authUserId;
    if (targetUserId == null) {
      _error = 'No student selected';
      notifyListeners();
      return;
    }

    final attempt = Attempt(
      id: _generateId(),
      wordText: word,
      score: score,
      feedback: feedback,
      createdAt: timestamp ?? DateTime.now(),
      transcript: transcript,
      accuracy: accuracy,
      duration: duration,
    );

    _saving = true;
    notifyListeners();

    try {
      final savedAttempt = await _repository.saveAttempt(
        userId: targetUserId,
        attempt: attempt,
        audioFilePath: audioFilePath,
      );
      if (_activeStudentId == targetUserId) {
        _attempts = [savedAttempt, ..._attempts];
      }
      _error = null;
    } catch (error) {
      _error = 'Unable to save attempt';
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _loadAttemptsFor(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      _attempts = await _repository.fetchAttempts(userId: userId);
      _error = null;
    } catch (_) {
      _error = 'Unable to load attempts';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _generateId() {
    final random = Random.secure().nextInt(0xFFFFFF);
    return 'a${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}$random';
  }
}

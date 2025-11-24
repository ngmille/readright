import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/attempt_model.dart';

abstract class AttemptRepository {
  Future<List<Attempt>> fetchAttempts();

  Future<void> saveAttempt(Attempt attempt);
}

class MockAttemptRepository implements AttemptRepository {
  final List<Attempt> _attempts;

  MockAttemptRepository({List<Attempt>? seed}) : _attempts = List.from(seed ?? _sampleData);

  static final _sampleData = List<Attempt>.unmodifiable([
    Attempt(
      id: 'a1',
      wordText: 'the',
      score: 95,
      feedback: 'Strong pronunciation',
      createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      transcript: 'the',
      accuracy: 0.95,
      duration: const Duration(seconds: 2),
    ),
    Attempt(
      id: 'a2',
      wordText: 'cat',
      score: 82,
      feedback: 'Watch the vowel sound',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      transcript: 'kat',
      accuracy: 0.82,
      duration: const Duration(seconds: 3),
    ),
    Attempt(
      id: 'a3',
      wordText: 'dog',
      score: 100,
      feedback: 'Perfect!',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      transcript: 'dog',
      accuracy: 1.0,
      duration: const Duration(seconds: 2),
    ),
    Attempt(
      id: 'a4',
      wordText: 'and',
      score: 78,
      feedback: 'Blend the ending',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      transcript: 'end',
      accuracy: 0.78,
      duration: const Duration(seconds: 3),
    ),
    Attempt(
      id: 'a5',
      wordText: 'bed',
      score: 91,
      feedback: 'Nice pacing',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      transcript: 'bed',
      accuracy: 0.91,
      duration: const Duration(seconds: 2),
    ),
  ]);

  @override
  Future<List<Attempt>> fetchAttempts() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_attempts);
  }

  @override
  Future<void> saveAttempt(Attempt attempt) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _attempts.insert(0, attempt);
  }
}

class AttemptController extends ChangeNotifier {
  final AttemptRepository _repository;
  List<Attempt> _attempts = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  AttemptController({required AttemptRepository repository}) : _repository = repository;

  List<Attempt> get attempts => List.unmodifiable([..._attempts]);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _error;
  int get totalAttempts => _attempts.length;
  double get averageScore {
    if (_attempts.isEmpty) return 0;
    final sum = _attempts.fold<int>(0, (total, attempt) => total + attempt.score);
    return sum / _attempts.length;
  }

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    try {
      _attempts = await _repository.fetchAttempts();
      _error = null;
    } catch (error) {
      _error = 'Unable to load attempts';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addAttempt({
    required String word,
    required int score,
    required String feedback,
    String? transcript,
    double? accuracy,
    DateTime? timestamp,
    Duration? duration,
    String? audioPath,
  }) async {
    final attempt = Attempt(
      id: _generateId(),
      wordText: word,
      score: score,
      feedback: feedback,
      createdAt: timestamp ?? DateTime.now(),
      transcript: transcript,
      accuracy: accuracy,
      duration: duration,
      audioPath: audioPath,
    );

    _saving = true;
    notifyListeners();

    try {
      await _repository.saveAttempt(attempt);
      _attempts = [attempt, ..._attempts];
      _error = null;
    } catch (_) {
      _error = 'Unable to save attempt';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  String _generateId() {
    final random = Random.secure().nextInt(0xFFFFFF);
    return 'a${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}$random';
  }
}

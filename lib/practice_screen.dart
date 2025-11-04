import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'models/word_model.dart';
import 'services/attempt_repository.dart';
import 'services/auth_service.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  static const _maxRecordingSeconds = 7;
  static const _masteryThreshold = 0.9; // 90%
  static const _listOrder = ['dolch', 'phonics', 'minimal_pair'];

  final SpeechToText _speech = SpeechToText();

  SharedPreferences? _prefs;
  String? _userId;

  bool _loading = true;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _allListsComplete = false;

  PermissionStatus? _micPermission;
  PermissionStatus? _speechPermission;

  Timer? _countdownTimer;
  int _remainingSeconds = _maxRecordingSeconds;
  DateTime? _listeningStartedAt;
  bool _processedCurrentAttempt = false;

  final List<WordList> _wordLists = [];
  final List<WordItem> _currentQueue = [];
  int _currentListIndex = 0;
  int _currentWordIndex = 0;
  final Set<String> _masteredKeys = {};

  String _lastTranscript = '';
  double _lastAccuracy = 0;
  bool? _lastWasCorrect;
  String? _feedbackMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthController>();
    final user = auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'You need to sign in to practice words.';
        _loading = false;
      });
      return;
    }

    _userId = user.id;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lists = await WordList.fromCSV('assets/seed_words.csv');

      lists.sort((a, b) {
        final indexA = _listOrder.indexOf(a.id);
        final indexB = _listOrder.indexOf(b.id);
        return (indexA < 0 ? _listOrder.length : indexA) -
            (indexB < 0 ? _listOrder.length : indexB);
      });

      _wordLists
        ..clear()
        ..addAll(lists);

      _prefs = prefs;
      _loadProgress();
      await _initSpeech();
      _rebuildQueue();
    } catch (error) {
      setState(() {
        _errorMessage = 'Unable to load practice lists. ${error.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _initSpeech({bool force = false}) async {
    if (_speechReady && !force) {
      return;
    }

    final micStatus = await Permission.microphone.request();
    final speechStatus = Platform.isIOS
        ? await Permission.speech.request()
        : PermissionStatus.granted;

    setState(() {
      _micPermission = micStatus;
      _speechPermission = speechStatus;
    });

    if (!micStatus.isGranted || !speechStatus.isGranted) {
      setState(() {
        _speechReady = false;
        _errorMessage = 'Microphone and speech permissions are required.';
      });
      return;
    }

    final available = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
      debugLogging: false,
    );

    setState(() {
      _speechReady = available;
      if (!available) {
        _errorMessage = 'Speech recognition is not available on this device.';
      }
    });
  }

  void _loadProgress() {
    if (_prefs == null || _userId == null) return;
    final stored = _prefs!.getStringList(_masteredKeyForUser(_userId!));
    if (stored != null) {
      _masteredKeys
        ..clear()
        ..addAll(stored);
    }
  }

  Future<void> _saveProgress() async {
    if (_prefs == null || _userId == null) return;
    await _prefs!.setStringList(_masteredKeyForUser(_userId!), _masteredKeys.toList());
  }

  void _rebuildQueue() {
    if (_wordLists.isEmpty) {
      setState(() {
        _loading = false;
        _allListsComplete = true;
      });
      return;
    }

    for (var i = 0; i < _wordLists.length; i++) {
      final list = _wordLists[i];
      final unmastered = list.items
          .where((item) => !_isWordMastered(list.id, item.text))
          .toList();

      if (unmastered.isNotEmpty) {
        setState(() {
          _currentListIndex = i;
          _currentQueue
            ..clear()
            ..addAll(unmastered);
          _currentWordIndex = 0;
          _allListsComplete = false;
          _loading = false;
        });
        return;
      }
    }

    setState(() {
      _allListsComplete = true;
      _currentQueue.clear();
      _currentWordIndex = 0;
      _loading = false;
    });
  }

  Future<void> _startListening() async {
    if (_isListening || _isProcessing) {
      return;
    }

    if (!_speechReady) {
      await _initSpeech(force: true);
      if (!_speechReady) {
        return;
      }
    }

    if (_currentQueue.isEmpty) {
      return;
    }

    setState(() {
      _isListening = true;
      _remainingSeconds = _maxRecordingSeconds;
      _listeningStartedAt = DateTime.now();
      _processedCurrentAttempt = false;
      _lastTranscript = '';
      _lastAccuracy = 0;
      _lastWasCorrect = null;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    var listenSuccess = await _startSpeechSession(onDevice: true);
    if (!listenSuccess) {
      listenSuccess = await _startSpeechSession(onDevice: false);
    }

    if (!listenSuccess && mounted) {
      setState(() {
        _isListening = false;
        _errorMessage = 'Unable to start speech recognition.';
      });
      return;
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        _stopListening(auto: true);
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      }
    });
  }

  Future<bool> _startSpeechSession({required bool onDevice}) {
    return _speech
        .listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: _maxRecordingSeconds),
          pauseFor: const Duration(seconds: 2),
          localeId: 'en_US',
          listenOptions: SpeechListenOptions(
            partialResults: true,
            listenMode: ListenMode.dictation,
            onDevice: onDevice,
          ),
        )
        .then((_) => _speech.isListening)
        .catchError((_) => false);
  }

  Future<void> _stopListening({bool auto = false}) async {
    if (!_isListening) return;

    _countdownTimer?.cancel();
    await _speech.stop();

    if (!mounted) return;
    setState(() {
      _isListening = false;
    });

    if (!_processedCurrentAttempt) {
      _processTranscript(_lastTranscript);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _lastTranscript = result.recognizedWords.trim();
    });

    if (result.finalResult && !_processedCurrentAttempt) {
      _processTranscript(result.recognizedWords);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _errorMessage = 'Speech error: ${error.errorMsg}';
      _isListening = false;
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' && _isListening) {
      _stopListening();
    }
  }

  Future<void> _processTranscript(String transcript) async {
    if (_isProcessing || _currentQueue.isEmpty) {
      return;
    }

    _processedCurrentAttempt = true;
    _countdownTimer?.cancel();

    final attemptController = context.read<AttemptController>();

    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {
        // Ignore stop errors; we only need to ensure the session ends.
      }
    }

    final word = _currentQueue[_currentWordIndex];
    final normalizedTarget = word.text.trim().toLowerCase();
    final normalizedTranscript = transcript.trim().toLowerCase();
    final duration = _listeningStartedAt != null ? DateTime.now().difference(_listeningStartedAt!) : null;

    double accuracy = 0;
    if (normalizedTranscript.isNotEmpty) {
      accuracy = _calculateSimilarity(normalizedTarget, normalizedTranscript);
    }
    final score = (accuracy * 100).clamp(0, 100).round();
    final isCorrect = accuracy >= _masteryThreshold;
    final feedback = _feedbackForScore(score, normalizedTranscript.isEmpty);

    setState(() {
      _isListening = false;
      _isProcessing = true;
      _lastTranscript = transcript.trim();
      _lastAccuracy = accuracy;
      _lastWasCorrect = isCorrect;
      _feedbackMessage = feedback;
    });

    await attemptController.addAttempt(
      word: word.text,
      score: score,
      feedback: feedback,
      transcript: normalizedTranscript,
      accuracy: accuracy,
      duration: duration,
    );

    if (isCorrect) {
      await _markWordMastered(word);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _advanceToNextWord(removeCurrent: true);
    } else {
      _advanceToNextWord(removeCurrent: false);
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _markWordMastered(WordItem word) async {
    final list = _wordLists[_currentListIndex];
    final key = _wordKey(list.id, word.text);
    _masteredKeys.add(key);
    await _saveProgress();
    _rebuildQueue();
  }

  void _advanceToNextWord({required bool removeCurrent}) {
    if (_currentQueue.isEmpty) {
      _rebuildQueue();
      return;
    }

    if (removeCurrent) {
      _currentQueue.removeAt(_currentWordIndex);
      if (_currentQueue.isEmpty) {
        _rebuildQueue();
        return;
      }
      if (_currentWordIndex >= _currentQueue.length) {
        _currentWordIndex = 0;
      }
    } else {
      _currentWordIndex = (_currentWordIndex + 1) % _currentQueue.length;
    }

    setState(() {
      // Trigger rebuild for next word
    });
  }

  bool _isWordMastered(String listId, String word) {
    return _masteredKeys.contains(_wordKey(listId, word));
  }

  String _wordKey(String listId, String word) {
    return '${listId.toLowerCase()}|${word.toLowerCase()}';
  }

  String _masteredKeyForUser(String userId) => 'practice_mastered_$userId';

  double _calculateSimilarity(String expected, String actual) {
    if (expected.isEmpty || actual.isEmpty) return 0;
    if (expected == actual) return 1;

    final m = expected.length;
    final n = actual.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = expected[i - 1] == actual[j - 1] ? 0 : 1;
        dp[i][j] = min(
          min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }

    final distance = dp[m][n];
    final maxLen = max(m, n).toDouble();
    return (maxLen - distance) / maxLen;
  }

  String _feedbackForScore(int score, bool noTranscript) {
    if (noTranscript) {
      return 'I did not catch that. Let\'s try again.';
    }
    if (score >= 95) {
      return 'Excellent pronunciation!';
    } else if (score >= 85) {
      return 'Great job! Keep it up.';
    } else if (score >= 70) {
      return 'Pretty good. Try speaking clearly on the tricky sounds.';
    } else {
      return 'Let\'s try again. Focus on each sound of the word.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final attemptController = context.watch<AttemptController>();

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 174, 98, 186),
        appBar: AppBar(
          title: const Text('Practice'),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_micPermission?.isPermanentlyDenied == true ||
        _speechPermission?.isPermanentlyDenied == true) {
      return _buildPermissionScaffold(
        message:
            'Speech recognition permissions are blocked. Please enable them in Settings to continue practicing.',
      );
    }

    if (!_speechReady) {
      return _buildPermissionScaffold(
        message: _errorMessage ?? 'Tap the button below to enable speech recognition.',
      );
    }

    if (_allListsComplete) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 174, 98, 186),
        appBar: AppBar(
          title: const Text('Practice'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'List complete!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You mastered every word. Fantastic work!',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_currentQueue.isEmpty) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 174, 98, 186),
        appBar: AppBar(
          title: const Text('Practice'),
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentList = _wordLists[_currentListIndex];
    final currentWord = _currentQueue[_currentWordIndex];
    final masteredCount = currentList.items
        .where((item) => _isWordMastered(currentList.id, item.text))
        .length;
    final totalCount = currentList.items.length;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListProgressHeader(
              listTitle: currentList.title,
              listPosition: _currentListIndex + 1,
              totalLists: _wordLists.length,
              masteredCount: masteredCount,
              totalCount: totalCount,
            ),
            const SizedBox(height: 16),
            _WordCard(word: currentWord),
            const SizedBox(height: 16),
            _RecordingCard(
              isListening: _isListening,
              isProcessing: _isProcessing || attemptController.isSaving,
              remainingSeconds: _remainingSeconds,
              onRecordPressed: _isListening
                  ? () => _stopListening(auto: false)
                  : () => _startListening(),
              canPress: !_isProcessing,
            ),
            if (_errorMessage != null && !_isListening) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 16),
              _ResultSummary(
                transcript: _lastTranscript,
                feedback: _feedbackMessage!,
                accuracy: _lastAccuracy,
                wasCorrect: _lastWasCorrect,
              ),
            ],
            if (_lastWasCorrect == false && !_isListening && !_isProcessing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _startListening,
                icon: const Icon(Icons.replay),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Scaffold _buildPermissionScaffold({required String message}) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 174, 98, 186),
      appBar: AppBar(
        title: const Text('Practice'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_off, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _initSpeech(force: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListProgressHeader extends StatelessWidget {
  final String listTitle;
  final int listPosition;
  final int totalLists;
  final int masteredCount;
  final int totalCount;

  const _ListProgressHeader({
    required this.listTitle,
    required this.listPosition,
    required this.totalLists,
    required this.masteredCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'List $listPosition of $totalLists',
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
            const SizedBox(height: 4),
            Text(
              listTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalCount == 0 ? 0 : masteredCount / totalCount,
              minHeight: 8,
              backgroundColor: Colors.purple.shade100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 8),
            Text('$masteredCount of $totalCount words mastered'),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final WordItem word;

  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word.text.toUpperCase(),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Sample sentences:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...word.sampleSentences.map(
              (sentence) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $sentence', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final bool isListening;
  final bool isProcessing;
  final int remainingSeconds;
  final Future<void> Function() onRecordPressed;
  final bool canPress;

  const _RecordingCard({
    required this.isListening,
    required this.isProcessing,
    required this.remainingSeconds,
    required this.onRecordPressed,
    required this.canPress,
  });

  @override
  Widget build(BuildContext context) {
    final label = isListening ? 'Stop' : 'Record';
    final icon = isListening ? Icons.stop : Icons.mic;
    final statusText = isListening
        ? 'Listening... $remainingSeconds s'
        : isProcessing
            ? 'Checking pronunciation...'
            : 'Tap record and say the word clearly.';

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 72, color: isListening ? Colors.red : Colors.deepPurple),
            const SizedBox(height: 12),
            Text(statusText, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: canPress ? () => onRecordPressed() : null,
              icon: Icon(icon),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final String transcript;
  final String feedback;
  final double accuracy;
  final bool? wasCorrect;

  const _ResultSummary({
    required this.transcript,
    required this.feedback,
    required this.accuracy,
    required this.wasCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final scoreText = 'Score: ${(accuracy * 100).clamp(0, 100).round()}%';
    final color = wasCorrect == true
        ? Colors.green
        : wasCorrect == false
            ? Colors.orange
            : Colors.black;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scoreText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(feedback, style: const TextStyle(fontSize: 16)),
            if (transcript.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('You said:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(transcript, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:readright/services/pronunciation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  SharedPreferences? _prefs;
  String? _userId;

  bool _loading = true;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _allListsComplete = false;
  bool _recorderReady = false;
  bool _isRecordingAudio = false;

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
  String? _phonemeFeedback;
  String? _errorMessage;
  String? _recordingFilePath;

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
    _recorder.closeRecorder();
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
      await _initRecorder();
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
      _showPermissionDialog(
        permanentlyDenied:
            micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied,
      );
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

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
      if (!mounted) return;
      setState(() {
        _recorderReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recorderReady = false;
      });
    }
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

    if (_micPermission?.isGranted != true || _speechPermission?.isGranted != true) {
      await _initSpeech(force: true);
      if (_micPermission?.isGranted != true || _speechPermission?.isGranted != true) {
        _showPermissionDialog(
          permanentlyDenied: _micPermission?.isPermanentlyDenied == true ||
              _speechPermission?.isPermanentlyDenied == true,
        );
        return;
      }
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

    _recordingFilePath = null;

    setState(() {
      _isListening = true;
      _remainingSeconds = _maxRecordingSeconds;
      _listeningStartedAt = DateTime.now();
      _processedCurrentAttempt = false;
      _lastTranscript = '';
      _lastAccuracy = 0;
      _lastWasCorrect = null;
      _feedbackMessage = null;
      _phonemeFeedback = null;
      _errorMessage = null;
    });

    if (_recorderReady) {
      try {
        await _startRecorder();
      } catch (_) {
        _recordingFilePath = null;
      }
    }

    var listenSuccess = await _startSpeechSession(onDevice: true);
    if (!listenSuccess) {
      listenSuccess = await _startSpeechSession(onDevice: false);
    }

    if (!listenSuccess && mounted) {
      await _stopRecorder();
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

  void _showPermissionDialog({required bool permanentlyDenied}) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Microphone disabled'),
        content: Text(
          permanentlyDenied
              ? 'Please enable the microphone and speech permissions from Settings to keep practicing.'
              : 'We need microphone access to listen while you read. Please allow it to continue.',
        ),
        actions: [
          if (permanentlyDenied)
            CupertinoDialogAction(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecorder() async {
    if (!_recorderReady) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/readright_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacMP4,
      numChannels: 1,
      sampleRate: 16000,
    );
    _isRecordingAudio = true;
    _recordingFilePath = path;
  }

  Future<String?> _stopRecorder() async {
    if (!_recorderReady) return _recordingFilePath;
    if (_isRecordingAudio) {
      final path = await _recorder.stopRecorder();
      _isRecordingAudio = false;
      if (path != null) {
        _recordingFilePath = path;
      }
    }
    return _recordingFilePath;
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
      await _processTranscript(_lastTranscript);
    }
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    if (!mounted) return;
    setState(() {
      _lastTranscript = result.recognizedWords.trim();
    });

    if (result.finalResult && !_processedCurrentAttempt) {
      await _processTranscript(result.recognizedWords);
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
    if (_isProcessing || _currentQueue.isEmpty) return;

    _processedCurrentAttempt = true;
    _countdownTimer?.cancel();
    final attemptController = context.read<AttemptController>();
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (_) {} // ignore
    }

    final audioFilePath = await _stopRecorder();
    _recordingFilePath = null;

    final word = _currentQueue[_currentWordIndex];
    final normalizedTranscript = transcript.trim().toLowerCase();
    final duration = _listeningStartedAt != null ? DateTime.now().difference(_listeningStartedAt!) : null;

    try {
    final assessor = AssessorFactory.create();
    final result = await assessor.assess(
      referenceText: word.text,
      transcript: transcript, // pass actual STT transcript
      locale: 'en-US',
    );

    final accuracy = result.accuracy ?? 0.0;
    final score = result.score;
    final isCorrect = accuracy >= _masteryThreshold; // Uses result.accuracy
    final feedback = result.feedback;

    setState(() {
      _isListening = false;
      _isProcessing = true;
      _lastTranscript = result.transcript;
      _lastAccuracy = accuracy;
      _lastWasCorrect = isCorrect;
      _feedbackMessage = feedback;
      _phonemeFeedback = result.phonemeFeedback;
    });

    final saveSucceeded = await _saveAttempt(
      attemptController,
      word: word.text,
      score: score,
      feedback: feedback,
      transcript: normalizedTranscript,
      accuracy: accuracy,
      duration: duration,
      audioFilePath: audioFilePath,
    );
    if (!saveSucceeded) {
      return;
    }

    if (isCorrect) {
      await _markWordMastered(word);
      await Future.delayed(const Duration(milliseconds: 600));
      _advanceToNextWord(removeCurrent: true);
    } else {
      _advanceToNextWord(removeCurrent: false);
    }
  } catch (e) {
    // If there's an error, fallback to mock results
    final fallbackScore = 70;
    final fallbackAccuracy = 0.7;
    final isCorrect = false;
    final fallbackFeedback = 'We made a mistake. It\'s not your fault. Say it again';
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _lastAccuracy = fallbackAccuracy;
      _lastWasCorrect = isCorrect;
      _feedbackMessage = fallbackFeedback;
    });
    final fallbackSaved = await _saveAttempt(
      attemptController,
      word: word.text,
      score: fallbackScore,
      feedback: fallbackFeedback,
      transcript: normalizedTranscript,
      accuracy: fallbackAccuracy,
      duration: duration,
      audioFilePath: audioFilePath,
    );
    if (!fallbackSaved) {
      return;
    }
    _advanceToNextWord(removeCurrent: false);
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  Future<bool> _saveAttempt(
    AttemptController controller, {
    required String word,
    required int score,
    required String feedback,
    required String transcript,
    required double accuracy,
    required Duration? duration,
    required String? audioFilePath,
  }) async {
    try {
      await controller.addAttempt(
        word: word,
        score: score,
        feedback: feedback,
        transcript: transcript,
        accuracy: accuracy,
        duration: duration,
        audioFilePath: audioFilePath,
      );
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'We could not save your recording. Please check your connection and try again.';
          _processedCurrentAttempt = false;
        });
      } else {
        _processedCurrentAttempt = false;
      }
      return false;
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

  @override
  Widget build(BuildContext context) {
    final attemptController = context.watch<AttemptController>();

    if (_loading) {
      return _buildPracticePage(const Center(child: CupertinoActivityIndicator()));
    }

    if (_micPermission?.isPermanentlyDenied == true ||
        _speechPermission?.isPermanentlyDenied == true) {
      return _buildPermissionPage(
        message:
            'Speech recognition permissions are blocked. Please enable them in Settings to continue practicing.',
      );
    }

    if (!_speechReady) {
      return _buildPermissionPage(
        message: _errorMessage ?? 'Tap the button below to enable speech recognition.',
      );
    }

    if (_allListsComplete) {
      return _buildPracticePage(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _CupertinoCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(CupertinoIcons.star_circle, color: CupertinoColors.systemYellow, size: 64),
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
      );
    }

    if (_currentQueue.isEmpty) {
      return _buildPracticePage(const Center(child: CupertinoActivityIndicator()));
    }

    final currentList = _wordLists[_currentListIndex];
    final currentWord = _currentQueue[_currentWordIndex];
    final masteredCount = currentList.items
        .where((item) => _isWordMastered(currentList.id, item.text))
        .length;
    final totalCount = currentList.items.length;

    return _buildPracticePage(
      Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  if (_errorMessage != null && !_isListening) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: CupertinoColors.destructiveRed),
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
                      phonemeFeedback: _phonemeFeedback,
                    ),
                  ],
                  if (_lastWasCorrect == false && !_isListening && !_isProcessing) ...[
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: _startListening,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _RecordingBar(
            isListening: _isListening,
            isProcessing: _isProcessing || attemptController.isSaving,
            remainingSeconds: _remainingSeconds,
            onRecordPressed: _isListening
                ? () => _stopListening(auto: false)
                : () => _startListening(),
            canPress: !_isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPage({required String message}) {
    return _buildPracticePage(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _CupertinoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.mic_slash_fill, size: 64, color: CupertinoColors.destructiveRed),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: () => _initSpeech(force: true),
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPracticePage(Widget child) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Practice'),
      ),
      child: SafeArea(child: child),
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
    final double progress = totalCount == 0 ? 0.0 : (masteredCount / totalCount).clamp(0.0, 1.0).toDouble();
    final textTheme = CupertinoTheme.of(context).textTheme;

    return _CupertinoCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'List $listPosition of $totalLists',
            style: textTheme.textStyle.copyWith(color: CupertinoColors.activeBlue),
          ),
          const SizedBox(height: 4),
          Text(
            listTitle,
            style: textTheme.navTitleTextStyle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: CupertinoColors.systemGrey5),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(color: CupertinoColors.activeBlue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$masteredCount of $totalCount words mastered'),
        ],
      ),
    );
  }
}

class _WordCard extends StatefulWidget {
  final WordItem word;

  const _WordCard({required this.word});

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _showSentences = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return _CupertinoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'let\'s say',
            style: textTheme.textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
          ),

          const SizedBox(height: 4),

          // BIG WORD
          Text(
            widget.word.text.toUpperCase(),
            style: textTheme.navLargeTitleTextStyle.copyWith(fontSize: 36),
          ),

          const SizedBox(height: 12),

          // ⭐ PNG IMAGE FOR THE WORD CARD
          Center(
            child: SizedBox(
              height: 140, // adjust as needed
              child: Image.asset(
                'assets/icons/education.png',   // <-- your PNG here
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // SAMPLE SENTENCES BUTTON
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _showSentences = !_showSentences),
            child: Row(
              children: [
                const Icon(CupertinoIcons.book_solid,
                    size: 20, color: CupertinoColors.activeBlue),
                const SizedBox(width: 8),
                Text(
                  'Sample sentences',
                  style: textTheme.textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  _showSentences ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 18,
                  color: CupertinoColors.inactiveGray,
                ),
              ],
            ),
          ),

          // SENTENCES LIST
          if (_showSentences) ...[
            const SizedBox(height: 8),
            ...widget.word.sampleSentences.map(
              (sentence) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(sentence, style: textTheme.textStyle),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _RecordingBar extends StatelessWidget {
  final bool isListening;
  final bool isProcessing;
  final int remainingSeconds;
  final Future<void> Function() onRecordPressed;
  final bool canPress;

  const _RecordingBar({
    required this.isListening,
    required this.isProcessing,
    required this.remainingSeconds,
    required this.onRecordPressed,
    required this.canPress,
  });

  @override
  Widget build(BuildContext context) {
    final label = isListening ? 'Stop' : 'Record';
    final icon = isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic;
    final statusText = isListening
        ? 'Listening... $remainingSeconds s'
        : isProcessing
            ? 'Checking how it sounded...'
            : 'Tap the button and say the word!';

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: CupertinoColors.systemGrey5,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey3,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  onPressed: canPress ? () => onRecordPressed() : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                statusText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
  final String? phonemeFeedback;

  const _ResultSummary({
    required this.transcript,
    required this.feedback,
    required this.accuracy,
    required this.wasCorrect,
    required this.phonemeFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final scoreText = 'Score: ${(accuracy * 100).clamp(0, 100).round()}%';
    final color = wasCorrect == true
        ? CupertinoColors.activeGreen
        : wasCorrect == false
            ? CupertinoColors.systemOrange
            : CupertinoColors.label;

    final textTheme = CupertinoTheme.of(context).textTheme;

    // Headline & helper
    final headline = wasCorrect == true ? 'Nice reading!' : 'Keep trying!';
    final helper = wasCorrect == true
        ? 'You said it just right.'
        : 'Listen carefully and give it another go.';

    return _CupertinoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline
          Center(
            child: Text(
              headline,
              style: textTheme.navTitleTextStyle.copyWith(
                fontSize: 24,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // ⭐ Show different PNG depending on correct / incorrect
          if (wasCorrect == true) ...[
            Center(
              child: SizedBox(
                height: 140,
                child: Image.asset(
                  'assets/icons/trophy.png',    // <<< correct image
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else if (wasCorrect == false) ...[
            Center(
              child: SizedBox(
                height: 140,
                child: Image.asset(
                  'assets/icons/back-to-school.png',   // <<< incorrect image
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Helper line
          Text(
            helper,
            style: textTheme.textStyle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),

          // Score
          Text(
            scoreText,
            style: textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // Feedback text
          Text(
            feedback,
            style: textTheme.textStyle.copyWith(fontSize: 18),
          ),

          // Transcript shown only when incorrect
          if (transcript.isNotEmpty && wasCorrect != true) ...[
            const SizedBox(height: 14),
            Text(
              'You said:',
              style: textTheme.textStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              transcript,
              style: textTheme.textStyle.copyWith(fontSize: 16),
            ),
          ],

          // Phoneme tip
          if (phonemeFeedback != null && phonemeFeedback!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Tip: $phonemeFeedback',
              style: textTheme.textStyle.copyWith(
                color: CupertinoColors.activeBlue,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// ✅ Now we start the card class
class _CupertinoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CupertinoCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: CupertinoColors.systemGrey4,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}


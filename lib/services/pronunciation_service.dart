import 'dart:math';
import 'dart:typed_data';

class AssessmentResult {
  final int score;
  final String feedback;
  final String transcript;
  final double? accuracy; // percentage
  final String? phonemeFeedback;

  const AssessmentResult({
    required this.score,
    required this.feedback,
    required this.transcript,
    this.accuracy,
    this.phonemeFeedback,
  });
}

abstract class PronunciationAssessor {
  Future<AssessmentResult> assess({
    required String referenceText,
    String? transcript, 
    Uint8List? audioBytes,
    String locale = 'en-US',
  });
}

// Offline STT
class LocalPronunciationAssessor implements PronunciationAssessor {
  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    String? transcript,
    Uint8List? audioBytes,
    String locale = 'en-US',
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Mimic processing

    // Use passed transcript or fallback mock
    final effectiveTranscript = transcript ?? _mockTranscript(referenceText);
    final normalizedRef = referenceText.toLowerCase().trim();
    final normalizedTrans = effectiveTranscript.toLowerCase().trim();

    final accuracy = _calculateSimilarity(normalizedRef, normalizedTrans);
    final score = (accuracy * 100).round().clamp(0, 100);

    final phonemeFb = _generatePhonemeFeedback(normalizedRef, normalizedTrans, accuracy);
    final feedback = _generateFeedback(score, phonemeFb);

    return AssessmentResult(
      score: score,
      feedback: feedback,
      transcript: effectiveTranscript,
      accuracy: accuracy,
      phonemeFeedback: phonemeFb,
    );
  }

  String _mockTranscript(String ref) {
    // Fallback mock if no transcript passed
    final variations = {
      'cat': ['cat', 'kat', 'cad'],
      'dog': ['dog', 'dawg', 'dag'],
      'the': ['the', 'duh', 'tee'],
      // Add more from csv
    };
    return variations[ref.toLowerCase()]?.elementAt(Random().nextInt(variations[ref.toLowerCase()]!.length)) ?? ref;
  }

  double _calculateSimilarity(String expected, String actual) {
    if (expected.isEmpty || actual.isEmpty) return 0;
    if (expected == actual) return 1.0;

    final m = expected.length;
    final n = actual.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
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

  String? _generatePhonemeFeedback(String ref, String trans, double accuracy) {
    if (accuracy > 0.9) return null; // No hint needed

    final vowels = 'aeiou';
    final refVowels = ref.runes.where((r) => vowels.contains(String.fromCharCode(r))).length;
    final transVowels = trans.runes.where((r) => vowels.contains(String.fromCharCode(r))).length;

    if (refVowels != transVowels) {
      return 'Vowel sounds off (expected $refVowels, got $transVowels)';
    }

    // Basic consonant check
    final refCons = ref.length - refVowels;
    final transCons = trans.length - transVowels;
    if (refCons != transCons) {
      return 'Try again';
    }

    return 'Speak slower';
  }

  String _generateFeedback(int score, String? phonemeHint) {
    String base;
    if (score >= 90) { base = 'Amazing!'; }
    else if (score >= 80) { base = 'Great!'; }
    else if (score >= 70) { base = 'Good!'; }
    else { base = 'Try again'; }

    if (phonemeHint != null) base += ' $phonemeHint';
    return base;
  }
}

// Mock Fallback
class MockPronunciationAssessor implements PronunciationAssessor {
  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    String? transcript,
    Uint8List? audioBytes,
    String locale = 'en-US',
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final score = Random().nextInt(46) + 55; // 55-100
    final feedback = score >= 70 ? 'Excellent!' : 'Try again';
    final effectiveTranscript = transcript ?? referenceText;
    return AssessmentResult(
      score: score,
      feedback: feedback,
      transcript: effectiveTranscript,
    );
  }
}

// Offline factory
class AssessorFactory {
  static PronunciationAssessor create() => LocalPronunciationAssessor();
}
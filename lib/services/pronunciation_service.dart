import 'dart:math';
import 'dart:typed_data';

class AssessmentResult {
  final int score;
  final String feedback;
  final String transcript;

  const AssessmentResult({
    required this.score,
    required this.feedback,
    required this.transcript,
  });
}

abstract class PronunciationAssessor {
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale,
  });
}

class MockPronunciationAssessor implements PronunciationAssessor {
  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final normalized = referenceText.trim().toLowerCase();
    final audioEnergy = audioBytes.isEmpty
        ? 0
        : audioBytes.fold<int>(0, (sum, byte) => sum + byte.abs()) ~/ audioBytes.length;
    final baseline = (normalized.replaceAll(RegExp(r'[^a-z]'), '').length * 7).clamp(20, 60);
    final energyScore = (audioEnergy / 3).clamp(0, 35).toInt();
    final random = Random(normalized.hashCode ^ audioBytes.length).nextInt(15);
    final rawScore = baseline + energyScore + random;
    final score = rawScore.clamp(55, 99);

    final feedback = _feedbackForScore(score);

    return AssessmentResult(
      score: score,
      feedback: feedback,
      transcript: normalized,
    );
  }

  String _feedbackForScore(int score) {
    if (score >= 90) {
      return 'Excellent pronunciation!';
    } else if (score >= 80) {
      return 'Great job! Keep practicing for a perfect score.';
    } else if (score >= 70) {
      return 'Pretty good. Try speaking a little clearer next time.';
    } else {
      return 'Let\'s try again. Focus on each sound of the word.';
    }
  }
}

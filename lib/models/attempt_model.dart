class Attempt {
  final String id;
  final String wordText;
  final int score;
  final String feedback;
  final DateTime createdAt;
  final String? transcript;
  final double? accuracy;
  final Duration? duration;
  final String? audioPath;

  const Attempt({
    required this.id,
    required this.wordText,
    required this.score,
    required this.feedback,
    required this.createdAt,
    this.transcript,
    this.accuracy,
    this.duration,
    this.audioPath,
  });

  // Value equality for testing
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attempt &&
        other.id == id &&
        other.wordText == wordText &&
        other.score == score &&
        other.feedback == feedback &&
        other.createdAt == createdAt &&
        other.transcript == transcript &&
        other.accuracy == accuracy &&
        other.duration == duration &&
        other.audioPath == audioPath;
  }

  // Hashcodes for testing
  @override
  int get hashCode {
    return id.hashCode ^
        wordText.hashCode ^
        score.hashCode ^
        feedback.hashCode ^
        createdAt.hashCode ^
        transcript.hashCode ^
        accuracy.hashCode ^
        duration.hashCode ^
        audioPath.hashCode;
  }
}
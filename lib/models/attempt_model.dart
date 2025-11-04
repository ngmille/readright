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
}

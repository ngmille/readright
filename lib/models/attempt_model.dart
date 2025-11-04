class Attempt {
  final String id;
  final String wordText;
  final int score;
  final String feedback;
  final DateTime createdAt;

  const Attempt({
    required this.id,
    required this.wordText,
    required this.score,
    required this.feedback,
    required this.createdAt,
  });
}
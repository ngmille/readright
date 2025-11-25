class Attempt {
  final String id;
  final String wordText;
  final int score;
  final String feedback;
  final DateTime createdAt;
  final String? transcript;
  final double? accuracy;
  final Duration? duration;
  final String? audioUrl;

  const Attempt({
    required this.id,
    required this.wordText,
    required this.score,
    required this.feedback,
    required this.createdAt,
    this.transcript,
    this.accuracy,
    this.duration,
    this.audioUrl,
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
        other.audioUrl == audioUrl;
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
        audioUrl.hashCode;
  }

  Attempt copyWith({
    String? id,
    String? wordText,
    int? score,
    String? feedback,
    DateTime? createdAt,
    String? transcript,
    double? accuracy,
    Duration? duration,
    String? audioUrl,
  }) {
    return Attempt(
      id: id ?? this.id,
      wordText: wordText ?? this.wordText,
      score: score ?? this.score,
      feedback: feedback ?? this.feedback,
      createdAt: createdAt ?? this.createdAt,
      transcript: transcript ?? this.transcript,
      accuracy: accuracy ?? this.accuracy,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wordText': wordText,
      'score': score,
      'feedback': feedback,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'transcript': transcript,
      'accuracy': accuracy,
      'durationMillis': duration?.inMilliseconds,
      'audioUrl': audioUrl,
    };
  }

  factory Attempt.fromMap(String id, Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.parse(createdAtRaw).toLocal();
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    } else {
      createdAt = DateTime.now();
    }

    return Attempt(
      id: id,
      wordText: data['wordText'] as String? ?? '',
      score: (data['score'] as num?)?.round() ?? 0,
      feedback: data['feedback'] as String? ?? '',
      createdAt: createdAt,
      transcript: data['transcript'] as String?,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      duration: data['durationMillis'] != null
          ? Duration(milliseconds: (data['durationMillis'] as num).round())
          : null,
      audioUrl: (data['audioUrl'] as String?) ?? (data['audioPath'] as String?),
    );
  }
}

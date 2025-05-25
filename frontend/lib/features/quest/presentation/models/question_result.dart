class QuestionResult {
  final String questionText;
  final String selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final int pointsEarned;

  QuestionResult({
    required this.questionText,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.pointsEarned,
  });
} 
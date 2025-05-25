class QuestHighlight {
  final String title;
  final String subtitle;
  final String imagePath;
  final bool isCompleted;

  const QuestHighlight({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.isCompleted = true,
  });
}

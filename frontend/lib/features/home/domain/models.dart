class UserProfile {
  final String username;
  final String avatarUrl; // Can be a local asset or network URL
  final String title; // e.g., GRAND MASTER
  final int currentXp;
  final int currentLevel;
  final int xpToNextLevel;
  final int totalXpForCurrentLevel; // For progress bar calculation

  UserProfile({
    required this.username,
    required this.avatarUrl,
    required this.title,
    required this.currentXp,
    required this.currentLevel,
    required this.xpToNextLevel,
    required this.totalXpForCurrentLevel,
  });

  // Helper to get progress for the XP bar (0.0 to 1.0)
  double get levelProgress {
    if (xpToNextLevel <= totalXpForCurrentLevel) {
      return 1.0; // Should not happen if data is correct
    }
    final currentLevelXp = currentXp - totalXpForCurrentLevel;
    final neededForLevel = xpToNextLevel - totalXpForCurrentLevel;
    if (neededForLevel == 0) return 1.0;
    return (currentLevelXp / neededForLevel).clamp(0.0, 1.0);
  }
}

// Renaming FeaturedQuest to QuestInfo for more general use in lists
class QuestInfo {
  final String id;
  final String title;
  final String subtitle;
  final String iconAssetPath; // e.g., path to a trophy icon
  final int currentPoints;
  final int totalPoints;

  QuestInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconAssetPath,
    required this.currentPoints,
    required this.totalPoints,
  });

  double get progress {
    if (totalPoints == 0) return 0.0;
    return (currentPoints / totalPoints).clamp(0.0, 1.0);
  }
}

class PopularLocation {
  // Reusing PopularArea as PopularLocation
  final String id;
  final String name;
  final String imagePath; // Local asset or network URL

  PopularLocation({
    required this.id,
    required this.name,
    required this.imagePath,
  });
}

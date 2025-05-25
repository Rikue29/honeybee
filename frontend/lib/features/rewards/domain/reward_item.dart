class RewardItem {
  final String id;
  final String title;
  final String description;
  final String imagePath; // Can be a local asset or a network URL
  final int tokenCost;
  final int expiresInDays;
  final String category;
  final String? specialProviderLogo; // For logos like 'PahangGo'

  RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.tokenCost,
    required this.expiresInDays,
    required this.category,
    this.specialProviderLogo,
  });
}

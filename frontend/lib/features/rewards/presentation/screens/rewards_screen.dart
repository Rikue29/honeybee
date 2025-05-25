import 'package:flutter/material.dart';
import 'package:honeybee/features/rewards/domain/reward_item.dart';
// import '../widgets/reward_card.dart'; // Will create this next

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final List<RewardItem> _allRewards = [
    // Dummy Data - Replace with your actual data source
    RewardItem(
      id: '1',
      title: '15% Off at Warung Pekan Lama',
      description: 'Get 15% off on any main dish',
      imagePath: 'assets/images/warung_pekan_lama.png', // Placeholder
      tokenCost: 2,
      expiresInDays: 7,
      category: 'Food',
    ),
    RewardItem(
      id: '2',
      title: 'Free Parking Coupon',
      description: 'Exclusive parking coupon limited to Pahang only',
      imagePath: 'assets/images/pahang_go_coupon.png', // Placeholder
      tokenCost: 1,
      expiresInDays: 30,
      category: 'Transport',
    ),
    RewardItem(
      id: '3',
      title: 'Museum Guided Tour',
      description: 'Use at Museum in Pahang',
      imagePath: 'assets/images/museum_tour.png', // Placeholder
      tokenCost: 3,
      expiresInDays: 14,
      category: 'Activities',
    ),
    // Add more dummy rewards...
  ];

  List<RewardItem> _filteredRewards = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _userTokens = 5; // Dummy user tokens

  @override
  void initState() {
    super.initState();
    _filteredRewards = _allRewards;
  }

  void _filterRewards() {
    setState(() {
      List<RewardItem> tempRewards = _allRewards;
      if (_selectedCategory != 'All') {
        tempRewards = tempRewards
            .where((reward) => reward.category == _selectedCategory)
            .toList();
      }
      if (_searchQuery.isNotEmpty) {
        tempRewards = tempRewards
            .where((reward) =>
                reward.title
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                reward.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();
      }
      _filteredRewards = tempRewards;
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterRewards();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterRewards();
    });
  }

  void _claimReward(RewardItem reward) {
    if (_userTokens >= reward.tokenCost) {
      setState(() {
        _userTokens -= reward.tokenCost;
        // TODO: Add logic to mark reward as claimed, update backend, etc.
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${reward.title} claimed!'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Not enough tokens to claim ${reward.title}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor =
        const Color(0xFFF5A623); // Main orange color from image
    final Color backgroundColor =
        const Color(0xFFFFF3E0); // Light yellow background
    final Color cardBackgroundColor = Colors.white;
    final Color chipSelectedColor = primaryColor;
    final Color chipUnselectedColor = Colors.grey[200]!;
    final Color chipSelectedTextColor = Colors.white;
    final Color chipUnselectedTextColor = Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        centerTitle: true,
        title: Text(
          'Rewards',
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(Icons.monetization_on_rounded,
                    color: primaryColor, size: 22),
                const SizedBox(width: 4),
                Text(
                  '$_userTokens Tokens',
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ],
        iconTheme:
            IconThemeData(color: Colors.black87), // For back button if needed
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search rewards...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Filter Chips
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                      'All',
                      Icons.all_inclusive_rounded,
                      chipSelectedColor,
                      chipUnselectedColor,
                      chipSelectedTextColor,
                      chipUnselectedTextColor),
                  _buildFilterChip(
                      'Food',
                      Icons.fastfood_rounded,
                      chipSelectedColor,
                      chipUnselectedColor,
                      chipSelectedTextColor,
                      chipUnselectedTextColor),
                  _buildFilterChip(
                      'Transport',
                      Icons.directions_bus_rounded,
                      chipSelectedColor,
                      chipUnselectedColor,
                      chipSelectedTextColor,
                      chipUnselectedTextColor),
                  _buildFilterChip(
                      'Activities',
                      Icons.local_activity_rounded,
                      chipSelectedColor,
                      chipUnselectedColor,
                      chipSelectedTextColor,
                      chipUnselectedTextColor),
                  // Add more categories as needed
                ],
              ),
            ),
          ),

          // Rewards List
          Expanded(
            child: _filteredRewards.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty || _selectedCategory != 'All'
                          ? 'No rewards found for your criteria.'
                          : 'No rewards available at the moment.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredRewards.length,
                    itemBuilder: (context, index) {
                      final reward = _filteredRewards[index];
                      return _buildRewardCard(
                          reward, cardBackgroundColor, primaryColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label,
      IconData icon,
      Color selectedColor,
      Color unselectedColor,
      Color selectedTextColor,
      Color unselectedTextColor) {
    bool isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(icon,
            color: isSelected
                ? selectedTextColor
                : unselectedTextColor.withOpacity(0.7)),
        selected: isSelected,
        onSelected: (selected) {
          _onCategorySelected(label);
        },
        backgroundColor: unselectedColor,
        selectedColor: selectedColor,
        labelStyle: TextStyle(
          color: isSelected ? selectedTextColor : unselectedTextColor,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isSelected ? selectedColor : Colors.grey[300]!,
              width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildRewardCard(
      RewardItem reward, Color cardBackgroundColor, Color primaryColor) {
    return Card(
      color: cardBackgroundColor,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
            // AspectRatio to maintain image proportions if needed
            child: AspectRatio(
              aspectRatio: 16 / 7, // Adjust as per your image aspect ratios
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    reward.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported_rounded,
                            color: Colors.grey[500], size: 40),
                      );
                    },
                  ),
                  if (reward.specialProviderLogo != null)
                    Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(6)),
                            child: Image.asset(
                              reward.specialProviderLogo!,
                              height: 24,
                              width: 60,
                              fit: BoxFit.contain,
                            )))
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  reward.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expires in ${reward.expiresInDays} days',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.monetization_on_rounded,
                                color: Colors.amber[700], size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${reward.tokenCost}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _claimReward(reward),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: const Text('Claim Reward',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

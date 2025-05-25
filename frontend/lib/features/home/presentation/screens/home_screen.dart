import 'package:flutter/material.dart';
import 'package:honeybee/features/home/domain/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Dummy Data for the new UI - this remains
  final UserProfile _user = UserProfile(
    username: 'MERLIN',
    avatarUrl: 'assets/images/user_merlin_avatar.png',
    title: 'GRAND MASTER',
    currentXp: 20000,
    currentLevel: 10,
    totalXpForCurrentLevel: 18000,
    xpToNextLevel: 22000,
  );

  final List<QuestInfo> _ongoingQuests = [
    QuestInfo(
        id: 'ongoing1',
        title: 'Royal Heritage Trail',
        subtitle: 'Explore the royal history of Pekan',
        iconAssetPath: 'assets/images/trophy_icon.png',
        currentPoints: 100,
        totalPoints: 150),
  ];

  final List<QuestInfo> _savedQuests = [
    QuestInfo(
        id: 'saved1',
        title: 'Culinary Adventure',
        subtitle: 'Taste the best local dishes in Pekan',
        iconAssetPath: 'assets/images/trophy_icon.png',
        currentPoints: 0,
        totalPoints: 120),
  ];

  final List<PopularLocation> _popularLocations = [
    PopularLocation(
        id: 'loc1',
        name: 'Sultan Abu Bakar Museum',
        imagePath: 'assets/images/museum_tour.png'),
    PopularLocation(
        id: 'loc2',
        name: 'Pekan Waterfront',
        imagePath: 'assets/images/location_waterfront.JPG'),
    PopularLocation(
        id: 'loc3',
        name: 'Traditional Market',
        imagePath: 'assets/images/location_market.jpg'),
  ];

  @override
  Widget build(BuildContext context) {
    final Color primaryColor =
        const Color(0xFFFBC02D); // Main Yellow/Gold from image
    final Color secondaryColor = const Color(0xFFFFF9C4); // Lighter Yellow
    final Color tertiaryColor = const Color(0xFF795548); // Brown for text/icons
    final Color backgroundColor =
        const Color(0xFFFFFDE7); // Very light yellow background
    final Color progressColor =
        const Color(0xFFFF8F00); // Orange for progress bars

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ListView(
          // Using ListView for overall scrollability
          padding: const EdgeInsets.all(0), // No padding for ListView itself
          children: [
            _buildTopBar(tertiaryColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildUserProfileCard(_user, primaryColor, secondaryColor,
                      tertiaryColor, progressColor),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Ongoing Quests', tertiaryColor),
                  const SizedBox(height: 12),
                  ..._ongoingQuests
                      .map((quest) => _buildQuestCard(
                          quest, progressColor, tertiaryColor, backgroundColor))
                      .toList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Saved Quests', tertiaryColor),
                  const SizedBox(height: 12),
                  ..._savedQuests
                      .map((quest) => _buildQuestCard(
                          quest, progressColor, tertiaryColor, backgroundColor))
                      .toList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Popular Locations', tertiaryColor),
                  const SizedBox(height: 16),
                  _buildPopularLocationsList(_popularLocations, tertiaryColor),
                  const SizedBox(
                      height: 30), // Space for bottom nav bar if added later
                ],
              ),
            ),
          ],
        ),
      ),
      // BottomNavigationBar would be added here if implementing full navigation
    );
  }

  Widget _buildTopBar(Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Welcome!',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Image.asset('assets/images/bee-flying.png',
                      height: 28), // Placeholder bee icon
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Discover Pekan\'s treasures',
                style:
                    TextStyle(fontSize: 15, color: iconColor.withOpacity(0.7)),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.search, color: iconColor, size: 28),
                onPressed: () {/* TODO: Search action */},
                tooltip: 'Search',
              ),
              const SizedBox(width: 0),
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: iconColor, size: 28),
                onPressed: () {/* TODO: Notification action */},
                tooltip: 'Notifications',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(UserProfile user, Color primaryBg,
      Color secondaryBg, Color textColor, Color progressColor) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: null, // Use gradient instead
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFBC02D), // Yellow
              Color(0xFFFFA726), // Orange
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 2.0, right: 16.0, left: 2.0),
                    child: Image.asset(
                      user.avatarUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, size: 28, color: Colors.white70),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(user.title,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.topRight,
                    child: Text('${user.currentXp} XP',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Level ${user.currentLevel}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                  const Spacer(),
                  Text('Level ${user.currentLevel + 1}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: user.levelProgress,
                backgroundColor: const Color(0xFFFFECB3),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF8D5A00)),
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 18),
              Center(
                child: ElevatedButton(
                  onPressed: () {/* TODO: My Rewards action */},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8D5A00),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  child: const Text('My Rewards'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/journey-completed');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('Test: Go to Journey Completed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.bold, color: textColor),
    );
  }

  Widget _buildQuestCard(QuestInfo quest, Color progressColor, Color textColor,
      Color cardBgColor) {
    return Card(
      elevation: 1.5,
      color: Colors.white, // Slightly whiter than main background for contrast
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {/* TODO: Quest details action */},
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: cardBgColor.withOpacity(
                      0.7), // Use lighter cardBg for icon background
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Image.asset(quest.iconAssetPath,
                    height: 24,
                    width: 24,
                    color: progressColor), // Placeholder trophy icon
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 2),
                    Text(quest.subtitle,
                        style: TextStyle(
                            fontSize: 13, color: textColor.withOpacity(0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: quest.progress,
                            backgroundColor: progressColor.withOpacity(0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${quest.currentPoints} pts',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: progressColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularLocationsList(
      List<PopularLocation> locations, Color textColor) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          return SizedBox(
            width: 140,
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
              margin: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () {/* TODO: Popular Location action */},
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // Make image stretch
                  children: [
                    Expanded(
                      flex: 3, // Give more space to image
                      child: Image.asset(
                        location.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported_rounded,
                                  size: 40, color: Colors.grey[400]));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        location.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

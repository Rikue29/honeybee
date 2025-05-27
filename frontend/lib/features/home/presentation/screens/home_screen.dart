import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_page.dart';
import 'package:honeybee/features/explore/screens/explore_screen.dart';
import 'package:honeybee/features/video_feed/pages/video_feed_page.dart';
import 'package:honeybee/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:honeybee/features/quest/services/quest_service.dart';
import '../../domain/models.dart';

// Placeholder classes based on usage
class UserProfile {
  final String username;
  final String avatarUrl;
  final String title;
  final int currentXp;
  final int currentLevel;
  final int totalXpForCurrentLevel;
  final int xpToNextLevel;

  UserProfile({
    required this.username,
    required this.avatarUrl,
    required this.title,
    required this.currentXp,
    required this.currentLevel,
    required this.totalXpForCurrentLevel,
    required this.xpToNextLevel,
  });

  double get levelProgress => (xpToNextLevel - totalXpForCurrentLevel == 0)
      ? 0
      : (currentXp - totalXpForCurrentLevel) /
          (xpToNextLevel - totalXpForCurrentLevel);
}

class PopularLocation {
  final String id;
  final String name;
  final String imagePath;

  PopularLocation({
    required this.id,
    required this.name,
    required this.imagePath,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late LocationService _locationService;
  final QuestService _questService = QuestService();
  List<QuestInfo> _ongoingQuests = [];
  List<QuestInfo> _savedQuests = [];
  bool _isLoading = true;

  // Dummy Data for the new UI - this remains
  final UserProfile _user = UserProfile(
    username: 'rikuekue',
    avatarUrl: 'assets/images/user_merlin_avatar.png',
    title: 'GRAND MASTER',
    currentXp: 20000,
    currentLevel: 10,
    totalXpForCurrentLevel: 18000,
    xpToNextLevel: 22000,
  );

  final List<PopularLocation> _popularLocations = [
    PopularLocation(
        id: 'loc1',
        name: 'Sultan Abu Bakar Museum',
        imagePath: 'assets/images/museum_tour.png'),
    PopularLocation(
        id: 'loc2',
        name: 'Pekan Riverfront',
        imagePath: 'assets/images/location_waterfront.JPG'),
    PopularLocation(
        id: 'loc3',
        name: 'Masjid Sultan Abdullah',
        imagePath: 'assets/images/masjid_sultan_abdullah.png'),
    PopularLocation(
        id: 'loc4',
        name: 'Abu Bakar Palace',
        imagePath: 'assets/images/istana_abubakar.png'),
  ];

  @override
  void initState() {
    super.initState();
    print("[HomeScreen] initState called");
    _locationService = LocationService();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    print("[HomeScreen] Starting to load quests");
    try {
      final ongoingQuestsJson = await _questService.getOngoingQuests();
      final savedQuestsJson = await _questService.getSavedQuests();

      print(
          "[HomeScreen] Fetched ${ongoingQuestsJson.length} ongoing and ${savedQuestsJson.length} saved quests");

      if (mounted) {
        print("[HomeScreen] Converting quests to QuestInfo objects");
        final ongoingQuests = ongoingQuestsJson
            .map((q) => _questService.questFromJson(q))
            .toList();
        final savedQuests =
            savedQuestsJson.map((q) => _questService.questFromJson(q)).toList();

        print(
            "[HomeScreen] Setting state with ${ongoingQuests.length} ongoing and ${savedQuests.length} saved quests");
        setState(() {
          _ongoingQuests = ongoingQuests;
          _savedQuests = savedQuests;
          _isLoading = false;
        });
        print("[HomeScreen] State updated successfully");
      } else {
        print("[HomeScreen] Widget not mounted, skipping state update");
      }
    } catch (e, stackTrace) {
      print('[HomeScreen] Error loading quests: $e');
      print('[HomeScreen] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHomePageView(
      UserProfile user,
      List<QuestInfo> ongoingQuests,
      List<QuestInfo> savedQuests,
      List<PopularLocation> popularLocations,
      Color primaryColor,
      Color secondaryColor,
      Color tertiaryColor,
      Color backgroundColor,
      Color progressColor) {
    print(
        "[HomeScreen] Building home page view with ${ongoingQuests.length} ongoing and ${savedQuests.length} saved quests");
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          _buildTopBar(tertiaryColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildUserProfileCard(user, primaryColor, secondaryColor,
                    tertiaryColor, progressColor),
                const SizedBox(height: 24),
                _buildSectionTitle('Ongoing Quests', tertiaryColor),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  if (_isLoading) {
                    print(
                        "[HomeScreen] Showing loading indicator for ongoing quests");
                    return const Center(child: CircularProgressIndicator());
                  } else if (ongoingQuests.isEmpty) {
                    print("[HomeScreen] Showing no ongoing quests message");
                    return Center(
                      child: Text(
                        'No ongoing quests',
                        style: TextStyle(color: tertiaryColor.withOpacity(0.6)),
                      ),
                    );
                  } else {
                    print(
                        "[HomeScreen] Building ${ongoingQuests.length} ongoing quest cards");
                    return Column(
                      children: ongoingQuests
                          .map((quest) => _buildQuestCard(quest, progressColor,
                              tertiaryColor, backgroundColor))
                          .toList(),
                    );
                  }
                }),
                const SizedBox(height: 24),
                _buildSectionTitle('Saved Quests', tertiaryColor),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  if (_isLoading) {
                    print(
                        "[HomeScreen] Showing loading indicator for saved quests");
                    return const Center(child: CircularProgressIndicator());
                  } else if (savedQuests.isEmpty) {
                    print("[HomeScreen] Showing no saved quests message");
                    return Center(
                      child: Text(
                        'No saved quests',
                        style: TextStyle(color: tertiaryColor.withOpacity(0.6)),
                      ),
                    );
                  } else {
                    print(
                        "[HomeScreen] Building ${savedQuests.length} saved quest cards");
                    return Column(
                      children: savedQuests
                          .map((quest) => _buildQuestCard(quest, progressColor,
                              tertiaryColor, backgroundColor))
                          .toList(),
                    );
                  }
                }),
                const SizedBox(height: 24),
                _buildSectionTitle('Popular Locations', tertiaryColor),
                const SizedBox(height: 16),
                _buildPopularLocationsList(popularLocations, tertiaryColor),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFBC02D); // Main Yellow/Gold from image
    const Color secondaryColor = Color(0xFFFFF9C4); // Lighter Yellow
    const Color tertiaryColor = Color(0xFF795548); // Brown for text/icons
    const Color backgroundColor =
        Color(0xFFFFFDE7); // Very light yellow background
    const Color progressColor = Color(0xFFFF8F00); // Orange for progress bars

    final List<Widget> pages = [
      _buildHomePageView(
          _user,
          _ongoingQuests,
          _savedQuests,
          _popularLocations,
          primaryColor,
          secondaryColor,
          tertiaryColor,
          backgroundColor,
          progressColor),
      const QuestPage(), // For creating/viewing quests
      const VideoFeedPage(),
      const ExploreScreen(),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Visibility(
            visible: _selectedIndex == 0,
            maintainState: true,
            child: pages[0],
          ),
          Visibility(
            visible: _selectedIndex == 1,
            maintainState: false, // Don't maintain state for Quest page
            child: pages[1],
          ),
          Visibility(
            visible: _selectedIndex == 2,
            maintainState:
                false, // Don't maintain state for Video Feed to prevent background playback
            child: pages[2],
          ),
          Visibility(
            visible: _selectedIndex == 3,
            maintainState: true,
            child: pages[3],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 0 && _selectedIndex != 0) {
            _loadQuests();
          }
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: tertiaryColor,
        unselectedItemColor: tertiaryColor.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag_outlined),
            label: 'Quest',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_filled_outlined),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
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
              const SizedBox(width: 0),
              IconButton(
                icon: Icon(Icons.logout_rounded, color: iconColor, size: 28),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                tooltip: 'Logout',
              ),
            ],
          )
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
        decoration: BoxDecoration(
          // BoxDecoration should be applied to Container, not Card directly if it has gradient.
          borderRadius: BorderRadius.circular(
              12.0), // Ensure this matches card shape for clipping
          gradient: const LinearGradient(
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
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          size: 44,
                          color: Colors.white70), // Adjusted size
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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RewardsScreen(),
                      ),
                    );
                  },
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
      color: Colors.white,
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
                  color: cardBgColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Image.asset(quest.iconAssetPath,
                    height: 24, width: 24, color: progressColor),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${quest.completedLocations} of ${quest.totalLocations} locations',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${quest.currentPoints} / ${quest.totalPoints} pts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: progressColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Tooltip(
                                message:
                                    'Progress: ${(quest.progress * 100).toInt()}%\n'
                                    'Completed: ${quest.completedLocations} locations\n'
                                    'Points: ${quest.currentPoints} of ${quest.totalPoints}',
                                child: LinearProgressIndicator(
                                  value: quest.progress,
                                  backgroundColor:
                                      progressColor.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      progressColor),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
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
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12.0),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
              child: InkWell(
                onTap: () {/* TODO: Popular Location action */},
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                        ),
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
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8.0),
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

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }
}

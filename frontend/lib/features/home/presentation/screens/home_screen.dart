import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_page.dart';
import 'package:honeybee/features/explore/screens/explore_screen.dart';
import 'package:honeybee/features/video_feed/pages/video_feed_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  List<Map<String, dynamic>> _quests = [];
  bool _isLoading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadQuests();
    _startLocationTracking();
  }

  Future<void> _loadQuests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _quests = [];
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('quests')
          .select('''
            *,
            quest_locations (
              id,
              location_name,
              latitude,
              longitude,
              visited_at
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      debugPrint('Supabase response: $response');

      if (response == null) {
        setState(() {
          _quests = [];
          _isLoading = false;
        });
        return;
      }

      // Ensure response is a List before casting
      final questsList = response is List ? response : [];
      
      setState(() {
        _quests = questsList.map((quest) {
          // Safely handle null values
          final questMap = Map<String, dynamic>.from(quest);
          questMap['title'] = questMap['title'] ?? 'Untitled Quest';
          questMap['description'] = questMap['description'] ?? '';
          questMap['total_points'] = questMap['total_points'] ?? 0;
          questMap['quest_locations'] = questMap['quest_locations'] ?? [];
          return questMap;
        }).toList();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading quests: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load quests: ${e.toString()}';
        _isLoading = false;
        _quests = [];
      });
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location tracking error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildQuestsPage(),
      const QuestPage(),
      const VideoFeedPage(),
      const ExploreScreen(),
    ];

    return Scaffold(
      appBar: _selectedIndex == 0 ? AppBar(
        title: const Text('Honeybee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ) : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            label: 'Quest',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            label: 'For You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
        ],
      ),
    );
  }

  Widget _buildQuestsPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/bee-helper.png',
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 16),
            Text(
              'No quests yet!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new quest to begin your adventure',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Start New Quest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quests.length,
      itemBuilder: (context, index) {
        final quest = _quests[index];
        final locations = List<Map<String, dynamic>>.from(quest['quest_locations'] ?? []);
        final completedLocations = locations.where((loc) => loc['visited_at'] != null).length;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(
                    quest['status'] == 'completed' ? Icons.check : Icons.flag,
                    color: Colors.white,
                  ),
                ),
                title: Text(quest['title'] ?? 'Untitled Quest'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quest['description'] ?? ''),
                    Text(
                      'City: ${quest['city']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${quest['total_points'] ?? 0} pts',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completedLocations/${locations.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuestPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }
}

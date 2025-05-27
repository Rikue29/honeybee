import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home/domain/models.dart';

class QuestService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getOngoingQuests() async {
    try {
      print("[QuestService] Starting to fetch ongoing quests");
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("[QuestService] No authenticated user found");
        throw Exception('User not authenticated');
      }
      print("[QuestService] User authenticated: ${user.id}");

      final response = await supabase
          .from('quests')
          .select('''
            *,
            quest_locations (
              id,
              name,
              description,
              latitude,
              longitude
            )
          ''')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('started_at', ascending: false);

      print("[QuestService] Raw response from Supabase: $response");
      final quests = List<Map<String, dynamic>>.from(response);
      print("[QuestService] Fetched ${quests.length} ongoing quests");
      print(
          "[QuestService] First quest data (if exists): ${quests.isNotEmpty ? quests.first : 'No quests'}");
      return quests;
    } catch (e, stackTrace) {
      print('[QuestService] Error fetching ongoing quests: $e');
      print('[QuestService] Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSavedQuests() async {
    try {
      print("[QuestService] Starting to fetch saved quests");
      final user = supabase.auth.currentUser;
      if (user == null) {
        print("[QuestService] No authenticated user found");
        throw Exception('User not authenticated');
      }
      print("[QuestService] User authenticated: ${user.id}");

      final response = await supabase
          .from('quests')
          .select('''
            *,
            quest_locations (
              id,
              name,
              description,
              latitude,
              longitude
            )
          ''')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      print("[QuestService] Raw response from Supabase: $response");
      final quests = List<Map<String, dynamic>>.from(response);
      print("[QuestService] Fetched ${quests.length} saved quests");
      print(
          "[QuestService] First quest data (if exists): ${quests.isNotEmpty ? quests.first : 'No quests'}");
      return quests;
    } catch (e, stackTrace) {
      print('[QuestService] Error fetching saved quests: $e');
      print('[QuestService] Stack trace: $stackTrace');
      return [];
    }
  }

  // Helper method to convert Supabase response to QuestInfo
  QuestInfo questFromJson(Map<String, dynamic> json) {
    print("[QuestService] Converting quest JSON to QuestInfo: ${json['id']}");
    print("[QuestService] Full quest data: $json");

    final locations =
        List<Map<String, dynamic>>.from(json['quest_locations'] ?? []);

    print("[QuestService] Quest has ${locations.length} locations");
    print("[QuestService] Locations data: $locations");

    // Set progress based on quest status
    int completedLocations = 0;
    int totalPoints = 0;

    // Only show progress for active quests
    if (json['status'] == 'active') {
      completedLocations = (locations.length / 3).round();
      totalPoints =
          completedLocations * 100; // 100 points per completed location
    }

    print(
        "[QuestService] Quest stats - Status: ${json['status']}, Completed: $completedLocations, Total Points: $totalPoints");

    final questInfo = QuestInfo(
      id: json['id'],
      title: json['title'] ?? 'Untitled Quest',
      subtitle: json['description'] ?? 'No description',
      iconAssetPath: 'assets/images/trophy_icon.png',
      currentPoints: totalPoints,
      totalPoints:
          locations.length * 100, // Maximum possible points (100 per location)
      completedLocations: completedLocations,
      totalLocations: locations.length,
    );

    print("[QuestService] Created QuestInfo object: $questInfo");
    return questInfo;
  }

  // Update quest progress in database
  Future<void> updateQuestProgress(
      String questId, String locationId, int score) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // For now, we'll just log that we would update progress here
      print(
          '[QuestService] Would update progress for quest $questId, location $locationId with score $score');
      // TODO: Implement progress tracking once we have the correct database structure
    } catch (e) {
      print('Error updating quest progress: $e');
      throw e;
    }
  }
}

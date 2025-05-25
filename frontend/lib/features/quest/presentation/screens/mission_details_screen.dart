import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_screen.dart'; // For navigating to the quiz

class MissionDetailsScreen extends StatefulWidget {
  final String questId;
  final String locationId;
  final String locationName;
  final double latitude;
  final double longitude;
  // final String missionId; // If already fetched and passed

  const MissionDetailsScreen({
    super.key,
    required this.questId,
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    // required this.missionId,
  });

  @override
  _MissionDetailsScreenState createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  int _currentStep = 0;
  bool _isFetchingMissionId = false;
  String? _fetchedMissionId;
  Map<String, dynamic>? _missionDetails;
  bool _isLoadingMission = true;

  @override
  void initState() {
    super.initState();
    _fetchMissionDetails();
  }

  Future<void> _fetchMissionDetails() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Get the location mission details
      final missionDetails = await supabase
          .from('location_missions')
          .select()
          .eq('location_name', widget.locationName)
          .single();
      
      if (mounted) {
        setState(() {
          _missionDetails = missionDetails;
          _isLoadingMission = false;
        });
      }
    } catch (e) {
      print('Error fetching mission details: $e');
      if (mounted) {
        setState(() {
          _isLoadingMission = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mission: ${e.toString()}')),
        );
      }
    }
  }

  String get _missionTitle => _missionDetails?['title'] ?? 'Find the Guide';
  String get _missionDescription => _missionDetails?['description'] ?? 'Find our guide who will share the location\'s history with you.';
  List<dynamic> get _requirements => List<dynamic>.from(_missionDetails?['requirements'] ?? []);

  // Placeholder for location-specific question detail
  String get _locationSpecificQuestionContext {
    // This should be dynamic based on widget.locationName or fetched
    // For example:
    if (widget.locationName.toLowerCase().contains("museum")) {
      return "the oldest artifact in the main hall";
    } else if (widget.locationName.toLowerCase().contains("market")) {
      return "the best local delicacy to try";
    }
    return "its unique history"; // Default
  }

  Future<String?> _fetchAndStartMission() async {
    setState(() {
      _isFetchingMissionId = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the location mission template
      final locationMissionResponse = await supabase
          .from('location_missions')
          .select()
          .eq('location_name', widget.locationName)
          .single();
      
      // This RPC 'handle_mission_start' should ideally create/find the user_mission_progress 
      // and return its ID ('mission_id' in the old context, but it's actually user_mission_progress_id)
      final response = await supabase.rpc('handle_mission_start', params: {
        'p_location_id': widget.locationId,
        'p_mission_type': locationMissionResponse['mission_type'],
        'p_title': locationMissionResponse['title'],
        'p_description': locationMissionResponse['description'],
        'p_points': locationMissionResponse['points'],
        'p_user_id': user.id
      });

      if (response == null || response['mission_id'] == null) { // Assuming 'mission_id' is the key for user_mission_progress_id
        throw Exception('Failed to start mission or get mission ID');
      }
      
      return response['mission_id'] as String?;
    } catch (e) {
      print('Error fetching/starting mission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing mission: ${e.toString()}')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMissionId = false;
        });
      }
    }
  }


  void _advanceStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _startQuiz() async {
    print("[MissionDetailsScreen] _startQuiz called for ${widget.locationName}.");
    _fetchedMissionId = await _fetchAndStartMission();
    print("[MissionDetailsScreen] Fetched mission ID: $_fetchedMissionId");
    
    if (_fetchedMissionId != null && mounted) {
      print("[MissionDetailsScreen] Navigating to QuizScreen for ${widget.locationName}.");
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            questId: widget.questId,
            locationId: widget.locationId,
            missionId: _fetchedMissionId!, 
            locationName: widget.locationName,
            latitude: widget.latitude,
            longitude: widget.longitude,
          ),
          settings: const RouteSettings(name: 'QuizScreen'),
        ),
      );
      print("[MissionDetailsScreen] Returned from QuizScreen/QuizSummaryScreen flow for ${widget.locationName}.");
      if (mounted) {
          print("[MissionDetailsScreen] Popping self with true for ${widget.locationName}.");
          Navigator.pop(context, true); 
      }
    } else if (mounted) {
      print("[MissionDetailsScreen] Failed to fetch mission ID or not mounted. Popping self with false for ${widget.locationName}.");
      Navigator.pop(context, false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    print("[MissionDetailsScreen] Build method called. Current step: $_currentStep for ${widget.locationName}");
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: Text("Mission at ${widget.locationName}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, false); // Indicate mission was not completed/backed out
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isFetchingMissionId 
            ? const CircularProgressIndicator()
            : _buildCurrentStepWidget(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    if (_currentStep == 0) {
      return _buildFindGuideStep();
    } else if (_currentStep == 1) {
      return _buildAskQuestionsStep();
    }
    // Potentially more steps or a completion/error state
    return const Text("Mission complete or undefined step."); 
  }

  Widget _buildFindGuideStep() {
    if (_isLoadingMission) {
      return const Center(child: CircularProgressIndicator());
    }

    final requirement = _requirements.isNotEmpty ? _requirements[0] : null;
    final findDescription = requirement?['description'] ?? 'Find our guide who will share the history with you.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _missionTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          findDescription,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _advanceStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: Text("Found Them!"),
        ),
      ],
    );
  }

  Widget _buildAskQuestionsStep() {
    if (_isLoadingMission) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _missionDescription,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Text(
          "Are you ready to start the quiz?",
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("No, not yet"),
            ),
            ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: Text("Yes, let's go!"),
            ),
          ],
        ),
      ],
    );
  }
} 
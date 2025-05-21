import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class QuestCompletedScreen extends StatelessWidget {
  final String areaName;
  final int xpEarned;
  final int questsCompleted;
  final List<QuestHighlight> highlights;
  final VoidCallback onContinue;
  final VoidCallback onGenerateVideo;
  final VoidCallback? onLogout;

  const QuestCompletedScreen({
    super.key,
    required this.areaName,
    required this.xpEarned,
    required this.questsCompleted,
    required this.highlights,
    required this.onContinue,
    required this.onGenerateVideo,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Small logout button at the top right
          if (onLogout != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFFEA8601)),
              tooltip: 'Logout',
              onPressed: onLogout,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF9E6), // Light cream background
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Trophy icon and journey complete
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      // Trophy icon in circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFEFC4), // Light yellow circle
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined, // Trophy icon
                          color: Color(0xFFFF9800), // Orange color
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Journey Complete text
                      const Text(
                        'Journey Complete!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Unlocked secrets text
                      Text(
                        'You\'ve unlocked the secrets of $areaName!',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),

                // XP and Quests completed stats
                Row(
                  children: [
                    // XP Earned
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$xpEarned',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA8601), // Orange
                              ),
                            ),
                            const Text(
                              'XP Earned',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quests Completed
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$questsCompleted',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA8601), // Orange
                              ),
                            ),
                            const Text(
                              'Quests Completed',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Journey Highlights section
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Journey Highlights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ),

                // Quest highlights list
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: highlights.length,
                  itemBuilder: (context, index) {
                    final quest = highlights[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildQuestHighlightCard(quest),
                    );
                  },
                ),

                // Create Your Journal Video section (yellow box)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F), // Yellow box
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Your Journal Video!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generate and share your journey video on social media or community!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Use the new JourneyVideoSection here
                      JourneyVideoSection(
                        journeyId:
                            areaName, // Replace with actual journey ID if available
                        onContinue: onContinue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestHighlightCard(QuestHighlight quest) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Quest image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
            child: Image.asset(
              quest.imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),

          // Quest details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quest.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Checkmark
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.check_circle,
              color: quest.isCompleted ? const Color(0xFF4CAF50) : Colors.grey,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// Add this widget for the video generation section
class JourneyVideoSection extends StatefulWidget {
  final String journeyId;
  final VoidCallback onContinue;
  const JourneyVideoSection(
      {super.key, required this.journeyId, required this.onContinue});

  @override
  State<JourneyVideoSection> createState() => _JourneyVideoSectionState();
}

enum VideoGenState { idle, loading, ready, error }

class _JourneyVideoSectionState extends State<JourneyVideoSection> {
  VideoGenState _state = VideoGenState.idle;
  String? _videoUrl;
  String? _errorMsg;
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _generateVideo() async {
    setState(() {
      _state = VideoGenState.loading;
      _errorMsg = null;
    });
    // 1. Call backend to start video generation
    final response = await http.post(
      Uri.parse('https://your-backend/api/generate-journey-video'),
      body: jsonEncode({'journeyId': widget.journeyId}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      setState(() {
        _state = VideoGenState.error;
        _errorMsg = 'Failed to start video generation';
      });
      return;
    }
    // 2. Poll for completion
    _pollForVideo();
  }

  Future<void> _pollForVideo() async {
    const pollInterval = Duration(seconds: 3);
    while (true) {
      await Future.delayed(pollInterval);
      final statusResp = await http.get(
        Uri.parse(
            'https://your-backend/api/journey-video-status?journeyId=${widget.journeyId}'),
      );
      if (statusResp.statusCode != 200) {
        setState(() {
          _state = VideoGenState.error;
          _errorMsg = 'Error checking video status';
        });
        return;
      }
      final data = jsonDecode(statusResp.body);
      if (data['status'] == 'ready') {
        setState(() {
          _videoUrl = data['videoUrl'];
          _state = VideoGenState.ready;
        });
        _controller = VideoPlayerController.network(_videoUrl!)
          ..initialize().then((_) {
            setState(() {});
            _controller!.play();
          });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == VideoGenState.loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_state == VideoGenState.ready &&
        _controller != null &&
        _controller!.value.isInitialized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          const SizedBox(height: 16),
          // Share buttons (replace with your actual share logic/UI)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.groups),
              label: const Text('Share On Community'),
              onPressed: () {
                // TODO: Implement share to community
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEA8601),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share On Social Media'),
              onPressed: () {
                // TODO: Implement share to social media
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEA8601),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF666666),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.sentiment_satisfied_alt, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_state == VideoGenState.error) {
      return Column(
        children: [
          Text(_errorMsg ?? 'An error occurred',
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _generateVideo,
            child: const Text('Try Again'),
          ),
        ],
      );
    }
    // Idle state: show generate button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _generateVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFEA8601),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Generate Video',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.auto_awesome, size: 18),
          ],
        ),
      ),
    );
  }
}

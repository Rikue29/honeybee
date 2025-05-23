import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<List<String>> getSupabaseFileUrls() async {
    final supabase = Supabase.instance.client;
    final files = await supabase.storage.from('upload.videos').list();
    return files
        .where((f) =>
            f.name.endsWith('.jpg') ||
            f.name.endsWith('.png') ||
            f.name.endsWith('.mp4')) // filter as needed
        .map((f) => supabase.storage.from('upload.videos').getPublicUrl(f.name))
        .toList();
  }

  Future<void> _generateVideoFromSupabase() async {
    setState(() {
      _state = VideoGenState.loading;
      _errorMsg = null;
    });

    try {
      final urls = await getSupabaseFileUrls();

      final response = await http.post(
        Uri.parse('http://103.209.156.158:5000/api/generate-video'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_urls': urls,
          'title_text': 'Journey With Amie',
          'duration': 3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _videoUrl = data['public_url'];
          _state = VideoGenState.ready;
        });
        _controller = VideoPlayerController.network(_videoUrl!)
          ..initialize().then((_) {
            setState(() {});
            _controller!.play();
          });
      } else {
        setState(() {
          _state = VideoGenState.error;
          _errorMsg = 'Failed to generate video: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _state = VideoGenState.error;
        _errorMsg = 'Error: $e';
      });
    }
  }

  Widget _buildLoadingScreen() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA8601)),
        ),
        const SizedBox(height: 20),
        const Text(
          'Generating your journey video...',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This may take a few moments',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Journey Video',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Share Your Adventure',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share your journey video on social media or community!',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == VideoGenState.loading) {
      return _buildLoadingScreen();
    }
    if (_state == VideoGenState.ready &&
        _controller != null &&
        _controller!.value.isInitialized) {
      return _buildVideoScreen();
    }
    if (_state == VideoGenState.error) {
      return Column(
        children: [
          Text(_errorMsg ?? 'An error occurred',
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _generateVideoFromSupabase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEA8601),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      );
    }
    // Idle state: show generate button
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _generateVideoFromSupabase,
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

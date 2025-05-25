import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'generated_video_screen.dart'; // To navigate to after success
import 'dart:async'; // Added for Timer

class VideoGenerationLoadingScreen extends StatefulWidget {
  final String journeyId; // Assuming journeyId is needed to get file URLs

  const VideoGenerationLoadingScreen({super.key, required this.journeyId});

  @override
  State<VideoGenerationLoadingScreen> createState() =>
      _VideoGenerationLoadingScreenState();
}

enum LoadingScreenState { loading, error }

class _VideoGenerationLoadingScreenState
    extends State<VideoGenerationLoadingScreen> {
  LoadingScreenState _screenState = LoadingScreenState.loading;
  String? _errorMessage;
  Timer? _messageTimer;
  Timer? _progressTimer;
  int _currentMessageIndex = 0;
  double _progressValue = 0.0;
  static const int totalLoadingTimeInSeconds = 60;
  static const int messageChangeInterval = 10;
  DateTime? _startTime;

  final List<String> _loadingMessages = [
    "Igniting the video creation engine...",
    "Gathering your best shots...",
    "Mixing in some visual flair...",
    "Harmonizing audio and visuals...",
    "Rendering your masterpiece...",
    "Adding final touches... Almost ready!",
  ];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initiateVideoGeneration();
    if (_screenState == LoadingScreenState.loading) {
      _startLoadingAnimation();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startLoadingAnimation() {
    // Update progress more frequently for smoother animation
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsedSeconds =
          DateTime.now().difference(_startTime!).inMilliseconds / 1000;
      setState(() {
        // Calculate progress based on actual elapsed time
        _progressValue =
            (elapsedSeconds / totalLoadingTimeInSeconds).clamp(0.0, 0.99);

        if (elapsedSeconds >= totalLoadingTimeInSeconds) {
          _progressValue = 0.99; // Ensure we stay at 99% until complete
          timer.cancel();
        }
      });
    });

    // Update messages less frequently
    _messageTimer =
        Timer.periodic(const Duration(seconds: messageChangeInterval), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_currentMessageIndex < _loadingMessages.length - 1) {
          _currentMessageIndex++;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<List<String>> _getSupabaseFileUrlsForLoading() async {
    // This is the same logic from JourneyVideoSection, refactored slightly
    // We are keeping it separate to allow this screen to be self-contained for generation
    try {
      final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
            'Supabase credentials not found in environment variables for loading screen');
      }
      final SupabaseClient client =
          SupabaseClient(supabaseUrl, supabaseAnonKey);
      const bucketName = 'user-pics';

      print('LoadingScreen: Listing files from $bucketName');
      List<FileObject> files = await client.storage.from(bucketName).list();
      print(
          'LoadingScreen: Files listed: ${files.map((f) => f.name).toList()}');

      if (files.isEmpty) {
        throw Exception('No media files found in storage for loading screen');
      }
      final validFiles = files
          .where((f) =>
              f.name.toLowerCase().endsWith('.jpg') ||
              f.name.toLowerCase().endsWith('.jpeg') ||
              f.name.toLowerCase().endsWith('.png') ||
              f.name.toLowerCase().endsWith('.mp4'))
          .toList();
      if (validFiles.isEmpty) {
        throw Exception(
            'No valid media files (images/videos) found in storage for loading screen');
      }
      return validFiles
          .map((f) => client.storage.from(bucketName).getPublicUrl(f.name))
          .toList();
    } catch (e) {
      print('LoadingScreen: Error fetching Supabase file URLs: $e');
      rethrow; // Rethrow to be caught by _initiateVideoGeneration
    }
  }

  Future<void> _initiateVideoGeneration() async {
    setState(() {
      _screenState = LoadingScreenState.loading;
      _errorMessage = null;
      _currentMessageIndex = 0;
      _progressValue = 0.0;
      _startTime = DateTime.now(); // Reset start time when retrying
    });

    // Cancel existing timers if any
    _messageTimer?.cancel();
    _progressTimer?.cancel();

    // Start new animation
    _startLoadingAnimation();

    try {
      final urls = await _getSupabaseFileUrlsForLoading();

      final response = await http.post(
        Uri.parse('http://103.209.156.158:5000/api/generate-video'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_urls': urls,
          'title_text': 'Journey With Me',
          'duration': 3, // Consider making this dynamic
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videoUrl = data['public_url'];

        if (videoUrl == null || videoUrl.isEmpty) {
          throw Exception('Backend returned no valid video URL');
        }

        if (mounted) {
          // Replace this screen with the video player screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GeneratedVideoScreen(videoUrl: videoUrl),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error'] is String
            ? errorData['error'] as String
            : response.body;
        throw Exception('Failed to generate video: $errorMessage');
      }
    } catch (e) {
      print('LoadingScreen: Video generation process error: $e');
      if (mounted) {
        _messageTimer?.cancel(); // Stop timer on error
        setState(() {
          _screenState = LoadingScreenState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generating Video'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFEA8601),
        elevation: 0,
        automaticallyImplyLeading: _screenState ==
            LoadingScreenState.error, // Show back button only on error
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _screenState == LoadingScreenState.loading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFEA8601)),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _loadingMessages[_currentMessageIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF444444),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: LinearProgressIndicator(
                        value: _progressValue,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFEA8601)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "This might take a few moments...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    Text(
                      'Failed to Generate Video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage ?? 'An unknown error occurred.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      onPressed: () {
                        _initiateVideoGeneration(); // Also restart message cycle here if needed.
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA8601),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

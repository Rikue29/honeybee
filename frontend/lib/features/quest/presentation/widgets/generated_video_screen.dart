import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

class GeneratedVideoScreen extends StatefulWidget {
  final String videoUrl;

  const GeneratedVideoScreen({
    super.key,
    required this.videoUrl,
  });

  @override
  State<GeneratedVideoScreen> createState() => _GeneratedVideoScreenState();
}

class _GeneratedVideoScreenState extends State<GeneratedVideoScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isRetrying = false;
  int _retryCount = 0;
  static const int maxRetries = 3;
  static const int retryDelay = 2; // seconds

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<bool> _checkVideoAvailability() async {
    try {
      final response = await http.head(Uri.parse(widget.videoUrl));
      print('Video URL status code: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error checking video availability: $e');
      return false;
    }
  }

  Future<void> _initializeVideo() async {
    if (_retryCount >= maxRetries) {
      setState(() {
        _errorMessage =
            'Failed to load video after several attempts. Please try again later.';
        _isRetrying = false;
      });
      return;
    }

    try {
      print('Attempt ${_retryCount + 1}: Checking video availability...');
      final isAvailable = await _checkVideoAvailability();

      if (!isAvailable) {
        print('Video not available yet, waiting ${retryDelay} seconds...');
        setState(() {
          _isRetrying = true;
        });
        await Future.delayed(Duration(seconds: retryDelay));
        _retryCount++;
        await _initializeVideo();
        return;
      }

      print('Initializing video player with URL: ${widget.videoUrl}');
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isRetrying = false;
        });
        _controller.play();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        if (_retryCount < maxRetries) {
          print('Retrying in ${retryDelay} seconds...');
          setState(() {
            _isRetrying = true;
          });
          await Future.delayed(Duration(seconds: retryDelay));
          _retryCount++;
          await _initializeVideo();
        } else {
          setState(() {
            _errorMessage = 'Failed to load video: $e';
            _isRetrying = false;
          });
        }
      }
    }
  }

  Future<void> _retryManually() async {
    setState(() {
      _errorMessage = null;
      _retryCount = 0;
      _isRetrying = false;
    });
    await _initializeVideo();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Journey Video'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFEA8601),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retryManually,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFEA8601),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_isInitialized)
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          width: 320,
                          color: Colors.white,
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay,
                              color: Color(0xFFEA8601)),
                          tooltip: 'Replay',
                          onPressed: () {
                            _controller.seekTo(Duration.zero);
                            _controller.play();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: const Color(0xFFEA8601),
                          ),
                          tooltip:
                              _controller.value.isPlaying ? 'Pause' : 'Play',
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        color: const Color(0xFFFFF3D6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Share Your Adventure',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFFEA8601),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'share your journey video on social media or community!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A6B2F),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.groups),
                                label: const Text('Share On Community'),
                                onPressed: () {
                                  // TODO: Implement share to community
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFEA8601),
                                  minimumSize: const Size(double.infinity, 48),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(color: Color(0xFFEA8601))),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text('or',
                                        style: TextStyle(
                                            color: Color(0xFFEA8601))),
                                  ),
                                  Expanded(
                                      child: Divider(color: Color(0xFFEA8601))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.share),
                                label: const Text('Share On Social Media'),
                                onPressed: () {
                                  // TODO: Implement share to social media
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFEA8601),
                                  minimumSize: const Size(double.infinity, 48),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              if (!_isInitialized && _errorMessage == null)
                Container(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFEA8601)),
                        ),
                        const SizedBox(height: 16),
                        if (_isRetrying)
                          Text(
                            'Attempt ${_retryCount + 1} of $maxRetries\nWaiting for video to be ready...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

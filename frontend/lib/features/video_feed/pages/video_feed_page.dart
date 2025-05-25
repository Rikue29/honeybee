import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/video_card.dart';

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({Key? key}) : super(key: key);

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  final PageController _pageController = PageController();
  List<Map<String, String>> _videos = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _pageController.addListener(() {
      int next = _pageController.page?.round() ?? 0;
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  Future<void> _loadVideos() async {
    try {
      final storage = Supabase.instance.client.storage;
      debugPrint('Fetching videos from videos.generated/videos...');
      final List<FileObject> files = await storage.from('videos.generated').list(path: 'videos');
      debugPrint('Found ${files.length} files in bucket');
      debugPrint('Files: ${files.map((f) => f.name).toList()}');
      
      if (!mounted) return;

      final List<Map<String, String>> videos = [];
      for (var file in files) {
        final String videoUrl = storage
            .from('videos.generated')
            .getPublicUrl('videos/${file.name}');
        debugPrint('Generated URL for ${file.name}: $videoUrl');
            
        videos.add({
          'videoUrl': videoUrl,
          'username': '@rikuekue', // You can customize this later
          'description': 'Generated video ${file.name}', // You can customize this later
          'likes': '0',
        });
      }

      debugPrint('Final videos list length: ${videos.length}');
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading videos: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load videos: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Feed or Loading/Error State
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _loadVideos();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_videos.isEmpty)
            const Center(
              child: Text(
                'No videos available',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                return VideoCard(
                  videoData: _videos[index],
                  isActive: _currentPage == index,
                );
              },
            ),
          
          // Top Bar with Following/For You
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                    child: const Text(
                      'For You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
} 
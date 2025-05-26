import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For image and video picking
import 'package:supabase_flutter/supabase_flutter.dart'; // For Supabase storage
import 'dart:io'; // For File operations
import 'package:video_player/video_player.dart'; // For video preview
import '../models/question_result.dart';
import 'package:honeybee/core/services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Class to store media information
class MediaItem {
  final XFile file;
  final bool isVideo;
  VideoPlayerController? controller;
  String? uploadedUrl;

  MediaItem({required this.file, required this.isVideo, this.controller});
}

class QuizSummaryScreen extends StatefulWidget {
  final List<QuestionResult> quizResults;
  final int totalScore;
  final String questId;
  final String locationId;
  final String missionId; // This is actually user_mission_progress_id
  final double latitude;
  final double longitude;

  const QuizSummaryScreen({
    super.key,
    required this.quizResults,
    required this.totalScore,
    required this.questId,
    required this.locationId,
    required this.missionId,
    required this.latitude,
    required this.longitude,
  });

  @override
  _QuizSummaryScreenState createState() => _QuizSummaryScreenState();
}

class _QuizSummaryScreenState extends State<QuizSummaryScreen> {
  final ImagePicker _picker = ImagePicker();
  final PlacesService _placesService = PlacesService();
  final List<MediaItem> _mediaItems =
      []; // New: List to store multiple media items
  bool _isUploading = false;
  List<Place> _nearbyPlaces = [];
  bool _isLoadingPlaces = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _fetchNearbyPlaces();
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (var item in _mediaItems) {
      item.controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchNearbyPlaces() async {
    if (mounted) {
      setState(() {
        _isLoadingPlaces = true;
      });
    }

    try {
      // First try with a smaller radius
      var places = await _placesService.getNearbyPlaces(
        latitude: widget.latitude,
        longitude: widget.longitude,
        type: 'restaurant',
        limit: 3,
        radiusMeters: 500,
      );

      // If no places found, try with a larger radius
      if (places.isEmpty) {
        places = await _placesService.getNearbyPlaces(
          latitude: widget.latitude,
          longitude: widget.longitude,
          type: 'restaurant',
          limit: 3,
          radiusMeters: 1000,
        );
      }

      // If still no places found, add a fallback restaurant
      if (places.isEmpty) {
        places = [_getFallbackRestaurant()];
      }

      if (mounted) {
        setState(() {
          _nearbyPlaces = places;
          _isLoadingPlaces = false;
        });
      }
    } catch (e) {
      print('Error fetching nearby places: $e');
      if (mounted) {
        setState(() {
          // Add fallback restaurant in case of error
          _nearbyPlaces = [_getFallbackRestaurant()];
          _isLoadingPlaces = false;
        });
      }
    }
  }

  Place _getFallbackRestaurant() {
    // Get location name in lowercase for easier matching
    final locationName = widget.locationId.toLowerCase();

    String restaurantName;
    String description;

    if (locationName.contains('museum')) {
      restaurantName = "Museum Cafe & Bistro";
      description = "Traditional cafe serving local delights at the museum";
    } else if (locationName.contains('masjid') ||
        locationName.contains('mosque')) {
      restaurantName = "Warung Pak Mat";
      description = "Authentic Malay cuisine near the mosque";
    } else if (locationName.contains('palace') ||
        locationName.contains('istana')) {
      restaurantName = "Royal Kitchen Restaurant";
      description = "Experience royal-inspired local cuisine";
    } else if (locationName.contains('market') ||
        locationName.contains('pasar')) {
      restaurantName = "Pasar Street Delights";
      description = "Popular local street food stall";
    } else if (locationName.contains('river') ||
        locationName.contains('sungai')) {
      restaurantName = "Riverside Dining";
      description = "Scenic riverside restaurant with local specialties";
    } else {
      restaurantName = "Warung Kampung";
      description = "Traditional Malaysian restaurant nearby";
    }

    return Place(
      name: restaurantName,
      category: "restaurant",
      latitude: widget.latitude + 0.001,
      longitude: widget.longitude + 0.001,
      distance: 200,
      address: description,
    );
  }

  Future<void> _openGoogleMapsNavigation(Place place) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    try {
      final XFile? pickedFile = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source);

      if (pickedFile != null) {
        final mediaItem = MediaItem(file: pickedFile, isVideo: isVideo);

        // Initialize video controller if it's a video
        if (isVideo) {
          mediaItem.controller =
              VideoPlayerController.file(File(pickedFile.path))
                ..initialize().then((_) {
                  setState(() {});
                });
        }

        setState(() {
          _mediaItems.add(mediaItem);
        });

        await _uploadMedia(mediaItem); // Upload the new media item
      }
    } catch (e) {
      print("Error picking media: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking media: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _uploadMedia(MediaItem mediaItem) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated for upload.");

      final String extension = mediaItem.isVideo ? '.mp4' : '.jpg';
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${widget.locationId}$extension';
      final File fileToUpload = File(mediaItem.file.path);

      final response =
          await Supabase.instance.client.storage.from('user-pics').upload(
                fileName,
                fileToUpload,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );

      mediaItem.uploadedUrl = response;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  mediaItem.isVideo ? Icons.videocam : Icons.photo,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mediaItem.isVideo
                            ? "Video uploaded successfully!"
                            : "Picture uploaded successfully!",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Your memory has been saved to your journal",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.1,
              left: 16,
              right: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print("[QuizSummaryScreen] Error details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error uploading media. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _removeMedia(int index) {
    final mediaItem = _mediaItems[index];
    mediaItem.controller?.dispose();
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  void _showNearbyPlacesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/bee_quest.png',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ready to head to the next location?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_nearbyPlaces.isNotEmpty) ...[
              Text(
                'Recommended: ${_nearbyPlaces[0].name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
              Text(
                _nearbyPlaces[0].address ??
                    '${(_nearbyPlaces[0].distance / 1000).toStringAsFixed(1)} km away',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_nearbyPlaces.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openGoogleMapsNavigation(_nearbyPlaces[0]);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      minimumSize: const Size(200, 45),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Navigate',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    minimumSize: const Size(200, 45),
                  ),
                  child: const Text(
                    'Continue Quest',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showPauseDialog();
                  },
                  icon: const Icon(Icons.coffee, size: 18),
                  label: const Text('Take a Break'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    minimumSize: const Size(200, 45),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPauseDialog() {
    setState(() => _isPaused = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_filled,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Quest Paused',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isPaused = false);
                  Navigator.pop(dialogContext);
                  _showNearbyPlacesDialog();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume Quest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenRewardDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/bee_quest.png',
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              'You have 1 token!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can redeem this voucher now to use at the next location or redeem later',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/bee_quest.png',
                        height: 40,
                        width: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Free Parking Coupon',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Exclusive parking coupon limited to Pahang only',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expires in 30 days',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Successfully redeemed!'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      _showNearbyPlacesDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Redeem Now',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showNearbyPlacesDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Redeem Later',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_isUploading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 50, color: Colors.grey[700]),
            const SizedBox(width: 8),
            IconButton(
              icon:
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/bee_quest.png',
                          height: 80,
                          width: 80,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "By adding to journal you can earn 100XP and generate a video at the end of the trip!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _mediaItems.isEmpty
              ? "Would you like to upload pictures or videos for your journal?"
              : "Add more pictures or videos to your journal:",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 15),
        if (_mediaItems.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaItems.length,
              itemBuilder: (context, index) {
                final mediaItem = _mediaItems[index];
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: mediaItem.isVideo
                            ? (mediaItem.controller?.value.isInitialized ??
                                    false)
                                ? VideoPlayer(mediaItem.controller!)
                                : const Center(child: Icon(Icons.videocam))
                            : Image.file(
                                File(mediaItem.file.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeMedia(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 15),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickMedia(ImageSource.gallery, false),
              icon: const Icon(Icons.photo),
              label: const Text("Add Photo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _pickMedia(ImageSource.gallery, true),
              icon: const Icon(Icons.videocam),
              label: const Text("Add Video"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: const Text('Quiz Summary'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "SUCCESS!",
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(widget.quizResults.length, (index) {
                      final result = widget.quizResults[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Question ${index + 1}",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Icon(
                              result.isCorrect
                                  ? Icons.check_box_outlined
                                  : Icons.disabled_by_default_outlined,
                              color:
                                  result.isCorrect ? Colors.green : Colors.red,
                              size: 28,
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    Text(
                      "You earned: ",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 30),
                        const SizedBox(width: 8),
                        Text(
                          "${widget.totalScore} XP",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/bee_quest.png',
                          height: 24,
                          width: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "1 Token",
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey[400]!,
                      style: BorderStyle.solid,
                      width: 1)),
              child: _buildMediaPreview(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _showTokenRewardDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                "NEXT",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

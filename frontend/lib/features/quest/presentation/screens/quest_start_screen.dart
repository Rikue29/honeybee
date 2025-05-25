import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:honeybee/core/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
import '../../services/gemini_service.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'quiz_screen.dart';
import 'mission_details_screen.dart';
import 'quest_completed_screen.dart';
import '../../domain/models/quest_highlight.dart';

class QuestStartScreen extends StatefulWidget {
  final List<Location> locations;
  final String city;
  final String questId;

  const QuestStartScreen({
    super.key,
    required this.locations,
    required this.city,
    required this.questId,
  });

  @override
  State<QuestStartScreen> createState() => _QuestStartScreenState();
}

class _QuestStartScreenState extends State<QuestStartScreen> {
  late List<Location> _locations;
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  final List<Uint8List> _locationMarkerImages = [];
  Uint8List? _userMarkerImage;
  bool _isMapInitialized = false;
  bool _isDisposed = false;
  geo.Position? _userLocation;
  LineLayer? _routeLayer;
  int _currentLocationIndex = 0;
  bool _isQuestChainCompleted = false;

  @override
  void initState() {
    super.initState();
    _locations = widget.locations;
    if (_locations.isEmpty) {
      print("[QuestStartScreen] Error: No locations provided for the quest.");
      _isQuestChainCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToQuestCompletedScreen(true);
        }
      });
    } else {
      _initializeMap();
      _loadMarkerImages();
      _startArrivalSimulation();
    }
  }

  void _initializeMap() {
    try {
      String accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      MapboxOptions.setAccessToken(accessToken);
      if (mounted) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing map: $e');
    }
  }

  Future<void> _loadMarkerImages() async {
    if (_isDisposed) return;

    // Load numbered markers
    for (int i = 1; i <= 4; i++) {
      final markerBytes = await rootBundle.load('assets/images/marker-$i.png');
      if (!_isDisposed && mounted) {
        _locationMarkerImages.add(markerBytes.buffer.asUint8List());
      }
    }

    // Load user marker
    final userMarkerBytes =
        await rootBundle.load('assets/images/marker-here.png');

    if (!_isDisposed && mounted) {
      setState(() {
        _userMarkerImage = userMarkerBytes.buffer.asUint8List();
      });
    }
  }

  void _onMapCreated(MapboxMap controller) async {
    if (!mounted || _isDisposed) return;

    setState(() {
      mapboxMap = controller;
    });

    // Initialize the point annotation manager
    pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();
    _addMarkersToMap();
  }

  Future<void> _addMarkersToMap() async {
    if (mapboxMap == null ||
        _locationMarkerImages.isEmpty ||
        _isDisposed ||
        _isQuestChainCompleted) return;

    try {
      // Create point annotation manager if it doesn't exist
      pointAnnotationManager ??=
          await mapboxMap!.annotations.createPointAnnotationManager();

      // Clear existing annotations
      await pointAnnotationManager!.deleteAll();

      // Add markers for each location
      for (var i = 0; i < _locations.length; i++) {
        if (_isDisposed) return;

        final location = _locations[i];
        final markerIndex = i % _locationMarkerImages.length;

        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          iconSize: 0.3,
          image: _locationMarkerImages[markerIndex],
        );

        await pointAnnotationManager!.create(options);
      }

      // Adjust camera to show current location
      if (!_isDisposed) {
        final currentLocation = _locations[_currentLocationIndex];
        final cameraOptions = CameraOptions(
          center: Point(
            coordinates:
                Position(currentLocation.longitude, currentLocation.latitude),
          ),
          zoom: 14.0,
        );
        await mapboxMap?.setCamera(cameraOptions);
      }
    } catch (e) {
      print('Error adding markers: $e');
    }
  }

  void _startArrivalSimulation() {
    if (_isQuestChainCompleted) return;
    print('Starting arrival simulation...'); // Debug log
    Future.delayed(const Duration(seconds: 4), () {
      print('Simulated arrival, showing confirmation...'); // Debug log
      if (!mounted) return;
      setState(() {}); // Ensure the widget is in a clean state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showArrivalPrompt();
      });
    });
  }

  void _showArrivalPrompt() {
    if (!mounted || _isQuestChainCompleted) {
      if (_isQuestChainCompleted && mounted) {}
      return;
    }

    if (_currentLocationIndex >= _locations.length) {
      print(
          "[QuestStartScreen] _showArrivalPrompt called with invalid index $_currentLocationIndex. Navigating to completed screen.");
      setState(() {
        _isQuestChainCompleted = true;
      });
      _navigateToQuestCompletedScreen();
      return;
    }

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
            Text(
              'Have you arrived at ${_locations[_currentLocationIndex].name}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Arrange buttons in a Column for better spacing and to include the dev button
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Make buttons stretch
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Pop this arrival dialog
                    print(
                        "[QuestStartScreen] User clicked 'Yes' for location: ${_locations[_currentLocationIndex].name}");

                    final currentLocation = _locations[_currentLocationIndex];
                    final missionCompleted = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MissionDetailsScreen(
                          questId: widget.questId,
                          locationId: currentLocation.id,
                          locationName: currentLocation.name,
                          latitude: currentLocation.latitude,
                          longitude: currentLocation.longitude,
                        ),
                        settings:
                            const RouteSettings(name: 'MissionDetailsScreen'),
                      ),
                    );

                    print(
                        "[QuestStartScreen] Result from MissionDetailsScreen: $missionCompleted for location: ${_locations[_currentLocationIndex].name}");

                    if (missionCompleted == true) {
                      if (mounted) {
                        print(
                            "[QuestStartScreen] Mission completed, advancing location index from $_currentLocationIndex");
                        int newIndex = _currentLocationIndex + 1;
                        if (newIndex >= _locations.length) {
                          print(
                              "[QuestStartScreen] All locations completed. New index: $newIndex");
                          setState(() {
                            _currentLocationIndex = newIndex;
                            _isQuestChainCompleted = true;
                          });
                          _navigateToQuestCompletedScreen();
                        } else {
                          print(
                              "[QuestStartScreen] Mission completed, advancing to index: $newIndex");
                          setState(() {
                            _currentLocationIndex = newIndex;
                          });
                          _addMarkersToMap();
                          _showNavigateToNextPrompt(); // Proceed to next location prompt
                        }
                      }
                    } else {
                      print(
                          "[QuestStartScreen] Mission NOT completed or quiz not started from details for ${_locations[_currentLocationIndex].name}.");
                      _startArrivalSimulation(); // Re-prompt for the same location
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12), // Ensure consistent padding
                  ),
                  child: const Text(
                    'Yes, I\'m Here!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext), // Just close this dialog
                  child: const Text('Not Yet'),
                ),
                const SizedBox(height: 12), // Spacer before dev button
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); // Close this dialog
                    print(
                        "[QuestStartScreen] Dev shortcut: Skipping to quest completed screen.");
                    setState(() {
                      _isQuestChainCompleted = true;
                    });
                    _navigateToQuestCompletedScreen();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10), // Ensure consistent padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('DEV: Skip to Quest End'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted && !_isQuestChainCompleted) {
        setState(() {});
      }
    });
  }

  void _showNavigateToNextPrompt() {
    if (!mounted || _isQuestChainCompleted) return;

    if (_currentLocationIndex >= _locations.length) {
      print(
          "[QuestStartScreen] _showNavigateToNextPrompt called with invalid index $_currentLocationIndex. Attempting to show quest complete.");
      _isQuestChainCompleted = true;
      _navigateToQuestCompletedScreen();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Next Stop: ${_locations[_currentLocationIndex].name}'),
        content: Text(
            'Ready to head to your next destination, ${_locations[_currentLocationIndex].name}?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding:
            const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.navigation, color: Colors.white),
                label: const Text('Navigate using Google Maps',
                    style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openGoogleMapsNavigation(_locations[_currentLocationIndex]);
                  _startArrivalSimulation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Not Yet',
                    style: TextStyle(color: Colors.orange)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  print(
                      "[QuestStartScreen] Dev shortcut: Skipping to quest completed screen.");
                  setState(() {
                    _isQuestChainCompleted = true;
                  });
                  _navigateToQuestCompletedScreen();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('DEV: Skip to Quest End'),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _navigateToQuestCompletedScreen([bool isEmptyQuest = false]) {
    if (!mounted) return;
    print(
        "[QuestStartScreen] Navigating to QuestCompletedScreen. IsEmptyQuest: $isEmptyQuest");

    final String areaName = widget.city;
    final int xpEarned = isEmptyQuest ? 0 : 400;
    final int questsCompleted = isEmptyQuest ? 0 : 1;

    // Define a map for location name to specific image paths
    final Map<String, String> locationImageMap = {
      'Sultan Abu Bakar Museum': 'assets/images/museum_tour.png',
      'Pekan Riverfront': 'assets/images/location_waterfront.JPG',
      'Masjid Sultan Abdullah': 'assets/images/masjid_sultan_abdullah.png',
      'Abu Bakar Palace': 'assets/images/istana_abubakar.png',
    };
    const String defaultPlaceholderImage = 'assets/images/bee_quest.png';

    List<QuestHighlight> highlights = [];
    if (!isEmptyQuest && _locations.isNotEmpty) {
      highlights = _locations.map((loc) {
        // Use the specific image from the map if available, otherwise use placeholder
        String imagePath =
            locationImageMap[loc.name] ?? defaultPlaceholderImage;

        // A special check for the 4th location if it's Abu Bakar Palace and we want a different placeholder or specific logic
        if (loc.name == 'Abu Bakar Palace' &&
            !locationImageMap.containsKey(loc.name)) {
          // This means Abu Bakar Palace was not in the map, so it will use defaultPlaceholderImage
          // If you had a specific placeholder for the 4th unpictured item, you could set it here.
          // e.g. imagePath = 'assets/images/abu_bakar_palace_placeholder.png';
        }

        return QuestHighlight(
          title: loc.name,
          subtitle: 'Visited this amazing place!',
          imagePath: imagePath,
          isCompleted: true,
        );
      }).toList();
    }

    if (highlights.isEmpty && !isEmptyQuest) {
      highlights.add(QuestHighlight(
        title: areaName,
        subtitle: "Journey Concluded!",
        imagePath:
            defaultPlaceholderImage, // Use placeholder for default highlight
        isCompleted: true,
      ));
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuestCompletedScreen(
          areaName: areaName,
          xpEarned: xpEarned,
          questsCompleted: questsCompleted,
          highlights: highlights,
          onContinue: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
          onGenerateVideo: () {
            print("Generate video called from QuestCompletedScreen");
          },
        ),
      ),
    );
  }

  Future<void> _openGoogleMapsNavigation(Location location) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}',
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

  @override
  void dispose() {
    _isDisposed = true;
    // Null-check before calling deleteAll to prevent errors on disposed manager
    if (pointAnnotationManager != null) {
      pointAnnotationManager!.deleteAll().catchError((e) {
        print(
            "[QuestStartScreen] Error during pointAnnotationManager.deleteAll in dispose: $e");
      });
    }
    pointAnnotationManager = null; // Explicitly nullify
    mapboxMap = null; // Explicitly nullify
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isQuestChainCompleted && _locations.isNotEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_locations.isEmpty && !_isQuestChainCompleted) {
      return const Scaffold(
          body: Center(child: Text("No locations for this quest. Error.")));
    }

    final safeLocationIndex = _currentLocationIndex.clamp(
        0, _locations.isNotEmpty ? _locations.length - 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest in Progress'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          if (!_isMapInitialized)
            const Center(child: CircularProgressIndicator())
          else
            MapWidget(
              key: const ValueKey('activeQuestMap'),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/mapbox/streets-v12",
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    _locations[safeLocationIndex].longitude,
                    _locations[safeLocationIndex].latitude,
                  ),
                ),
                zoom: 14.0,
              ),
            ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Location ${safeLocationIndex + 1} of ${_locations.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isQuestChainCompleted || _locations.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _openGoogleMapsNavigation(_locations[safeLocationIndex]),
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.navigation, color: Colors.white),
              label:
                  const Text('Navigate', style: TextStyle(color: Colors.white)),
            ),
    );
  }
}

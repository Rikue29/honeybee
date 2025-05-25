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

  @override
  void initState() {
    super.initState();
    _locations = widget.locations;
    _initializeMap();
    _loadMarkerImages();
    _startArrivalSimulation();
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
    final userMarkerBytes = await rootBundle.load('assets/images/marker-here.png');
    
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
    pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
    _addMarkersToMap();
  }

  Future<void> _addMarkersToMap() async {
    if (mapboxMap == null || _locationMarkerImages.isEmpty || _isDisposed) return;

    try {
      // Create point annotation manager if it doesn't exist
      pointAnnotationManager ??= await mapboxMap!.annotations.createPointAnnotationManager();
      
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
            coordinates: Position(currentLocation.longitude, currentLocation.latitude),
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
    print('Starting arrival simulation...'); // Debug log
    Future.delayed(const Duration(seconds:4), () {
      print('Simulated arrival, showing confirmation...'); // Debug log
      if (!mounted) return;
      setState(() {}); // Ensure the widget is in a clean state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showArrivalPrompt();
      });
    });
  }

  void _showArrivalPrompt() {
    if (!mounted) return;
    
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
              'Have you arrived at ${widget.locations[_currentLocationIndex].name}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Not yet'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    print("[QuestStartScreen] User clicked 'Yes' for location: ${widget.locations[_currentLocationIndex].name}");
                    
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
                        settings: const RouteSettings(name: 'MissionDetailsScreen'),
                      ),
                    );

                    print("[QuestStartScreen] Result from MissionDetailsScreen: $missionCompleted for location: ${widget.locations[_currentLocationIndex].name}");

                    if (missionCompleted == true) {
                      if (mounted) {
                        print("[QuestStartScreen] Mission completed, advancing location index from $_currentLocationIndex");
                        setState(() {
                          _currentLocationIndex++;
                        });
                        print("[QuestStartScreen] New location index: $_currentLocationIndex");

                        if (_currentLocationIndex < _locations.length) {
                          _showNavigateToNextPrompt();
                        } else {
                          _showQuestCompleteDialog();
                        }
                      }
                    } else {
                      print("[QuestStartScreen] Mission NOT completed or quiz not started from details.");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text(
                    'Yes',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      // Handle any cleanup if needed after dialog is dismissed
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showNavigateToNextPrompt() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
            const SizedBox(height: 24),
            Flexible(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openGoogleMapsNavigation(_locations[_currentLocationIndex]);
                  _startArrivalSimulation(); // Start the simulation for the next location
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.navigation, color: Colors.white),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Navigate using Google Maps',
                        style: TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestCompleteDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              'Congratulations! You\'ve completed the quest!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'You\'ve earned 400 points!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to home screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Complete Quest',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
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
    pointAnnotationManager?.deleteAll();
    pointAnnotationManager = null;
    mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    _locations[_currentLocationIndex].longitude,
                    _locations[_currentLocationIndex].latitude,
                  ),
                ),
                zoom: 14.0,
              ),
            ),
          
          // Current location indicator
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
                    'Location ${_currentLocationIndex + 1} of ${_locations.length}',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoogleMapsNavigation(_locations[_currentLocationIndex]),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.navigation, color: Colors.white),
        label: const Text('Navigate', style: TextStyle(color: Colors.white)),
      ),
    );
  }
} 
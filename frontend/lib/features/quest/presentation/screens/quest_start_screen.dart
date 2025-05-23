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

class QuestStartScreen extends StatefulWidget {
  final List<Location> locations;
  final String city;
  final String questId;

  const QuestStartScreen({
    Key? key,
    required this.locations,
    required this.city,
    required this.questId,
  }) : super(key: key);

  @override
  State<QuestStartScreen> createState() => _QuestStartScreenState();
}

class _QuestStartScreenState extends State<QuestStartScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  List<Uint8List> _locationMarkerImages = [];
  Uint8List? _userMarkerImage;
  bool _isMapInitialized = false;
  bool _isDisposed = false;
  geo.Position? _userLocation;
  LineLayer? _routeLayer;
  Timer? _locationCheckTimer;
  int _currentLocationIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadMarkerImages();
    _getUserLocation();
    _startLocationCheck();
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

  Future<void> _getUserLocation() async {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _userLocation = position;
        });
        _addMarkersToMap();
      }
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  void _onMapCreated(MapboxMap controller) async {
    if (!mounted || _isDisposed) return;
    
    setState(() {
      mapboxMap = controller;
    });

    pointAnnotationManager = await controller.annotations.createPointAnnotationManager();
    _addMarkersToMap();
    _showRouteAnimation();
  }

  Future<void> _addMarkersToMap() async {
    if (mapboxMap == null || _locationMarkerImages.isEmpty || 
        _userMarkerImage == null || _isDisposed) return;

    try {
      await pointAnnotationManager?.deleteAll();

      // Add markers for each location
      for (var i = 0; i < widget.locations.length; i++) {
        if (_isDisposed) return;
        
        final location = widget.locations[i];
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

      // Add user's current location marker
      if (_userLocation != null && !_isDisposed) {
        final userMarkerOptions = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _userLocation!.longitude,
              _userLocation!.latitude,
            ),
          ),
          iconSize: 0.3,
          image: _userMarkerImage,
        );
        await pointAnnotationManager!.create(userMarkerOptions);
      }

      _updateCameraPosition();
    } catch (e) {
      print('Error adding markers: $e');
    }
  }

  void _updateCameraPosition() {
    if (widget.locations.isEmpty || !mounted) return;

    List<double> lngs = widget.locations.map((l) => l.longitude).toList();
    List<double> lats = widget.locations.map((l) => l.latitude).toList();

    if (_userLocation != null) {
      lngs.add(_userLocation!.longitude);
      lats.add(_userLocation!.latitude);
    }

    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);

    final centerLng = (minLng + maxLng) / 2;
    final centerLat = (minLat + maxLat) / 2;

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    final zoom = (14 - (maxDiff * 10)).clamp(11.0, 15.0);

    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
        padding: MbxEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
      ),
    );
  }

  void _showRouteAnimation() async {
    if (widget.locations.isEmpty || mapboxMap == null) return;

    final coordinates = widget.locations.map((loc) => 
      Position(loc.longitude, loc.latitude)
    ).toList();

    // Create a properly formatted GeoJSON object
    final routeGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "LineString",
            "coordinates": coordinates.map((pos) => [pos.lng, pos.lat]).toList(),
          }
        }
      ]
    };

    final sourceId = 'route-source';
    try {
      await mapboxMap!.style.addSource(GeoJsonSource(
        id: sourceId,
        data: jsonEncode(routeGeoJson),
      ));

      _routeLayer = LineLayer(
        id: 'route-layer',
        sourceId: sourceId,
        lineColor: Colors.orange.value,
        lineWidth: 3,
      );

      await mapboxMap!.style.addLayer(_routeLayer!);
    } catch (e) {
      print('Error showing route animation: $e');
    }
  }

  void _startLocationCheck() {
    final locationService = Provider.of<LocationService>(context, listen: false);
    _locationCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (_currentLocationIndex >= widget.locations.length) {
        timer.cancel();
        return;
      }

      final targetLocation = widget.locations[_currentLocationIndex];
      final currentLocation = await locationService.getCurrentLocation();
      
      if (currentLocation == null) return;

      setState(() {
        _userLocation = currentLocation;
      });
      _addMarkersToMap();

      final distance = geo.Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );

      if (distance <= 50) {
        _showArrivalConfirmation();
      }
    });
  }

  void _showArrivalConfirmation() {
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
              'assets/images/bee-helper.png',
              height: 100,
              width: 100,
            ),
            SizedBox(height: 16),
            Text(
              'You have arrived at ${widget.locations[_currentLocationIndex].name}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Not yet'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    try {
                      // Get the quiz mission for this location
                      final missions = await Supabase.instance.client
                          .from('missions')
                          .select()
                          .eq('location_id', widget.locations[_currentLocationIndex].id)
                          .eq('mission_type', 'quiz')
                          .limit(1)
                          .single();

                      if (!mounted) return;

                      // Start the quiz
                      final score = await Navigator.push<int>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            questId: widget.questId,
                            locationId: widget.locations[_currentLocationIndex].id,
                            missionId: missions['id'],
                            locationName: widget.locations[_currentLocationIndex].name,
                          ),
                        ),
                      );

                      if (score != null && mounted) {
                        setState(() {
                          _currentLocationIndex++;
                        });

                        if (_currentLocationIndex < widget.locations.length) {
                          _showNavigateToNextPrompt();
                        } else {
                          _showQuestCompleteDialog();
                        }
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start quiz: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: Text(
                    'Start Quiz',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              'assets/images/bee-helper.png',
              height: 100,
              width: 100,
            ),
            SizedBox(height: 16),
            Text(
              'Ready to head to the next location?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openGoogleMapsNavigation(widget.locations[_currentLocationIndex]);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Navigate using Google Maps',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
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
              'assets/images/bee-helper.png',
              height: 100,
              width: 100,
            ),
            SizedBox(height: 16),
            Text(
              'Congratulations! You\'ve completed the quest!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'You\'ve earned 400 points!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to home screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
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
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationCheckTimer?.cancel();
    pointAnnotationManager?.deleteAll();
    pointAnnotationManager = null;
    mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quest in Progress'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          if (!_isMapInitialized)
            const Center(child: CircularProgressIndicator())
          else
            MapWidget(
              key: ValueKey('activeQuestMap'),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/mapbox/streets-v12",
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    widget.locations.first.longitude,
                    widget.locations.first.latitude,
                  ),
                ),
                zoom: 13.0,
              ),
            ),
          
          // Current location indicator
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Location ${_currentLocationIndex + 1} of ${widget.locations.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Debug controls
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.bug_report, color: Colors.orange),
                onPressed: () {
                  // Simulate arrival at current location
                  _showArrivalConfirmation();
                },
                tooltip: 'Debug: Simulate Arrival',
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoogleMapsNavigation(widget.locations[_currentLocationIndex]),
        backgroundColor: Colors.orange,
        icon: Icon(Icons.navigation, color: Colors.white),
        label: Text('Navigate', style: TextStyle(color: Colors.white)),
      ),
    );
  }
} 
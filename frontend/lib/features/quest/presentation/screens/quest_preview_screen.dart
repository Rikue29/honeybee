import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../services/gemini_service.dart';
import 'dart:math' show min, max;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'quest_page.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' as geo;

class QuestPreviewScreen extends StatefulWidget {
  final List<Location> locations;
  final String city;

  const QuestPreviewScreen({
    Key? key,
    required this.locations,
    required this.city,
  }) : super(key: key);

  @override
  State<QuestPreviewScreen> createState() => _QuestPreviewScreenState();
}

class _QuestPreviewScreenState extends State<QuestPreviewScreen> {
  late List<Location> _locations;
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  bool _isSaving = false;
  List<Uint8List> _locationMarkerImages = [];
  Uint8List? _userMarkerImage;
  bool _isMapInitialized = false;
  bool _isDisposed = false;
  geo.Position? _userLocation;

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
    _initializeMap();
    _loadMarkerImages();
    _getUserLocation();
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

  @override
  void dispose() {
    _isDisposed = true;
    pointAnnotationManager?.deleteAll();
    pointAnnotationManager = null;
    mapboxMap = null;
    super.dispose();
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
    if (mapboxMap == null || _locationMarkerImages.isEmpty || 
        _userMarkerImage == null || _isDisposed) return;

    try {
      // Create point annotation manager if it doesn't exist
      pointAnnotationManager ??= await mapboxMap!.annotations.createPointAnnotationManager();
      
      // Clear existing annotations
      await pointAnnotationManager!.deleteAll();

      // Add markers for each location
      for (var i = 0; i < _locations.length; i++) {
        if (_isDisposed) return;
        
        final location = _locations[i];
        final markerIndex = i % _locationMarkerImages.length; // Cycle through available markers
        
        // Create marker options
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          iconSize: 0.3, // Smaller icon
          image: _locationMarkerImages[markerIndex],
        );

        // Add marker to map
        await pointAnnotationManager!.create(options);
      }

      // Add user's current location marker if available
      if (_userLocation != null && !_isDisposed) {
        final userMarkerOptions = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _userLocation!.longitude,
              _userLocation!.latitude,
            ),
          ),
          iconSize: 0.3, // Smaller icon
          image: _userMarkerImage,
        );
        await pointAnnotationManager!.create(userMarkerOptions);
      }

      // Adjust camera to show all points including user location
      if (_locations.isNotEmpty && !_isDisposed) {
        List<double> lngs = _locations.map((l) => l.longitude).toList();
        List<double> lats = _locations.map((l) => l.latitude).toList();

        // Include user location in bounds calculation if available
        if (_userLocation != null) {
          lngs.add(_userLocation!.longitude);
          lats.add(_userLocation!.latitude);
        }

        final minLng = lngs.reduce(min);
        final maxLng = lngs.reduce(max);
        final minLat = lats.reduce(min);
        final maxLat = lats.reduce(max);

        // Calculate center point
        final centerLng = (minLng + maxLng) / 2;
        final centerLat = (minLat + maxLat) / 2;

        // Calculate appropriate zoom level based on bounds
        final latDiff = (maxLat - minLat).abs();
        final lngDiff = (maxLng - minLng).abs();
        final maxDiff = max(latDiff, lngDiff);
        
        // Adjust zoom level based on the distance between points
        final zoom = max(14 - (maxDiff * 10), 11.0); // Minimum zoom of 11

        final cameraOptions = CameraOptions(
          center: Point(
            coordinates: Position(centerLng, centerLat),
          ),
          zoom: zoom,
          // Add padding to ensure markers aren't too close to edges
          padding: MbxEdgeInsets(
            top: 100,
            left: 50,
            bottom: 200, // Extra padding for bottom sheet
            right: 50,
          ),
        );

        await mapboxMap?.setCamera(cameraOptions);
      }
    } catch (e) {
      print('Error adding markers: $e');
    }
  }

  void _removeLocation(int index) {
    setState(() {
      _locations.removeAt(index);
      _addMarkersToMap();
    });
  }

  Future<void> _saveQuest() async {
    setState(() => _isSaving = true);

    try {
      // TODO: Implement actual save to database
      await Future.delayed(Duration(seconds: 2)); // Simulate network delay
      
      if (!mounted) return;
      Navigator.pop(context); // Return to home screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save quest: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Day in ${widget.city}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => QuestPage()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_isMapInitialized)
            const Center(child: CircularProgressIndicator())
          else
            MapWidget(
              key: ValueKey('previewMap'),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/mapbox/streets-v12",
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    _locations.first.longitude,
                    _locations.first.latitude,
                  ),
                ),
                zoom: 13.0,
              ),
            ),

          // Draggable itinerary sheet
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        scrollController: scrollController,
                        itemCount: _locations.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _locations.removeAt(oldIndex);
                            _locations.insert(newIndex, item);
                            _addMarkersToMap();
                          });
                        },
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          return Dismissible(
                            key: ValueKey(location.name),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 16),
                              child: Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) => _removeLocation(index),
                            child: Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                  backgroundColor: Colors.orange,
                                ),
                                title: Text(location.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(location.timeSlot),
                                    Text(
                                      location.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Icon(Icons.drag_handle),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_isSaving)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveQuest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Start Quest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _saveQuest,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Save Quest',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
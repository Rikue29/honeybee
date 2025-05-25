import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/features/explore/models/poi.dart';
import 'package:honeybee/features/explore/services/poi_service.dart';
import 'package:honeybee/features/explore/widgets/poi_details_sheet.dart';
import 'package:honeybee/features/home/presentation/screens/home_screen.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_page.dart';

// Custom click listener for point annotations
class POIClickListener implements OnPointAnnotationClickListener {
  final Function(PointAnnotation) onClick;

  POIClickListener({required this.onClick});

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    onClick(annotation);
    return true;
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  MapboxMap? _mapboxMap;
  final _poiService = POIService();
  List<POI>? _pois;
  PointAnnotationManager? _pointAnnotationManager;
  final Map<String, PointAnnotation> _annotations = {};
  bool _isMapInitialized = false;
  bool _isDisposed = false;
  List<Uint8List> _markerImages = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadMarkerImages();
    _loadPOIs();
  }

  void _initializeMap() {
    try {
      String accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      debugPrint('Initializing map with access token length: ${accessToken.length}');
      MapboxOptions.setAccessToken(accessToken);
      if (mounted) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  Future<void> _loadMarkerImages() async {
    if (_isDisposed) return;
    
    try {
      debugPrint('Loading marker image...');
      final markerBytes = await rootBundle.load('assets/images/marker.png');
      if (!_isDisposed && mounted) {
        _markerImages = [markerBytes.buffer.asUint8List()];
      }
      debugPrint('Loaded marker image');
      
      // If POIs are already loaded, add markers
      if (_pois != null) {
        _addPOIMarkers();
      }
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }
  }

  Future<void> _loadPOIs() async {
    try {
      debugPrint('Loading POIs...');
      final pois = await _poiService.getPOIs();
      debugPrint('Loaded ${pois.length} POIs');
      if (!_isDisposed && mounted) {
        setState(() {
          _pois = pois;
        });
        _addPOIMarkers();
      }
    } catch (e) {
      debugPrint('Error loading POIs: $e');
    }
  }

  Future<void> _addPOIMarkers() async {
    debugPrint('Adding POI markers...');
    if (_mapboxMap == null || _pois == null || _pointAnnotationManager == null || _markerImages.isEmpty) {
      debugPrint('Cannot add markers: mapboxMap: ${_mapboxMap != null}, pois: ${_pois != null}, pointAnnotationManager: ${_pointAnnotationManager != null}, markerImages: ${_markerImages.length}');
      return;
    }

    try {
      // Clear existing annotations
      await _pointAnnotationManager!.deleteAll();
      _annotations.clear();

      debugPrint('Adding markers for ${_pois!.length} POIs');
      for (var poi in _pois!) {
        debugPrint('Creating marker for ${poi.name} at (${poi.latitude}, ${poi.longitude})');
        
        // Create point geometry
        final point = Point(coordinates: Position(poi.longitude, poi.latitude));
        debugPrint('Created point geometry: $point');

        final options = PointAnnotationOptions(
          geometry: point,
          image: _markerImages[0], // Always use the single marker image
          iconSize: 0.3,
          textField: poi.name,
          textSize: 13.0,
          textOffset: [0.0, -2.0],
          textColor: const Color.fromARGB(255, 0, 0, 0).value,
          textHaloColor: Colors.white.value,
          textHaloWidth: 2.0,
        );

        final annotation = await _pointAnnotationManager!.create(options);
        debugPrint('Created annotation: $annotation');
        _annotations[poi.id] = annotation;
      }

      // After adding all markers, update the camera to show all POIs
      if (_pois!.isNotEmpty) {
        // Calculate the center point of all POIs
        final centerLat = _pois!.map((p) => p.latitude).reduce((a, b) => a + b) / _pois!.length;
        final centerLon = _pois!.map((p) => p.longitude).reduce((a, b) => a + b) / _pois!.length;
        
        // Calculate the maximum distance from center to determine zoom
        final maxLatDist = _pois!.map((p) => (p.latitude - centerLat).abs()).reduce(math.max);
        final maxLonDist = _pois!.map((p) => (p.longitude - centerLon).abs()).reduce(math.max);
        
        debugPrint('Setting camera to center: ($centerLat, $centerLon)');
        await _mapboxMap!.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(centerLon, centerLat)),
            zoom: 15.0,
            padding: MbxEdgeInsets(top: 100, left: 50, bottom: 50, right: 50),
          ),
        );
      }

      // Set up click listener
      _pointAnnotationManager!.addOnPointAnnotationClickListener(
        POIClickListener(
          onClick: (annotation) {
            final index = _pois!.indexWhere(
              (p) => _annotations[p.id] == annotation,
            );
            if (index != -1) {
              _showPOIDetails(_pois![index]);
            }
          },
        ),
      );

      debugPrint('Finished adding POI markers');
    } catch (e, stackTrace) {
      debugPrint('Error adding POI markers: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _showPOIDetails(POI poi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => POIDetailsSheet(poi: poi),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!_isMapInitialized)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          else
            MapWidget(
              key: const ValueKey('explore_map'),
              onMapCreated: (MapboxMap mapboxMap) async {
                debugPrint('Map created');
                _mapboxMap = mapboxMap;
                
                debugPrint('Creating point annotation manager');
                _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                debugPrint('Point annotation manager created');
                
                // Set initial camera position to Sultan Abu Bakar Museum
                final initialPosition = Point(
                  coordinates: Position(
                    103.390350, // Sultan Abu Bakar Museum longitude
                    3.493542,   // Sultan Abu Bakar Museum latitude
                  ),
                );
                debugPrint('Setting initial camera position to: $initialPosition');
                await mapboxMap.setCamera(
                  CameraOptions(
                    center: initialPosition,
                    zoom: 14.0, // Adjusted zoom level
                  ),
                );
                debugPrint('Initial camera position set');

                if (_pois != null) {
                  debugPrint('POIs already loaded, adding markers');
                  await _addPOIMarkers();
                }
              },
              styleUri: "mapbox://styles/mapbox/streets-v12",
            ),
          // Title and Search Bar Container
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 70, left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore Pekan',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search places in Pekan',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
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
    _isDisposed = true;
    if (_pointAnnotationManager != null) {
      _pointAnnotationManager!.deleteAll();
    }
    _pointAnnotationManager = null;
    _mapboxMap = null;
    super.dispose();
  }
} 
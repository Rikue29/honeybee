import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:honeybee/features/home/presentation/screens/home_screen.dart'; // For navigation

class NextAreaTransitionScreen extends StatefulWidget {
  final String completedAreaName;
  final Point completedAreaCoordinates;
  final String nextAreaName;
  final Point nextAreaCoordinates;
  final String nextAreaDescription;

  const NextAreaTransitionScreen({
    super.key,
    required this.completedAreaName,
    required this.completedAreaCoordinates,
    required this.nextAreaName,
    required this.nextAreaCoordinates,
    required this.nextAreaDescription,
  });

  @override
  State<NextAreaTransitionScreen> createState() =>
      _NextAreaTransitionScreenState();
}

class _NextAreaTransitionScreenState extends State<NextAreaTransitionScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  bool _markersAdded = false;
  bool _isMapTokenInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMapToken();
  }

  void _initializeMapToken() {
    final String mapboxAccessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(mapboxAccessToken);
      if (mounted) {
        setState(() {
          _isMapTokenInitialized = true;
        });
      }
    } else {
      print(
          "MAPBOX_ACCESS_TOKEN not found in .env file for NextAreaTransitionScreen");
      if (mounted) {
        setState(() {
          _isMapTokenInitialized =
              false; // Explicitly set to false if token is missing
        });
      }
    }
  }

  Future<Uint8List> _loadMarkerImage(String assetName) async {
    final ByteData byteData = await rootBundle.load('assets/images/$assetName');
    return byteData.buffer.asUint8List();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    mapboxMap.annotations.createPointAnnotationManager().then((manager) async {
      pointAnnotationManager = manager;
      await _addMarkers();
    });
    _setCameraPosition();
  }

  Future<void> _addMarkers() async {
    if (pointAnnotationManager == null || _markersAdded) return;

    final Uint8List markerImage = await _loadMarkerImage('marker.png');

    pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: widget.completedAreaCoordinates,
      image: markerImage,
      iconSize: 0.18,
      iconOpacity: 0.4,
    ));

    pointAnnotationManager?.create(PointAnnotationOptions(
      geometry: widget.nextAreaCoordinates,
      image: markerImage,
      iconSize: 0.18,
      iconOpacity: 1.0,
    ));
    if (mounted) {
      setState(() {
        _markersAdded = true;
      });
    }
  }

  void _setCameraPosition() {
    if (mapboxMap == null) return;

    final centerLat = (widget.completedAreaCoordinates.coordinates.lat +
            widget.nextAreaCoordinates.coordinates.lat) /
        2;
    final centerLng = (widget.completedAreaCoordinates.coordinates.lng +
            widget.nextAreaCoordinates.coordinates.lng) /
        2;

    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 10.0,
      ),
      MapAnimationOptions(duration: 1500, startDelay: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMapTokenInitialized) {
      return const Scaffold(
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing map...'),
            Text('(Ensure MAPBOX_ACCESS_TOKEN is in .env)',
                style: TextStyle(color: Colors.grey)),
          ],
        )),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('nextAreaMap'),
            styleUri:
                MapboxStyles.MAPBOX_STREETS, // Using a default public style
            cameraOptions: CameraOptions(
              center: widget
                  .nextAreaCoordinates, // Initial camera, will be updated by flyTo
              zoom: 10.0,
            ),
            onMapCreated: _onMapCreated,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20.0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ready for Your Next Journey?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.nextAreaDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Notify Me',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.white),
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
}

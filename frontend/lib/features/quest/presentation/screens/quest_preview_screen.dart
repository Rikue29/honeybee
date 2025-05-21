import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../services/gemini_service.dart';
import 'dart:math' show min, max;

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
    _addMarkersToMap();
  }

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    _addMarkersToMap();
  }

  Future<void> _addMarkersToMap() async {
    if (mapboxMap == null) return;

    // Clear existing annotations
    final annotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
    await annotationManager.deleteAll();

    // Add markers for each location
    for (var i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      
      // Create marker options
      final options = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(location.longitude, location.latitude),
        ),
        textField: '${i + 1}',
        textSize: 16.0,
        textColor: Colors.white.value,
        iconSize: 1.5,
        textOffset: [0.0, 0.0],
        iconImage: "marker",
      );

      // Add marker to map
      await annotationManager.create(options);
    }

    // Adjust camera to show all markers
    if (_locations.isNotEmpty) {
      final minLng = _locations.map((l) => l.longitude).reduce(min);
      final maxLng = _locations.map((l) => l.longitude).reduce(max);
      final minLat = _locations.map((l) => l.latitude).reduce(min);
      final maxLat = _locations.map((l) => l.latitude).reduce(max);

      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            (minLng + maxLng) / 2,
            (minLat + maxLat) / 2,
          ),
        ),
        zoom: 13.0,
      );

      mapboxMap?.setCamera(cameraOptions);
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Map view (1/3 of screen)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: MapWidget(
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
              ),

              // Itinerary list (2/3 of screen)
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.all(16),
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
                    return Card(
                      key: ValueKey(location.name),
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
                    );
                  },
                ),
              ),
            ],
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
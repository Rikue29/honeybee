import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/core/services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  MapboxMap? _mapController;
  List<Map<String, dynamic>> _quests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuests();
    _startLocationTracking();
  }

  Future<void> _loadQuests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('quests')
          .select('*, quest_locations(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _quests = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load quests';
        _isLoading = false;
      });
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location tracking error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapController = mapboxMap;
    _updateMapMarkers();
  }

  void _updateMapMarkers() {
    if (_mapController == null) return;

    // Clear existing markers
    // Clear existing markers
    _mapController?.annotations.createPointAnnotationManager().then((manager) {
      manager.deleteAll();
    });

    // Add markers for each quest location
    for (final quest in _quests) {
      for (final location in quest['quest_locations']) {
        _mapController!.annotations
            .createPointAnnotationManager()
            .then((pointAnnotationManager) async {
          final ByteData bytes =
              await rootBundle.load('assets/symbols/custom-icon.png');
          final Uint8List list = bytes.buffer.asUint8List();
          pointAnnotationManager.create(PointAnnotationOptions(
            geometry: Point(
                coordinates: Position(
              location['longitude'] as double,
              location['latitude'] as double,
            )),
            image: list,
          ));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Honeybee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Map View
                    Expanded(
                      flex: 2,
                      child: MapWidget(
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: Position(0.0, 0.0)),
                          zoom: 2,
                          bearing: 0,
                          pitch: 0,
                        ),
                        onMapCreated: _onMapCreated,
                        styleUri: 'mapbox://styles/mapbox/streets-v12',
                      ),
                    ),

                    // Quest List
                    Expanded(
                      flex: 1,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quests.length,
                        itemBuilder: (context, index) {
                          final quest = _quests[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.flag),
                              title: Text(quest['title']),
                              subtitle: Text(quest['description']),
                              trailing: Text(
                                '${quest['points']} pts',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              onTap: () {
                                // TODO: Navigate to quest details
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to new quest creation
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _mapController?.dispose();
    super.dispose();
  }
}

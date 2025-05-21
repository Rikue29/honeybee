import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/features/quest/presentation/screens/quest_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  int _selectedIndex = 0;
  bool _isDisposed = false;
  PointAnnotationManager? _pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');
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

  void _onMapCreated(MapboxMap mapboxMap) async {
    if (_isDisposed) return;
    _mapController = mapboxMap;
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _updateMapMarkers();
  }

  void _updateMapMarkers() async {
    if (_mapController == null || _isDisposed) return;

    try {
      // Clear existing markers
      await _pointAnnotationManager?.deleteAll();

      // Add markers for each quest location
      for (final quest in _quests) {
        if (_isDisposed) return; // Check if disposed before continuing
        
        for (final location in quest['quest_locations']) {
          if (_isDisposed) return; // Check if disposed before continuing
          
          final ByteData bytes = await rootBundle.load('assets/symbols/custom-icon.png');
          final Uint8List list = bytes.buffer.asUint8List();
          
          if (!_isDisposed && _pointAnnotationManager != null) {
            await _pointAnnotationManager!.create(PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(
                  location['longitude'] as double,
                  location['latitude'] as double,
                ),
              ),
              image: list,
            ));
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('Error updating map markers: $e');
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
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: Position(103.3894, 3.5057)), // Pekan coordinates
                          zoom: 12,
                          bearing: 0,
                          pitch: 0,
                        ),
                        onMapCreated: _onMapCreated,
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Quest',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          
          // Handle navigation based on index
          switch (index) {
            case 0: // Home
              // Already on home screen
              break;
            case 1: // Quest
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuestPage()),
              );
              break;
            case 2: // Explore
              // TODO: Implement explore screen navigation
              break;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pointAnnotationManager?.deleteAll();
    _pointAnnotationManager = null;
    _locationService.stopTracking();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }
}

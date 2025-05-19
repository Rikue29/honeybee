import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/core/services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _locationService = LocationService();
  MapboxMapController? _mapController;
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

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    _updateMapMarkers();
  }

  void _updateMapMarkers() {
    if (_mapController == null) return;

    // Clear existing markers
    _mapController!.clearSymbols();

    // Add markers for each quest location
    for (final quest in _quests) {
      for (final location in quest['quest_locations']) {
        _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(
              location['latitude'],
              location['longitude'],
            ),
            iconImage: 'marker-15',
            iconSize: 2.0,
            textField: location['name'],
            textOffset: const Offset(0, 1.5),
            textColor: '#000000',
            textSize: 12.0,
          ),
        );
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
                      child: MapboxMap(
                        accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(0, 0), // Will be updated with user location
                          zoom: 12,
                        ),
                        styleString: MapboxStyles.MAPBOX_STREETS,
                        myLocationEnabled: true,
                        myLocationTrackingMode: MyLocationTrackingMode.Tracking,
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
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
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/gemini_service.dart';
import 'quest_preview_screen.dart';
import 'package:honeybee/features/home/presentation/screens/home_screen.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/core/services/geocoding_service.dart';
import 'package:provider/provider.dart';

class QuestPage extends StatefulWidget {
  const QuestPage({Key? key}) : super(key: key);

  @override
  _QuestPageState createState() => _QuestPageState();
}

class _QuestPageState extends State<QuestPage> {
  int _currentStep = 0;
  String? selectedCity;
  double? selectedLatitude;
  double? selectedLongitude;
  int selectedDuration = 1;
  List<String> selectedInterests = [];
  List<String> selectedCuisine = [];
  MapboxMap? mapboxMap;
  bool _isQuestCreated = false;
  bool _isGenerating = false;
  bool _showLoadingScreen = false;
  bool _isMapInitialized = false;
  final _geminiService = GeminiService();
  final _geocodingService = GeocodingService();
  bool _isDisposed = false;
  bool _isLoadingLocation = true;
  bool _isSearching = false;
  List<City> _searchResults = [];
  List<City> _nearestCities = [];
  final _searchController = TextEditingController();

  final List<String> availableCities = ['Pekan'];
  final List<int> availableDurations = [1, 2, 3, 7];
  final List<String> interests = [
    'Historical Sites',
    'Nature',
    'Local Culture',
    'Shopping',
    'Architecture',
    'Museums'
  ];
  final List<String> cuisineTypes = [
    'Local Malaysian',
    'Seafood',
    'Vegetarian',
    'Street Food',
    'International',
    'Halal'
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _detectCurrentCity();
  }

  void _initializeMap() {
    try {
      String accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      MapboxOptions.setAccessToken(accessToken);
      if (mounted && !_isDisposed) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing map: $e');
    }
  }

  Future<void> _detectCurrentCity() async {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentLocation();
      
      if (position != null) {
        final city = await _geocodingService.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (city != null && mounted) {
          // Get nearest cities
          final nearestCities = await _geocodingService.getNearestCities(
            position.latitude,
            position.longitude,
          );

          if (mounted) {
            setState(() {
              selectedCity = city.name;
              selectedLatitude = city.latitude;
              selectedLongitude = city.longitude;
              _isLoadingLocation = false;
              _searchController.text = city.fullName;
              _nearestCities = nearestCities;
              if (mapboxMap != null) {
                mapboxMap?.setCamera(
                  CameraOptions(
                    center: Point(coordinates: Position(city.longitude, city.latitude)),
                    zoom: 12.0,
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error detecting city: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isDisposed = true;
    mapboxMap = null;
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) {
    if (!mounted || _isDisposed) return;
    setState(() {
      mapboxMap = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!_isMapInitialized)
            const Center(child: CircularProgressIndicator())
          else
            MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
              styleUri: "mapbox://styles/mapbox/streets-v12",
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(103.3894, 3.5057)), // Pekan coordinates
                zoom: 12.0,
                bearing: 0.0,
                pitch: 0.0,
              ),
            ),
          if (_showLoadingScreen)
            Container(
              color: const Color(0xFFFFF8E1), // Light cream background
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/bee_quest.png', width: 60, height: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Creating Your Quest',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 200,
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFFFFE0B2), // Light orange color
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_isQuestCreated)
            Container(
              color: const Color(0xFFFFF8E1), // Light cream background
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/bee_quest.png', width: 60, height: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Quest Created!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get ready to\nexplore Pekan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.brown,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildCurrentStep(),
        ],
      ),
      bottomNavigationBar: (!_showLoadingScreen && !_isQuestCreated) ? BottomNavigationBar(
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
        currentIndex: 1, // Quest tab is selected
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          } else if (index == 2) {
            // TODO: Navigate to explore screen
          }
        },
      ) : null,
    );
  }

  void _updateMapCamera() {
    if (selectedLatitude != null && selectedLongitude != null) {
      mapboxMap?.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(selectedLongitude!, selectedLatitude!)),
          zoom: 14.0,
        ),
      );
    }
  }

  Future<void> _searchCities(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _geocodingService.searchCities(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching cities: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _selectCity(City city) {
    setState(() {
      selectedCity = city.name;
      selectedLatitude = city.latitude;
      selectedLongitude = city.longitude;
      _searchResults = [];
      _searchController.text = city.fullName;
    });
    _updateMapCamera();
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildLocationSelection();
      case 1:
        return _buildDurationSelection();
      case 2:
        return _buildInterestsSelection();
      case 3:
        return _buildCuisineSelection();
      case 4:
        return _buildQuestOverview();
      default:
        return Container();
    }
  }

  Widget _buildLocationSelection() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Your Adventure',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Where are you going?',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingLocation)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              )
            else
              Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a city',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      _searchCities(value);
                    },
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                    )
                  else if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final city = _searchResults[index];
                          return ListTile(
                            title: Text(city.name),
                            subtitle: Text(
                              [city.state, city.country]
                                  .where((e) => e != null)
                                  .join(', '),
                            ),
                            onTap: () => _selectCity(city),
                          );
                        },
                      ),
                    )
                  else if (_nearestCities.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cities near you',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_nearestCities.length, (index) {
                            final city = _nearestCities[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.orange),
                              title: Text(city.name),
                              subtitle: Text(
                                [
                                  if (city.distance != null)
                                    '${city.distance!.toStringAsFixed(1)} km away',
                                  city.state,
                                  city.country,
                                ].where((e) => e != null).join(' • '),
                              ),
                              onTap: () => _selectCity(city),
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedCity != null
                          ? () {
                              setState(() {
                                _currentStep++;
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelection() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Trip Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var duration in availableDurations)
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedDuration = duration;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedDuration == duration
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedDuration == duration
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        duration == 7 ? '1 week' : '$duration days',
                        style: TextStyle(
                          color: selectedDuration == duration
                              ? Colors.orange
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep++;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSelection() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.interests),
                const SizedBox(width: 8),
                const Text(
                  'Interests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'What would you like to see?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: interests.map((interest) {
                final isSelected = selectedInterests.contains(interest);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedInterests.remove(interest);
                      } else {
                        selectedInterests.add(interest);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color:
                          isSelected ? Colors.orange.withOpacity(0.1) : Colors.white,
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedInterests.isNotEmpty
                        ? () {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuisineSelection() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu),
                const SizedBox(width: 8),
                const Text(
                  'Cuisine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Food preferences?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cuisineTypes.map((cuisine) {
                final isSelected = selectedCuisine.contains(cuisine);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedCuisine.remove(cuisine);
                      } else {
                        selectedCuisine.add(cuisine);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color:
                          isSelected ? Colors.orange.withOpacity(0.1) : Colors.white,
                    ),
                    child: Text(
                      cuisine,
                      style: TextStyle(
                        color: isSelected ? Colors.orange : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedCuisine.isNotEmpty
                        ? () {
                            setState(() {
                              _currentStep++;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateQuest() async {
    setState(() {
      _isGenerating = true;
      _showLoadingScreen = true;
    });

    try {
      final locations = await _geminiService.generateItinerary(
        city: selectedCity!,
        duration: selectedDuration,
        interests: selectedInterests,
        cuisinePreferences: selectedCuisine,
      );

      if (!mounted) return;

      // Navigate to preview screen immediately after getting locations
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestPreviewScreen(
            locations: locations,
            city: selectedCity!,
          ),
        ),
      );

      // Reset state after navigation
      if (mounted) {
        setState(() {
          _showLoadingScreen = false;
          _isQuestCreated = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showLoadingScreen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate quest: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _buildQuestOverview() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Your Quest Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildOverviewItem(
              'Trip Location',
              '$selectedCity, Pahang',
              Icons.location_on,
            ),
            const SizedBox(height: 12),
            _buildOverviewItem(
              'Trip Duration',
              selectedDuration == 7 ? '1 week' : '$selectedDuration day',
              Icons.access_time,
            ),
            const SizedBox(height: 12),
            _buildOverviewItem(
              'Interests',
              selectedInterests.join(', '),
              Icons.interests,
            ),
            const SizedBox(height: 12),
            _buildOverviewItem(
              'Cuisine',
              selectedCuisine.join(', '),
              Icons.restaurant_menu,
            ),
            const SizedBox(height: 20),
            const Text(
              'Looking good!',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _generateQuest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: _isGenerating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Create Quest',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 
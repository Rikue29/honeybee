import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/gemini_service.dart';
import 'quest_preview_screen.dart';

class QuestPage extends StatefulWidget {
  const QuestPage({Key? key}) : super(key: key);

  @override
  _QuestPageState createState() => _QuestPageState();
}

class _QuestPageState extends State<QuestPage> {
  int _currentStep = 0;
  String? selectedCity;
  int selectedDuration = 1;
  List<String> selectedInterests = [];
  List<String> selectedCuisine = [];
  MapboxMap? mapboxMap;
  bool _isQuestCreated = false;
  bool _isGenerating = false;
  bool _showLoadingScreen = false;
  final _geminiService = GeminiService();

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
    String accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    MapboxOptions.setAccessToken(accessToken);
  }

  void _onMapCreated(MapboxMap controller) {
    setState(() {
      mapboxMap = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
            Navigator.pop(context); // Go back to home
          } else if (index == 2) {
            // TODO: Navigate to explore screen
          }
        },
      ) : null,
    );
  }

  void _updateMapCamera() {
    mapboxMap?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(103.3894, 3.5057)), // Pekan coordinates
        zoom: 14.0,
      ),
    );
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
            TextField(
              decoration: InputDecoration(
                hintText: 'State/City',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              readOnly: true,
              onTap: () {
                setState(() {
                  selectedCity = 'Pekan';
                  _updateMapCamera();
                });
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.location_city, size: 50, color: Colors.orange),
              title: const Text('Pekan'),
              onTap: () {
                setState(() {
                  selectedCity = 'Pekan';
                  _updateMapCamera();
                });
              },
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

      setState(() {
        _showLoadingScreen = false;
        _isQuestCreated = true;
      });

      // Navigate to preview screen immediately
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestPreviewScreen(
            locations: locations,
            city: selectedCity!,
          ),
        ),
      );
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
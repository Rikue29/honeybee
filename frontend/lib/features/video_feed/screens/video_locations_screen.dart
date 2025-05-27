import 'package:flutter/material.dart';

class VideoLocationsScreen extends StatelessWidget {
  const VideoLocationsScreen({super.key});

  // Sample locations data - in a real app, this would come from your backend
  final List<Map<String, String>> locations = const [
    {
      'name': 'Istana Abu Bakar',
      'description': 'Historical palace in Pekan, Pahang',
      'image': 'assets/images/istana_abubakar.png',
    },
    {
      'name': 'Pekan Waterfront',
      'description': 'Scenic riverside location in Pekan',
      'image': 'assets/images/location_waterfront.JPG',
    },
    {
      'name': 'Sultan Abu Bakar Museum',
      'description': 'Royal museum showcasing Pahang heritage',
      'image': 'assets/images/sultan_museum.png',
    },
    {
      'name': 'Sultan Abdullah Mosque',
      'description': 'Historic mosque with beautiful architecture',
      'image': 'assets/images/masjid_sultan_abdullah.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Locations'),
        backgroundColor: Color(0xFFFFFDE7),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final location = locations[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  location['image']!,
                  height: 150, // Reduced from 200
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(12), // Reduced from 16
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location['name']!,
                        style: const TextStyle(
                          fontSize: 18, // Reduced from 20
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced from 8
                      Text(
                        location['description']!,
                        style: const TextStyle(
                          fontSize: 14, // Reduced from 16
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

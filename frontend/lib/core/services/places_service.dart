import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Place {
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final double distance; // in meters
  final String? address;

  Place({
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distance,
    this.address,
  });

  factory Place.fromMapbox(Map<String, dynamic> json) {
    final coordinates = List<double>.from(json['geometry']['coordinates']);
    final properties = json['properties'] as Map<String, dynamic>;
    
    return Place(
      name: properties['name'] ?? 'Unknown Place',
      category: properties['category'] ?? 'place',
      longitude: coordinates[0],
      latitude: coordinates[1],
      distance: (properties['distance'] ?? 0).toDouble(),
      address: properties['address'],
    );
  }
}

class PlacesService {
  final String apiKey;

  PlacesService() : apiKey = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    String type = 'restaurant', // restaurant, cafe, attraction, etc.
    int limit = 5,
    int radiusMeters = 1000,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('Mapbox API key not found');
    }

    try {
      // Use Mapbox's Places API to search for nearby places
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json'
        '?access_token=$apiKey'
        '&types=$type'
        '&limit=$limit'
        '&radius=$radiusMeters'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null) {
          return List<Place>.from(
            data['features'].map((feature) => Place.fromMapbox(feature))
          );
        }
      }
      return [];
    } catch (e) {
      print('Error getting nearby places: $e');
      return [];
    }
  }
} 
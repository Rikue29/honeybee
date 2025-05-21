import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class City {
  final String name;
  final double latitude;
  final double longitude;
  final String? state;
  final String? country;
  final double? distance; // Distance in kilometers

  City({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.state,
    this.country,
    this.distance,
  });

  factory City.fromMapbox(Map<String, dynamic> json) {
    final coordinates = List<double>.from(json['center']);
    final context = List<Map<String, dynamic>>.from(json['context'] ?? []);
    
    String? state;
    String? country;
    
    for (var item in context) {
      if (item['id']?.startsWith('region') == true) {
        state = item['text'];
      } else if (item['id']?.startsWith('country') == true) {
        country = item['text'];
      }
    }

    return City(
      name: json['text'],
      longitude: coordinates[0],
      latitude: coordinates[1],
      state: state,
      country: country,
    );
  }

  String get fullName {
    final parts = [name];
    if (state != null) parts.add(state!);
    if (country != null) parts.add(country!);
    return parts.join(', ');
  }
}

class GeocodingService {
  final String apiKey;

  GeocodingService() : apiKey = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  Future<City?> getCityFromCoordinates(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      throw Exception('Mapbox API key not found');
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$apiKey&types=place'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          return City.fromMapbox(data['features'][0]);
        }
      }
      return null;
    } catch (e) {
      print('Error getting city name: $e');
      return null;
    }
  }

  Future<List<City>> getNearestCities(double latitude, double longitude) async {
    if (apiKey.isEmpty) {
      throw Exception('Mapbox API key not found');
    }

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$apiKey&types=place&limit=3&radius=100000'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null) {
          return List<City>.from(
            data['features'].map((feature) {
              final city = City.fromMapbox(feature);
              // Calculate rough distance in kilometers using the Haversine formula
              final distance = _calculateDistance(
                latitude, longitude,
                city.latitude, city.longitude,
              );
              return City(
                name: city.name,
                latitude: city.latitude,
                longitude: city.longitude,
                state: city.state,
                country: city.country,
                distance: distance,
              );
            }),
          );
        }
      }
      return [];
    } catch (e) {
      print('Error getting nearest cities: $e');
      return [];
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = 
      sin(dLat/2) * sin(dLat/2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
      sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<List<City>> searchCities(String query) async {
    if (apiKey.isEmpty) {
      throw Exception('Mapbox API key not found');
    }

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=$apiKey&types=place&limit=5'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['features'] != null) {
          return List<City>.from(
            data['features'].map((feature) => City.fromMapbox(feature))
          );
        }
      }
      return [];
    } catch (e) {
      print('Error searching cities: $e');
      return [];
    }
  }
} 
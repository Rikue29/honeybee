import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Location {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String timeSlot;
  final String category;
  final String? missionId;

  Location({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.timeSlot,
    required this.category,
    this.missionId,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      timeSlot: json['timeSlot'],
      category: json['category'],
      missionId: json['missionId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'timeSlot': timeSlot,
      'category': category,
      'missionId': missionId,
    };
  }
}

class GeminiService {
  final String apiKey;

  GeminiService() : apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<List<Location>> generateItinerary({
    required String city,
    required int duration,
    required List<String> interests,
    required List<String> cuisinePreferences,
  }) async {
    if (city.toLowerCase() == 'pekan') {
      return [
        Location(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Sultan Abu Bakar Museum',
          description: 'A grand museum showcasing the rich history of Pahang\'s royal family and cultural heritage.',
          latitude: 3.4934,
          longitude: 103.4274,
          timeSlot: '9:00 AM',
          category: 'history',
        ),
        Location(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Masjid Sultan Abdullah',
          description: 'A historic mosque built in 1932, featuring beautiful Islamic architecture and spiritual significance.',
          latitude: 3.4927,
          longitude: 103.4266,
          timeSlot: '11:00 AM',
          category: 'culture',
        ),
        Location(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Pekan Riverfront',
          description: 'A scenic waterfront along the Pahang River, perfect for experiencing local life and cuisine.',
          latitude: 3.4930,
          longitude: 103.4261,
          timeSlot: '2:00 PM',
          category: 'leisure',
        ),
        Location(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Abu Bakar Palace',
          description: 'A majestic palace that serves as a testament to Pekan\'s royal heritage and architectural beauty.',
          latitude: 3.4940,
          longitude: 103.4280,
          timeSlot: '4:00 PM',
          category: 'history',
        ),
      ];
    }

    // For other cities, use the Gemini API
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found');
    }

    final prompt = _buildPrompt(
      city: city,
      duration: duration,
      interests: interests,
      cuisinePreferences: cuisinePreferences,
    );

    final response = await _callGeminiAPI(prompt);
    return _parseResponse(response);
  }

  String _buildPrompt({
    required String city,
    required int duration,
    required List<String> interests,
    required List<String> cuisinePreferences,
  }) {
    return '''
    Create a detailed $duration-day itinerary for $city, Malaysia focusing on the following interests: ${interests.join(', ')}.
    Food preferences include: ${cuisinePreferences.join(', ')}.
    
    Please provide the response in the following JSON format:
    {
      "itinerary": [
        {
          "name": "Location name",
          "description": "Brief description",
          "latitude": 0.0,
          "longitude": 0.0,
          "timeSlot": "HH:MM AM/PM",
          "category": "interest category"
        }
      ]
    }
    
    Important:
    - Only include locations within $city
    - Provide actual coordinates for each location
    - Space activities appropriately throughout the day
    - Include food recommendations matching the cuisine preferences
    - Focus on the selected interests
    - Only suggest 4 locations per day
    ''';
  }

  Future<String> _callGeminiAPI(String prompt) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
    
    final response = await http.post(
      Uri.parse('$url?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception('Failed to generate itinerary: ${response.statusCode} - ${errorBody['error']['message']}');
    }
  }

  List<Location> _parseResponse(String response) {
    try {
      // Remove markdown code block formatting if present
      String cleanResponse = response.trim();
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse
          .replaceFirst(RegExp(r'^```(?:json)?\n'), '') // Remove opening ```
          .replaceFirst(RegExp(r'\n```$'), ''); // Remove closing ```
      }
      
      final jsonResponse = jsonDecode(cleanResponse);
      final List<dynamic> itinerary = jsonResponse['itinerary'];
      return itinerary.map((item) => Location.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to parse itinerary response: $e');
    }
  }
} 
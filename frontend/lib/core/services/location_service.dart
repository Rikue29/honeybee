import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:background_location/background_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<LocationData>? _backgroundLocationStream;
  bool _isTracking = false;

  Future<void> initialize() async {
    // Request location permissions
    await _requestPermissions();
    
    // Start background location service
    await BackgroundLocation.setAndroidNotification(
      title: "Honeybee Location Tracking",
      message: "Tracking your location for quest check-ins",
      icon: "@mipmap/ic_launcher",
    );
    
    await BackgroundLocation.startLocationService();
  }

  Future<void> _requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    // Start foreground location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    ).listen(_handleLocationUpdate);

    // Start background location updates
    _backgroundLocationStream = BackgroundLocation.getLocationUpdates(
      (location) async {
        await _handleLocationUpdate(Position(
          latitude: location.latitude!,
          longitude: location.longitude!,
          timestamp: DateTime.now(),
          accuracy: location.accuracy!,
          altitude: location.altitude!,
          heading: location.heading!,
          speed: location.speed!,
          speedAccuracy: location.speedAccuracy!,
        ));
      },
    );
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    await _backgroundLocationStream?.cancel();
    await BackgroundLocation.stopLocationService();
  }

  Future<void> _handleLocationUpdate(Position position) async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Store location update
      await _supabase.from('location_updates').insert({
        'user_id': user.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp?.toIso8601String(),
      });

      // Check for nearby quests
      await _checkNearbyQuests(position);
    } catch (e) {
      print('Error handling location update: $e');
    }
  }

  Future<void> _checkNearbyQuests(Position position) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Query for nearby active quests
      final response = await _supabase
          .from('quests')
          .select('*, quest_locations(*)')
          .eq('user_id', user.id)
          .eq('status', 'active');

      if (response == null) return;

      for (final quest in response) {
        for (final location in quest['quest_locations']) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            location['latitude'],
            location['longitude'],
          );

          // If within 50 meters of a quest location
          if (distance <= 50) {
            await _supabase.from('quest_checkins').insert({
              'quest_id': quest['id'],
              'location_id': location['id'],
              'user_id': user.id,
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    } catch (e) {
      print('Error checking nearby quests: $e');
    }
  }

  Future<void> dispose() async {
    await stopTracking();
  }
} 
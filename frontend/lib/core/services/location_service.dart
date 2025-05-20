import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  late StreamController<Position> _positionStreamController;
  Stream<Position> get positionStream => _positionStreamController.stream;
  bool _isTracking = false;
  bool _isDisposed = false;

  LocationService() {
    _initStreamController();
  }

  void _initStreamController() {
    _positionStreamController = StreamController<Position>.broadcast(
      onListen: () => _isDisposed = false,
      onCancel: () {
        if (!_isDisposed) {
          _positionStreamController.close();
        }
      },
    );
  }

  Future<void> initialize() async {
    // Initialize location service
    await Geolocator.requestPermission();
  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<bool> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Timer? _locationTimer;

  Future<void> startTracking() async {
    if (_isTracking) return;

    if (!await checkLocationPermission()) {
      throw Exception('Location permission not granted');
    }

    // Recreate the stream controller if it's closed
    if (_positionStreamController.isClosed) {
      _initStreamController();
    }

    _isTracking = true;
    try {
      // Start periodic location updates every 5 seconds
      _locationTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _positionStreamController.add(position);
        } catch (e) {
          print('Error getting location: $e');
          _isTracking = false;
          _locationTimer?.cancel();
          rethrow;
        }
      });
    } catch (e) {
      print('Error in location tracking: $e');
      _isTracking = false;
      rethrow;
    }
  }

  void stopTracking() {
    if (!_isTracking) return;

    _isTracking = false;
    _locationTimer?.cancel();
    
    if (!_positionStreamController.isClosed) {
      _positionStreamController.close();
    }
  }
  
  void dispose() {
    _isDisposed = true;
    _locationTimer?.cancel();
    if (!_positionStreamController.isClosed) {
      _positionStreamController.close();
    }
  }
}

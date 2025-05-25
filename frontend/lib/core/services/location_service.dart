import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  late StreamController<Position> _positionStreamController;
  Stream<Position> get positionStream => _positionStreamController.stream;
  bool _isTracking = false;
  bool _isDisposed = false;
  int _errorCount = 0;
  static const int _maxErrorRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  Position? _currentLocation;

  Position? get currentLocation => _currentLocation;

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
    await _checkPermission();
    await _getCurrentLocation();
  }

  Future<void> _checkPermission() async {
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
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentLocation = await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: $e');
    }
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

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
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

  Future<void> _handleLocationError() async {
    _errorCount++;
    if (_errorCount >= _maxErrorRetries) {
      stopTracking();
      // Attempt to restart tracking after a delay
      await Future.delayed(_retryDelay);
      _errorCount = 0;
      await startTracking();
    }
  }

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
    _errorCount = 0;
    
    try {
      // Start periodic location updates every 5 seconds
      _locationTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (!_positionStreamController.isClosed && _isTracking) {
            _positionStreamController.add(position);
            _errorCount = 0; // Reset error count on successful update
          }
        } catch (e) {
          print('Error getting location: $e');
          await _handleLocationError();
        }
      });
    } catch (e) {
      print('Error in location tracking: $e');
      _isTracking = false;
      await _handleLocationError();
    }
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _locationTimer?.cancel();
    _errorCount = 0;
    
    if (!_positionStreamController.isClosed) {
      _positionStreamController.close();
    }
  }
  
  void dispose() {
    _isDisposed = true;
    _locationTimer?.cancel();
    _errorCount = 0;
    if (!_positionStreamController.isClosed) {
      _positionStreamController.close();
    }
  }
}

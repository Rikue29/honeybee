import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart' as provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/app.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/core/theme/app_theme.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Mapbox with access token
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken == null)
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env');
    MapboxOptions.setAccessToken(mapboxToken);

    // Initialize Supabase
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl == null) throw Exception('SUPABASE_URL not found in .env');
    if (supabaseAnonKey == null)
      throw Exception('SUPABASE_ANON_KEY not found in .env');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Initialize location service
    final locationService = LocationService();
    await locationService.initialize();

    // Create and store the AppLifecycleReactor
    final appLifecycle = AppLifecycleReactor(locationService);

    runApp(
      provider.Provider<LocationService>.value(
        value: locationService,
        child: provider.Provider<AppLifecycleReactor>.value(
          value: appLifecycle,
          child: const HoneybeeApp(),
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Error initializing app: $e');
    debugPrint('Stack trace: $stackTrace');
    // You might want to show an error screen here instead of crashing
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

// Helper class to handle app lifecycle events
class AppLifecycleReactor extends WidgetsBindingObserver {
  final LocationService _locationService;
  bool _isDisposed = false;

  AppLifecycleReactor(this._locationService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.paused:
        _locationService.stopTracking();
        break;
      case AppLifecycleState.resumed:
        _locationService.startTracking();
        break;
      case AppLifecycleState.detached:
        dispose();
        break;
      default:
        break;
    }
  }

  void dispose() {
    if (!_isDisposed) {
      _locationService.dispose();
      WidgetsBinding.instance.removeObserver(this);
      _isDisposed = true;
    }
  }
}

class HoneybeeApp extends StatelessWidget {
  const HoneybeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Honeybee',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/app.dart';
import 'package:honeybee/core/services/location_service.dart';
import 'package:honeybee/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Mapbox with access token
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize location service
  final locationService = LocationService();
  await locationService.initialize();

  runApp(
    Provider<LocationService>.value(
      value: locationService,
      child: const HoneybeeApp(),
    ),
  );

  // Ensure resources are cleaned up when the app is closed
  final appLifecycle = AppLifecycleReactor(locationService);
}

// Helper class to handle app lifecycle events
class AppLifecycleReactor extends WidgetsBindingObserver {
  final LocationService _locationService;

  AppLifecycleReactor(this._locationService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in the background
      _locationService.stopTracking();
    } else if (state == AppLifecycleState.resumed) {
      // App is back in the foreground
      _locationService.startTracking();
    } else if (state == AppLifecycleState.detached) {
      // App is being closed
      _locationService.dispose();
      WidgetsBinding.instance.removeObserver(this);
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

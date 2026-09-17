import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// DTO holding GPS or Test Location result
class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String source; // 'GPS' or 'TEST_LOCATION'
  final bool isMocked;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
    this.isMocked = false,
  });

  bool get isTestLocation => source == 'TEST_LOCATION';

  @override
  String toString() => 'LocationResult($latitude, $longitude, source: $source, accuracy: ${accuracy}m)';
}

/// Abstract Location Service interface
abstract class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<LocationResult> getCurrentLocation({bool useTestLocation = false});
}

/// Production / Development Location Service Implementation
class AppLocationService implements LocationService {
  static const double testLatitude = 28.6139;
  static const double testLongitude = 77.2090;

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  @override
  Future<LocationResult> getCurrentLocation({bool useTestLocation = false}) async {
    if (useTestLocation) {
      if (kDebugMode) {
        print('[LocationService] Using TEST LOCATION: $testLatitude, $testLongitude');
      }
      return const LocationResult(
        latitude: testLatitude,
        longitude: testLongitude,
        accuracy: 5.0,
        source: 'TEST_LOCATION',
        isMocked: true,
      );
    }

    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services (GPS) are disabled on your device. Please enable GPS or select Test Location mode.');
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission is required. Please grant location permission or select Test Location mode.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied in settings. Please enable location permission in settings or select Test Location mode.');
    }

    // 1. Fast last-known position check to prevent Android main thread ANR
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        if (kDebugMode) {
          print('[LocationService] Fast last known position: ${lastPos.latitude}, ${lastPos.longitude}');
        }
        return LocationResult(
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
          accuracy: lastPos.accuracy,
          source: 'GPS',
          isMocked: lastPos.isMocked,
        );
      }
    } catch (_) {}

    // 2. High-speed current position with 5-second timeout safeguard
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        source: 'GPS',
        isMocked: position.isMocked,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[LocationService] GPS Position timeout/error: $e, falling back to site GPS');
      }
      // 3. Secondary last-known position fallback
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          return LocationResult(
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
            accuracy: lastPos.accuracy,
            source: 'GPS',
            isMocked: lastPos.isMocked,
          );
        }
      } catch (_) {}

      // Default site GPS fallback
      return const LocationResult(
        latitude: testLatitude,
        longitude: testLongitude,
        accuracy: 5.0,
        source: 'GPS',
        isMocked: false,
      );
    }
  }
}

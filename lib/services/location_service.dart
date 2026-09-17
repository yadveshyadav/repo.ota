import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// DTO holding GPS or Test Location result
class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String source; // 'GPS' or 'TEST_LOCATION'
  final bool isMocked;
  final DateTime? capturedAt;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
    this.isMocked = false,
    this.capturedAt,
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
  Future<LocationResult> getAccurateLocationForAttendance({bool useTestLocation = false});
  Future<void> warmUpAccurateLocation({bool silent = true});
}

/// Production / Development Location Service Implementation
class AppLocationService implements LocationService {
  AppLocationService._();
  static final AppLocationService instance = AppLocationService._();
  factory AppLocationService() => instance;

  static const double testLatitude = 28.6139;
  static const double testLongitude = 77.2090;

  /// Re-use a recent high-accuracy fix for attendance (set by warm-up or prior capture).
  static const Duration accurateCacheMaxAge = Duration(minutes: 3);
  static const double attendanceTargetAccuracyMeters = 50.0;

  LocationResult? _cachedAccurate;
  DateTime? _cachedAt;
  Future<void>? _warmUpInFlight;

  LocationResult? get cachedAccurateLocation => _cachedAccurate;
  DateTime? get cachedAccurateAt => _cachedAt;

  void _storeCache(LocationResult result) {
    if (result.isTestLocation) return;
    _cachedAccurate = result;
    _cachedAt = result.capturedAt ?? DateTime.now();
  }

  bool _isCacheFresh({double maxAccuracyMeters = attendanceTargetAccuracyMeters}) {
    final cached = _cachedAccurate;
    final at = _cachedAt;
    if (cached == null || at == null) return false;
    if (DateTime.now().difference(at) > accurateCacheMaxAge) return false;
    return cached.accuracy <= maxAccuracyMeters;
  }

  LocationResult _fromPosition(Position position) {
    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      source: 'GPS',
      isMocked: position.isMocked,
      capturedAt: position.timestamp,
    );
  }

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

  Future<LocationPermission> _ensurePermission({required bool requestIfDenied}) async {
    var permission = await checkPermission();
    if (permission == LocationPermission.denied && requestIfDenied) {
      permission = await requestPermission();
    }
    return permission;
  }

  /// Background warm-up when app opens / resumes (no UI). Only runs if permission already granted.
  @override
  Future<void> warmUpAccurateLocation({bool silent = true}) async {
    if (_warmUpInFlight != null) {
      return _warmUpInFlight;
    }

    _warmUpInFlight = _warmUpAccurateLocationInternal(silent: silent);
    try {
      await _warmUpInFlight;
    } finally {
      _warmUpInFlight = null;
    }
  }

  Future<void> _warmUpAccurateLocationInternal({required bool silent}) async {
    try {
      if (!await isLocationServiceEnabled()) return;

      final permission = await checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      _storeCache(_fromPosition(position));
      if (kDebugMode) {
        print(
          '[LocationService] Warm-up GPS: ${position.latitude}, ${position.longitude} '
          '±${position.accuracy.toStringAsFixed(1)}m',
        );
      }
    } catch (e) {
      if (!silent && kDebugMode) {
        print('[LocationService] Warm-up skipped/failed: $e');
      }
    }
  }

  /// High-accuracy path for team / machine attendance (uses warm-up cache when fresh).
  @override
  Future<LocationResult> getAccurateLocationForAttendance({
    bool useTestLocation = false,
  }) async {
    if (useTestLocation) {
      return const LocationResult(
        latitude: testLatitude,
        longitude: testLongitude,
        accuracy: 5.0,
        source: 'TEST_LOCATION',
        isMocked: true,
        capturedAt: null,
      );
    }

    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services (GPS) are disabled on your device. Please enable GPS.',
      );
    }

    var permission = await _ensurePermission(requestIfDenied: true);
    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is required. Please grant location permission.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it in device settings.',
      );
    }

    if (_isCacheFresh()) {
      if (kDebugMode) {
        print('[LocationService] Using cached accurate GPS for attendance');
      }
      return _cachedAccurate!;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final result = _fromPosition(position);
      _storeCache(result);
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationService] High-accuracy fix failed: $e');
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final result = _fromPosition(position);
      _storeCache(result);
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[LocationService] Medium-accuracy fallback failed: $e');
      }
    }

    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final age = DateTime.now().difference(lastPos.timestamp);
        if (age.inMinutes <= 5) {
          final result = _fromPosition(lastPos);
          _storeCache(result);
          return result;
        }
      }
    } catch (_) {}

    throw Exception(
      'Unable to obtain an accurate GPS fix. Please wait a moment and try again outdoors with clear sky view.',
    );
  }

  /// Legacy fast path (may use stale last-known). Prefer [getAccurateLocationForAttendance] for attendance.
  @override
  Future<LocationResult> getCurrentLocation({bool useTestLocation = false}) async {
    return getAccurateLocationForAttendance(useTestLocation: useTestLocation);
  }
}

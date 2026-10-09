import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Samples a route when GPS moves at least 3 m or 10 seconds have elapsed.
/// This keeps a useful trace without writing every noisy GPS fix to storage.
class HindranceRouteRecorder {
  StreamSubscription<Position>? _subscription;
  Timer? _interval;
  Position? _lastPosition;
  DateTime? _lastRecordedAt;
  final List<Map<String, dynamic>> _points = [];

  List<Map<String, dynamic>> get points => List.unmodifiable(_points);

  Future<void> start() async {
    await stop();
    _points.clear();
    _lastPosition = null;
    _lastRecordedAt = null;

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on device location to record the route trace.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for route tracking.');
    }

    final firstPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    _record(firstPosition, force: true);

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen(_record);
    _interval = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        _record(
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          ),
        );
      } catch (_) {
        // A failed periodic fix must not discard the video or earlier trace.
      }
    });
  }

  Future<List<Map<String, dynamic>>> stop() async {
    _interval?.cancel();
    _interval = null;
    await _subscription?.cancel();
    _subscription = null;
    return points;
  }

  void _record(Position position, {bool force = false}) {
    if (position.isMocked) return;
    final now = DateTime.now().toUtc();
    final previous = _lastPosition;
    final elapsed = _lastRecordedAt == null
        ? null
        : now.difference(_lastRecordedAt!);
    final movedMeters = previous == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            position.latitude,
            position.longitude,
          );
    if (!force &&
        movedMeters < 3 &&
        (elapsed == null || elapsed.inSeconds < 10)) {
      return;
    }
    _points.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'capturedAt': (position.timestamp).toUtc().toIso8601String(),
    });
    _lastPosition = position;
    _lastRecordedAt = now;
  }
}

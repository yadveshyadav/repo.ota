/// DTO holding real-time GPS location capture for attendance verification
class AttendanceLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;

  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
  });

  factory AttendanceLocation.fromJson(Map<String, dynamic> json) {
    return AttendanceLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isMocked: json['is_mocked'] as bool? ?? json['isMocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
        'is_mocked': isMocked,
      };

  bool isAccurateEnough(double maxAccuracyMeters) => accuracy <= maxAccuracyMeters;
}

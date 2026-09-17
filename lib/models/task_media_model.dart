import '../core/utils/date_parser_utils.dart';

/// Reusable strongly typed model representing photos, videos, or evidence media attachments.
class TaskMediaModel {
  final String label;
  final String? photoUrl;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final String? remarks;

  const TaskMediaModel({
    required this.label,
    this.photoUrl,
    this.capturedAt,
    this.latitude,
    this.longitude,
    this.remarks,
  });

  /// Check whether GPS coordinates are valid non-zero latitude/longitude values
  bool get hasValidCoordinates {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    if (latitude! < -90.0 || latitude! > 90.0) return false;
    if (longitude! < -180.0 || longitude! > 180.0) return false;
    return true;
  }

  /// Formatted location string strictly adhering to media location rule:
  /// Returns "Location not available" if coordinates are null, 0.0, or invalid.
  String get formattedLocation {
    if (!hasValidCoordinates) {
      return 'Location not available';
    }
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  factory TaskMediaModel.fromJson(
    dynamic json, {
    String defaultLabel = 'Evidence Photo',
  }) {
    if (json == null) {
      return TaskMediaModel(label: defaultLabel);
    }

    if (json is String) {
      return TaskMediaModel(
        label: defaultLabel,
        photoUrl: json,
      );
    }

    if (json is Map<String, dynamic>) {
      double? parseCoord(dynamic val) {
        if (val == null) return null;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString());
      }

      final rawLat = json['latitude'] ?? json['lat'] ?? json['check_in_latitude'];
      final rawLng = json['longitude'] ?? json['lng'] ?? json['lon'] ?? json['check_in_longitude'];

      return TaskMediaModel(
        label: (json['label'] ?? json['title'] ?? json['name'] ?? defaultLabel).toString(),
        photoUrl: json['photoUrl']?.toString() ??
            json['photo_url']?.toString() ??
            json['url']?.toString() ??
            json['imagePath']?.toString() ??
            json['path']?.toString() ??
            json['key']?.toString(),
        capturedAt: DateParserUtils.parse(
          json['capturedAt'] ?? json['captured_at'] ?? json['timestamp'] ?? json['createdAt'],
        ),
        latitude: parseCoord(rawLat),
        longitude: parseCoord(rawLng),
        remarks: json['remarks']?.toString() ?? json['note']?.toString(),
      );
    }

    return TaskMediaModel(label: defaultLabel);
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (remarks != null) 'remarks': remarks,
      };
}

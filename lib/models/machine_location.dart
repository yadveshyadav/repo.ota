/// Data model for Machine map marker locations
class MachineLocation {
  final String id;
  final String machineName;
  final String chassisNumber;
  final String status;
  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final String address;

  const MachineLocation({
    required this.id,
    required this.machineName,
    required this.chassisNumber,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.course,
    required this.address,
  });

  factory MachineLocation.fromJson(Map<String, dynamic> json) {
    return MachineLocation(
      id: json['id'] as String? ?? '',
      machineName: json['machineName'] as String? ?? '',
      chassisNumber: json['chassisNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'Online',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'machineName': machineName,
        'chassisNumber': chassisNumber,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'course': course,
        'address': address,
      };
}

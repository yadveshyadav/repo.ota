/// Data model representing a granular permission capability in the HERO / VehicleIQ platform
class PermissionModel {
  final int id;
  final String code;
  final String name;
  final String category;
  final String description;

  const PermissionModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.description = '',
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}

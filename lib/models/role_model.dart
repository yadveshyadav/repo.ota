import 'permission_model.dart';

/// Data model representing a System or Custom Role in the HERO / VehicleIQ platform
class RoleModel {
  final int id;
  final String name;
  final String code;
  final String? description;
  final bool isSystem;
  final List<int> permissions;
  final List<PermissionModel> permissionsDetails;
  final List<String> permissionCodes;
  final int userCount;
  final String? createdAt;
  final String? updatedAt;

  const RoleModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.isSystem = false,
    this.permissions = const [],
    this.permissionsDetails = const [],
    this.permissionCodes = const [],
    this.userCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0;
    final rawName = json['name']?.toString() ?? '';
    final rawCode = json['code']?.toString() ?? rawName.toUpperCase().replaceAll(' ', '_');

    final permIds = (json['permissions'] as List<dynamic>?)
            ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList() ??
        [];

    final permDetails = (json['permissions_details'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => PermissionModel.fromJson(e))
            .toList() ??
        [];

    final permCodes = (json['permission_codes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        permDetails.map((e) => e.code).toList();

    return RoleModel(
      id: rawId,
      name: rawName,
      code: rawCode,
      description: json['description']?.toString(),
      isSystem: json['is_system'] as bool? ?? false,
      permissions: permIds,
      permissionsDetails: permDetails,
      permissionCodes: permCodes,
      userCount: json['user_count'] is int
          ? json['user_count'] as int
          : int.tryParse(json['user_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'is_system': isSystem,
        'permissions': permissions,
        'permissions_details': permissionsDetails.map((e) => e.toJson()).toList(),
        'permission_codes': permissionCodes,
        'user_count': userCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  RoleModel copyWith({
    int? id,
    String? name,
    String? code,
    String? description,
    bool? isSystem,
    List<int>? permissions,
    List<PermissionModel>? permissionsDetails,
    List<String>? permissionCodes,
    int? userCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return RoleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
      permissions: permissions ?? this.permissions,
      permissionsDetails: permissionsDetails ?? this.permissionsDetails,
      permissionCodes: permissionCodes ?? this.permissionCodes,
      userCount: userCount ?? this.userCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

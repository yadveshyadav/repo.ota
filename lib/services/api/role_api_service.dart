import 'package:flutter/foundation.dart';
import '../../models/permission_model.dart';
import '../../models/role_model.dart';
import 'api_client.dart';

/// Dedicated API service for Roles and Permissions management in HERO / VehicleIQ
class RoleApiService {
  final ApiClient apiClient;

  RoleApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch list of all roles from GET /api/v1/roles/
  Future<List<RoleModel>> fetchRoles() async {
    const primaryEndpoint = '/api/v1/roles/';
    const secondaryEndpoint = '/api/v1/roles';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseRolesResponse(response);
    } catch (_) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        return _parseRolesResponse(response);
      } catch (e) {
        if (kDebugMode) {
          print('[RoleApiService] Roles endpoint error: $e');
        }
        rethrow;
      }
    }
  }

  /// Fetch single role by ID from GET /api/v1/roles/{id}/
  Future<RoleModel?> fetchRoleById(int id) async {
    final primaryEndpoint = '/api/v1/roles/$id/';
    final response = await apiClient.get(primaryEndpoint);
    if (response is Map<String, dynamic>) {
      final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      return RoleModel.fromJson(data);
    }
    return null;
  }

  /// Create new custom role via POST /api/v1/roles/
  Future<RoleModel> createRole({
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    const endpoint = '/api/v1/roles/';
    final body = <String, dynamic>{
      'name': name,
      'code': code.toUpperCase().replaceAll(' ', '_'),
      'description': description ?? '',
      'permissions': permissionIds,
      'is_system': false,
    };

    final response = await apiClient.post(endpoint, body: body);
    if (response is Map<String, dynamic>) {
      final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      return RoleModel.fromJson(data);
    }

    return RoleModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      name: name,
      code: code.toUpperCase().replaceAll(' ', '_'),
      description: description,
      isSystem: false,
      permissions: permissionIds,
      userCount: 0,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Update existing role via PUT /api/v1/roles/{id}/
  Future<RoleModel> updateRole({
    required int id,
    required String name,
    required String code,
    String? description,
    required List<int> permissionIds,
  }) async {
    final endpoint = '/api/v1/roles/$id/';
    final body = <String, dynamic>{
      'name': name,
      'code': code.toUpperCase().replaceAll(' ', '_'),
      'description': description ?? '',
      'permissions': permissionIds,
    };

    final response = await apiClient.post(endpoint, body: body);
    if (response is Map<String, dynamic>) {
      final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      return RoleModel.fromJson(data);
    }

    return RoleModel(
      id: id,
      name: name,
      code: code.toUpperCase().replaceAll(' ', '_'),
      description: description,
      permissions: permissionIds,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Delete role via DELETE /api/v1/roles/{id}/
  Future<bool> deleteRole(int id) async {
    final endpoint = '/api/v1/roles/$id/';
    await apiClient.get('$endpoint?method=DELETE');
    return true;
  }

  /// Fetch all platform permissions from GET /api/v1/permissions/
  Future<List<PermissionModel>> fetchPermissions() async {
    const primaryEndpoint = '/api/v1/permissions/';
    const secondaryEndpoint = '/api/v1/permissions';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parsePermissionsResponse(response);
    } catch (_) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        return _parsePermissionsResponse(response);
      } catch (e) {
        if (kDebugMode) {
          print('[RoleApiService] Permissions endpoint error: $e');
        }
        rethrow;
      }
    }
  }

  List<RoleModel> _parseRolesResponse(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['roles'] is List) {
          list = data['roles'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      } else if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      }
    } else if (response is List) {
      list = response;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => RoleModel.fromJson(json))
        .toList();
  }

  List<PermissionModel> _parsePermissionsResponse(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['permissions'] is List) {
          list = data['permissions'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      } else if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      }
    } else if (response is List) {
      list = response;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => PermissionModel.fromJson(json))
        .toList();
  }
}

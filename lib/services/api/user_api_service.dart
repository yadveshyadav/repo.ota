import 'package:flutter/foundation.dart';
import '../../features/auth/models/user_model.dart';
import 'api_client.dart';

import '../../models/user_response.dart';

/// Dedicated API Service for Users management and Role assignments in HERO / VehicleIQ
class UserApiService {
  final ApiClient apiClient;

  UserApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch paginated user response from GET /api/v1/users/
  Future<UserResponse> fetchUsersResponse({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    final queryParams = 'page=$page&size=$size${search.isNotEmpty ? "&search=${Uri.encodeComponent(search)}" : ""}';
    final primaryEndpoint = '/api/v1/users/?$queryParams';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return UserResponse.fromJson(response, requestPage: page, requestSize: size);
    } catch (e) {
      if (kDebugMode) {
        print('[UserApiService] Users endpoint error: $e');
      }
      rethrow;
    }
  }

  /// Fetch list of users from GET /api/v1/users/ or GET /api/v1/auth/users/
  Future<List<UserModel>> fetchUsers({
    int page = 0,
    int size = 20,
    String search = '',
  }) async {
    final res = await fetchUsersResponse(page: page, size: size, search: search);
    return res.users;
  }

  /// Create user via POST /api/v1/users/
  Future<UserModel> createUser({
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    const endpoint = '/api/v1/users/';
    final body = <String, dynamic>{
      'name': name,
      'username': username,
      'email': email,
      'roles': roles,
      'role': roles.isNotEmpty ? roles.first : 'VIEWER',
      'phone_number': phoneNumber ?? '',
      'is_active': isActive,
    };

    final response = await apiClient.post(endpoint, body: body);
    if (response is Map<String, dynamic>) {
      final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      return UserModel.fromJson(data);
    }

    return UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      email: email,
      name: name,
      role: roles.isNotEmpty ? roles.first : 'VIEWER',
      roles: roles,
      phoneNumber: phoneNumber,
      isActive: isActive,
    );
  }

  /// Update user via PUT /api/v1/users/{id}/
  Future<UserModel> updateUser({
    required String id,
    required String name,
    required String username,
    required String email,
    required List<String> roles,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    final endpoint = '/api/v1/users/$id/';
    final body = <String, dynamic>{
      'name': name,
      'username': username,
      'email': email,
      'roles': roles,
      'role': roles.isNotEmpty ? roles.first : 'VIEWER',
      'phone_number': phoneNumber ?? '',
      'is_active': isActive,
    };

    final response = await apiClient.post(endpoint, body: body);
    if (response is Map<String, dynamic>) {
      final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      return UserModel.fromJson(data);
    }

    return UserModel(
      id: id,
      username: username,
      email: email,
      name: name,
      role: roles.isNotEmpty ? roles.first : 'VIEWER',
      roles: roles,
      phoneNumber: phoneNumber,
      isActive: isActive,
    );
  }

  /// Delete user via DELETE /api/v1/users/{id}/
  Future<bool> deleteUser(String id) async {
    final endpoint = '/api/v1/users/$id/';
    await apiClient.get('$endpoint?method=DELETE');
    return true;
  }
}

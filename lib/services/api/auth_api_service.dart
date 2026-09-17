import 'package:flutter/foundation.dart';
import '../../features/auth/models/user_model.dart';
import 'api_client.dart';

/// Dedicated Authentication API Service contacting backend auth endpoints
class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Execute login request to POST /api/v1/auth/login/
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    const primaryEndpoint = '/api/v1/auth/login/';
    const secondaryEndpoint = '/api/v1/auth/login';

    final cleanUsername = username.trim();

    if (kDebugMode) {
      print('[AuthApiService] POST $primaryEndpoint for user: $cleanUsername');
    }

    final body = <String, dynamic>{
      'username': cleanUsername,
      'password': password,
    };
    if (cleanUsername.contains('@')) {
      body['email'] = cleanUsername;
    }
    if (RegExp(r'^[0-9]{10}$').hasMatch(cleanUsername)) {
      body['phone_number'] = cleanUsername;
      body['phone'] = cleanUsername;
      body['mobile'] = cleanUsername;
    }

    try {
      final response = await apiClient.post(primaryEndpoint, body: body);
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthApiService] Primary login endpoint failed ($e), trying secondary...');
      }
      try {
        final response = await apiClient.post(secondaryEndpoint, body: body);
        if (response is Map<String, dynamic>) {
          return response;
        }
      } catch (e2) {
        if (kDebugMode) {
          print('[AuthApiService] Secondary login error: $e2');
        }
        rethrow;
      }
    }

    throw Exception('Invalid or empty response from auth login server');
  }

  /// Fetch authenticated user profile from GET /api/v1/auth/me/
  Future<UserModel?> fetchCurrentUser() async {
    const primaryEndpoint = '/api/v1/auth/me/';
    const secondaryEndpoint = '/api/v1/auth/me';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response is Map<String, dynamic>) {
        return UserModel.fromJson(response);
      }
    } catch (_) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        if (response is Map<String, dynamic>) {
          return UserModel.fromJson(response);
        }
      } catch (_) {}
    }
    return null;
  }
}

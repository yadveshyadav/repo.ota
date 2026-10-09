import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/models/auth_token.dart';
import 'api_client.dart';

/// Dedicated Authentication API Service contacting backend auth endpoints
class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient(baseUrl: AppConstants.devApiBaseUrl);

  bool lastLoginWasDev = false;

  /// Prefer Dev sign-in, then fall back to HERO if the account is provisioned
  /// there instead.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    Object? devError;
    try {
      final response = await apiClient.post(
        '${AppConstants.devApiBaseUrl}/api/auth/login',
        body: {'phoneNumber': cleanUsername, 'password': password},
        isPublic: true,
      );
      if (response is Map<String, dynamic> &&
          AuthToken.fromJson(response).accessToken.isNotEmpty) {
        lastLoginWasDev = true;
        if (kDebugMode) {
          print('[AuthApiService] Dev sign-in succeeded for $cleanUsername.');
        }
        return response;
      }
      devError = const FormatException('Dev login returned no access token.');
    } catch (error) {
      devError = error;
    }

    try {
      final heroApi = ApiClient(baseUrl: AppConstants.productionAuthBaseUrl);
      final response = await heroApi.post(
        '${AppConstants.productionAuthBaseUrl}/api/v1/auth/login/',
        body: {'username': cleanUsername, 'password': password},
        isPublic: true,
      );
      if (response is Map<String, dynamic> &&
          AuthToken.fromJson(response).accessToken.isNotEmpty) {
        lastLoginWasDev = false;
        if (kDebugMode) {
          print('[AuthApiService] HERO sign-in succeeded for $cleanUsername.');
        }
        return response;
      }
      throw const FormatException('HERO login returned no access token.');
    } catch (heroError) {
      throw Exception(
        'Unable to sign in. Dev login failed ($devError); HERO login failed ($heroError).',
      );
    }
  }

  /// Establish the separate UAT token required by UAT's task API.
  /// This is a login request; task retrieval itself remains GET-only.
  Future<String> loginForUatTasks({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await apiClient.post(
      'https://uat.ilync.tech/api/auth/login',
      body: {'phoneNumber': phoneNumber.trim(), 'password': password},
      isPublic: true,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Unexpected UAT login response.');
    }
    final token = AuthToken.fromJson(response).accessToken;
    if (token.isEmpty) {
      throw const FormatException(
        'UAT login response did not include an access token.',
      );
    }
    return token;
  }

  /// Establish a token for the Dev task service used by Hindrance workflows.
  Future<String> loginForDevTasks({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await apiClient.post(
      '${AppConstants.devApiBaseUrl}/api/auth/login',
      body: {'phoneNumber': phoneNumber.trim(), 'password': password},
      isPublic: true,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Dev login response.');
    }
    final token = AuthToken.fromJson(response).accessToken;
    if (token.isEmpty) {
      throw const FormatException(
        'Dev login response did not include an access token.',
      );
    }
    return token;
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

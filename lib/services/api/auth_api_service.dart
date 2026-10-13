import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/models/auth_token.dart';
import 'api_client.dart';

/// Dedicated Authentication API Service contacting backend auth endpoints
class AuthApiService {
  final ApiClient apiClient;

  AuthApiService({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient(baseUrl: AppConstants.ilyncApiBaseUrl);

  bool lastLoginWasIlYnc = false;
  String activeAuthBaseUrl = AppConstants.ilyncApiBaseUrl;

  /// Prefer HERO sign-in for the fleet app, then fall back to IlYnc UAT.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    Object? heroError;
    try {
      final heroApi = ApiClient(baseUrl: AppConstants.productionAuthBaseUrl);
      final response = await heroApi.post(
        '${AppConstants.productionAuthBaseUrl}/api/v1/auth/login/',
        body: {'username': cleanUsername, 'password': password},
        isPublic: true,
      );
      if (response is Map<String, dynamic> &&
          AuthToken.fromJson(response).accessToken.isNotEmpty) {
        lastLoginWasIlYnc = false;
        activeAuthBaseUrl = AppConstants.productionAuthBaseUrl;
        if (kDebugMode) {
          print('[AuthApiService] HERO sign-in succeeded.');
        }
        return response;
      }
      heroError = const FormatException('HERO login returned no access token.');
    } catch (error) {
      heroError = error;
    }

    try {
      final response = await apiClient.post(
        '${AppConstants.ilyncApiBaseUrl}/api/auth/login',
        body: {'phoneNumber': cleanUsername, 'password': password},
        isPublic: true,
      );
      if (response is Map<String, dynamic> &&
          AuthToken.fromJson(response).accessToken.isNotEmpty) {
        lastLoginWasIlYnc = true;
        activeAuthBaseUrl = AppConstants.ilyncApiBaseUrl;
        if (kDebugMode) {
          print('[AuthApiService] UAT sign-in succeeded.');
        }
        return response;
      }
      throw const FormatException('UAT login returned no access token.');
    } catch (uatError) {
      throw Exception(
        'Unable to sign in. HERO login failed ($heroError); UAT login failed ($uatError).',
      );
    }
  }

  /// Establish the separate task-service token for the selected IlYnc flavor.
  /// This is a login request; task retrieval itself remains GET-only.
  Future<String> loginForIlYncTasks({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await apiClient.post(
      '${AppConstants.ilyncApiBaseUrl}/api/auth/login',
      body: {'phoneNumber': phoneNumber.trim(), 'password': password},
      isPublic: true,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Unexpected IlYnc login response.');
    }
    final token = AuthToken.fromJson(response).accessToken;
    if (token.isEmpty) {
      throw const FormatException(
        'IlYnc login response did not include an access token.',
      );
    }
    return token;
  }

  /// Compatibility wrapper for callers that specifically request Dev.
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
  Future<UserModel?> fetchCurrentUser({
    String? baseUrl,
    String? accessToken,
  }) async {
    const primaryEndpoint = '/api/v1/auth/me/';
    const secondaryEndpoint = '/api/v1/auth/me';
    final selectedBaseUrl = baseUrl ?? activeAuthBaseUrl;
    final profileClient = selectedBaseUrl == apiClient.baseUrl
        ? apiClient
        : ApiClient(baseUrl: selectedBaseUrl);
    if (accessToken != null && accessToken.isNotEmpty) {
      profileClient.setAuthToken(accessToken);
    }

    try {
      final response = await profileClient.get(primaryEndpoint);
      if (response is Map<String, dynamic>) {
        return _parseProfile(response);
      }
    } catch (_) {
      try {
        final response = await profileClient.get(secondaryEndpoint);
        if (response is Map<String, dynamic>) {
          return _parseProfile(response);
        }
      } catch (_) {}
    }
    return null;
  }

  UserModel _parseProfile(Map<String, dynamic> response) {
    dynamic data = response;
    for (var depth = 0; depth < 3 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      if (map['user'] is Map) {
        final user = Map<String, dynamic>.from(map['user'] as Map);
        // HERO returns vendor scope beside `user` in /auth/me. Preserve it so
        // the app uses the same vendor context as the web portal.
        if (user['vendor'] == null && map['vendor'] != null) {
          user['vendor'] = map['vendor'];
        }
        if (user['vendors'] == null && map['vendors'] is List) {
          user['vendors'] = map['vendors'];
        }
        return UserModel.fromJson(user);
      }
      if (map['data'] is Map) {
        data = map['data'];
        continue;
      }
      return UserModel.fromJson(map);
    }
    return UserModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../features/auth/services/auth_storage_service.dart';
import '../../../services/api/api_client.dart';

/// Isolated client for the task-service Daily Muster contract.
class DailyMusterApiService {
  DailyMusterApiService({ApiClient? client})
    : _client = client ?? ApiClient(baseUrl: AppConstants.ilyncApiBaseUrl);

  final ApiClient _client;

  void _authenticate() {
    final auth = AuthStorageService();
    final token = AppConstants.ilyncIsDev
        ? auth.devTaskAccessToken
        : AppConstants.ilyncIsProd
        ? auth.prodTaskAccessToken
        : auth.uatTaskAccessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to establish task-service access.');
    }
    _client.setAuthToken(token);
  }

  dynamic _unwrap(dynamic value) {
    if (value is Map && value['success'] == false) {
      throw Exception(
        value['message']?.toString() ?? 'Daily Muster request failed.',
      );
    }
    if (value is Map && value.containsKey('data')) return value['data'];
    return value;
  }

  Future<Map<String, dynamic>?> today(String taskId) async {
    _authenticate();
    try {
      final response = _unwrap(
        await _client.get('/api/tasks/$taskId/musters/today'),
      );
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return null;
    } catch (error) {
      // The contract uses 404 for a task with no muster today; do not suppress
      // task-not-found or authorization failures as an empty day.
      final message = error.toString().toLowerCase();
      if (message.contains('[404]') &&
          (message.contains('muster not found') ||
              message.contains('no muster'))) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(
    String taskId,
    Map<String, dynamic> body,
  ) async {
    _authenticate();
    final value = _unwrap(
      await _client.post('/api/tasks/$taskId/musters', body: body),
    );
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('The server returned an invalid muster response.');
  }

  Future<Map<String, dynamic>> update(
    String musterId,
    Map<String, dynamic> body,
  ) async {
    _authenticate();
    final value = _unwrap(
      await _client.put('/api/musters/$musterId', body: body),
    );
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> submit(String musterId) async {
    _authenticate();
    _unwrap(await _client.post('/api/musters/$musterId/submit'));
  }

  Future<Map<String, dynamic>> photoUploadUrl({
    required String musterId,
    required String entryId,
  }) async {
    _authenticate();
    final query = Uri(
      queryParameters: {
        'musterId': musterId,
        'entryId': entryId,
        'contentType': 'image/jpeg',
      },
    ).query;
    final value = _unwrap(
      await _client.get('/api/musters/photo-upload-url?$query'),
    );
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('The server did not return a photo upload URL.');
  }

  Future<void> uploadPhoto({required String url, required String path}) async {
    final bytes = await File(path).readAsBytes();
    await _client.putRawBytes(url, bytes, contentType: 'image/jpeg');
  }
}

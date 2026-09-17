import 'package:flutter/foundation.dart';
import '../../models/alert.dart';
import 'api_client.dart';

/// Dedicated REST API Service for Fleet Alerts & Critical Telemetry
class AlertApiService {
  final ApiClient apiClient;

  AlertApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch paginated alert list from GET /api/v1/integrations/alerts/
  Future<AlertResponse> fetchAlerts({
    int page = 1,
    int size = 20,
    String? severity,
    String search = '',
  }) async {
    final queryParams = StringBuffer('page=$page&page_size=$size&size=$size');

    if (severity != null && severity.isNotEmpty && severity != 'ALL') {
      queryParams.write('&severity=${Uri.encodeComponent(severity.toUpperCase())}');
      queryParams.write('&alert_severity=${Uri.encodeComponent(severity.toUpperCase())}');
    }

    if (search.trim().isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search.trim())}');
    }

    final queryString = queryParams.toString();
    final endpoints = [
      '/api/v1/integrations/alerts/?$queryString',
      '/api/v1/integrations/alerts?$queryString',
      '/api/v1/alerts/?$queryString',
      '/api/v1/alerts?$queryString',
      '/api/v1/tracking/alerts/?$queryString',
      '/api/v1/dashboard/alerts/?$queryString',
    ];

    dynamic response;
    Object? lastError;

    for (final ep in endpoints) {
      try {
        if (kDebugMode) {
          print('[AlertApiService] Trying GET $ep');
        }
        response = await apiClient.get(ep).timeout(const Duration(seconds: 12));
        if (response != null) {
          break;
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          print('[AlertApiService] GET $ep failed: $e');
        }
      }
    }

    if (response == null) {
      if (lastError != null) {
        throw lastError;
      }
      throw Exception('Failed to fetch alerts from API endpoints.');
    }

    final alertResponse = AlertResponse.fromJson(
      response,
      requestPage: page,
      requestSize: size,
    );

    if (kDebugMode) {
      print(
          '[AlertApiService] Received ${alertResponse.alerts.length} alerts (Total: ${alertResponse.totalCount}, Page: ${alertResponse.currentPage}/${alertResponse.totalPages})');
    }

    return alertResponse;
  }

  /// Mark specific alert as read via POST /api/v1/integrations/alerts/{id}/read/
  Future<bool> markAsRead(String alertId) async {
    final endpoints = [
      '/api/v1/integrations/alerts/$alertId/read/',
      '/api/v1/integrations/alerts/$alertId/mark-read/',
      '/api/v1/alerts/$alertId/read/',
      '/api/v1/alerts/$alertId/mark-read/',
    ];

    for (final ep in endpoints) {
      try {
        if (kDebugMode) {
          print('[AlertApiService] POST $ep');
        }
        await apiClient.post(ep, body: {});
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('[AlertApiService] POST $ep error: $e');
        }
      }
    }
    return false;
  }
}

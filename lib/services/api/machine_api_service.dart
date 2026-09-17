import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../models/machine_response.dart';
import 'api_client.dart';

/// Dedicated Machine API Service contacting backend REST endpoints for live telemetry.
class MachineApiService {
  final ApiClient apiClient;

  MachineApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch machine list from official HERO / DevTunnel API
  Future<MachineResponse> fetchMachines({int pageSize = 100}) async {
    final primaryEndpoint = '/api/v1/machines/?page_size=$pageSize';
    const secondaryEndpoint = '/api/v1/machines/';
    final tertiaryEndpoint = '/api/v1/machines?page_size=$pageSize';
    const fallbackEndpoint = AppConstants.machinesFallbackEndpoint;

    if (kDebugMode) {
      print('[MachineApiService] GET $primaryEndpoint');
    }

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint);
    } catch (e) {
      if (kDebugMode) {
        print('[MachineApiService] Primary endpoint failed ($e), trying secondary...');
      }
      try {
        response = await apiClient.get(secondaryEndpoint);
      } catch (e2) {
        if (kDebugMode) {
          print('[MachineApiService] Secondary endpoint failed ($e2), trying tertiary...');
        }
        try {
          response = await apiClient.get(tertiaryEndpoint);
        } catch (_) {
          response = await apiClient.get(fallbackEndpoint);
        }
      }
    }

    if (response == null) {
      throw Exception('Null response received from machines API');
    }

    final machineResponse = MachineResponse.fromJson(
      response is Map<String, dynamic> ? response : <String, dynamic>{'data': response},
    );

    if (kDebugMode) {
      print('[MachineApiService] Received ${machineResponse.machines.length} machines (Total: ${machineResponse.total})');
    }

    return machineResponse;
  }

  /// Backend integration point for single machine live telemetry fetch
  Future<Map<String, dynamic>?> fetchMachineTelemetry(String chassisNo) async {
    final primaryEndpoint = '/api/v1/machines/$chassisNo/';
    final fallbackEndpoint = '${AppConstants.machinesFallbackEndpoint}$chassisNo/';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (_) {
      try {
        final response = await apiClient.get(fallbackEndpoint);
        if (response is Map<String, dynamic>) {
          return response;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetch live GPS tracking telemetry for all fleet machines from GET /api/v1/tracking/machines/
  Future<List<Map<String, dynamic>>> fetchLiveTracking() async {
    const primaryEndpoint = '/api/v1/tracking/machines/';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response is Map<String, dynamic> && response['data'] is List) {
        final list = response['data'] as List<dynamic>;
        return list.whereType<Map<String, dynamic>>().toList();
      } else if (response is List) {
        return response.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MachineApiService] Live tracking endpoint error: $e');
      }
    }
    return [];
  }
}

import 'package:flutter/foundation.dart';
import '../../models/refuel_model.dart';
import 'api_client.dart';

/// REST API Service for Machine Refuel Logs & Fuel Analytics from GET /api/v1/refuel/
class RefuelApiService {
  final ApiClient apiClient;

  RefuelApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch refuel logs from GET /api/v1/refuel/ with optional machine filter or search
  Future<List<RefuelModel>> fetchRefuelLogs({
    String? machineId,
    String? searchQuery,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String>[];

    if (machineId != null && machineId.isNotEmpty) {
      queryParams.add('machine=$machineId');
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(searchQuery.trim())}');
    }
    queryParams.add('page=$page');
    queryParams.add('page_size=$pageSize');

    final queryString = queryParams.join('&');
    final primaryEndpoint = '/api/v1/refuel/?$queryString';
    final secondaryEndpoint = '/api/v1/refuel';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseRefuelList(response);
    } catch (e) {
      if (kDebugMode) {
        print('[RefuelApiService] Primary endpoint failed: $e, trying secondary...');
      }
      try {
        final response = await apiClient.get(secondaryEndpoint);
        return _parseRefuelList(response);
      } catch (e2) {
        if (kDebugMode) {
          print('[RefuelApiService] Secondary endpoint failed: $e2');
        }
        return [];
      }
    }
  }

  /// Create a new refuel log entry via POST /api/v1/refuel/
  Future<RefuelModel> createRefuelEntry(Map<String, dynamic> body) async {
    const endpoint = '/api/v1/refuel/';
    final response = await apiClient.post(endpoint, body: body);

    if (response is Map<String, dynamic>) {
      return RefuelModel.fromJson(response);
    }

    throw Exception('Invalid response received from create refuel endpoint');
  }

  List<RefuelModel> _parseRefuelList(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response['results'] ?? response['content'];
      if (data is Map<String, dynamic>) {
        if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['content'] is List) {
          list = data['content'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      }
    } else if (response is List) {
      list = response;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => RefuelModel.fromJson(json))
        .toList();
  }
}

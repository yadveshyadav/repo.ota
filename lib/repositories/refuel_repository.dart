import 'package:flutter/foundation.dart';
import '../models/refuel_model.dart';
import '../services/api/refuel_api_service.dart';

abstract class RefuelRepository {
  Future<List<RefuelModel>> getRefuelLogs({
    String? machineId,
    String? searchQuery,
  });

  Future<RefuelModel> createRefuelEntry(Map<String, dynamic> body);
}

/// Production API-backed Refuel Repository
class ApiRefuelRepository implements RefuelRepository {
  final RefuelApiService apiService;

  ApiRefuelRepository({RefuelApiService? apiService})
      : apiService = apiService ?? RefuelApiService();

  @override
  Future<List<RefuelModel>> getRefuelLogs({
    String? machineId,
    String? searchQuery,
  }) async {
    try {
      final remoteLogs = await apiService.fetchRefuelLogs(
        machineId: machineId,
        searchQuery: searchQuery,
      );
      if (remoteLogs.isNotEmpty) {
        return remoteLogs;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiRefuelRepository] Fetch refuel logs error: $e');
      }
    }

    // Return empty list instead of dummy fallback data
    return [];
  }

  @override
  Future<RefuelModel> createRefuelEntry(Map<String, dynamic> body) async {
    return await apiService.createRefuelEntry(body);
  }
}

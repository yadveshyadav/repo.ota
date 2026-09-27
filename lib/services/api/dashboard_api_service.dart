import 'package:flutter/foundation.dart';
import '../../models/alert.dart';
import '../../models/dashboard_summary.dart';
import '../../models/engine_hours.dart';
import '../../models/fuel_analytics.dart';
import '../../models/machine_location.dart';
import '../../models/utilization.dart';
import 'alert_api_service.dart';
import 'api_client.dart';

/// Dashboard API Service for contacting backend endpoints.
class DashboardApiService {
  final ApiClient apiClient;

  DashboardApiService({required this.apiClient});

  Future<DashboardSummary> fetchSummary() async {
    const primaryEndpoint = '/api/v1/dashboard/summary/';
    const secondaryEndpoint = '/dashboard/summary';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response is Map<String, dynamic>) {
        final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
            ? response['data'] as Map<String, dynamic>
            : response;
        return DashboardSummary.fromJson(data);
      }
    } catch (_) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        if (response is Map<String, dynamic>) {
          final data = response.containsKey('data') && response['data'] is Map<String, dynamic>
              ? response['data'] as Map<String, dynamic>
              : response;
          return DashboardSummary.fromJson(data);
        }
      } catch (_) {}
    }

    return const DashboardSummary(
      totalMachines: 0,
      onlineMachines: 0,
      offlineMachines: 0,
      maintenanceMachines: 0,
    );
  }

  Future<FuelAnalytics> fetchFuelAnalytics() async {
    final response = await apiClient.get('/dashboard/fuel-analytics');
    return FuelAnalytics.fromJson(response as Map<String, dynamic>);
  }

  Future<Utilization> fetchUtilization() async {
    final response = await apiClient.get('/dashboard/utilization');
    return Utilization.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Alert>> fetchActiveAlerts() async {
    try {
      final alertRes = await AlertApiService(apiClient: apiClient).fetchAlerts(page: 1, size: 20);
      return alertRes.alerts;
    } catch (e) {
      if (kDebugMode) {
        print('[DashboardApiService] fetchActiveAlerts error: $e');
      }
      return [];
    }
  }

  Future<List<MachineLocation>> fetchLiveLocations() async {
    final response = await apiClient.get('/dashboard/locations');
    final list = response as List<dynamic>;
    return list
        .map((json) => MachineLocation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<EngineHours> fetchEngineHours({DateTime? date}) async {
    final response = await apiClient.get('/dashboard/engine-hours');
    return EngineHours.fromJson(response as Map<String, dynamic>);
  }
}

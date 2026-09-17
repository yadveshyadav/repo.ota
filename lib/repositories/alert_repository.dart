import 'package:flutter/foundation.dart';
import '../models/alert.dart';
import '../services/api/api_client.dart';
import '../services/api/alert_api_service.dart';

abstract class AlertRepository {
  Future<AlertResponse> getAlerts({
    int page = 1,
    int size = 20,
    String? severity,
    String search = '',
  });

  Future<bool> markAsRead(String alertId);
}

class ApiAlertRepository implements AlertRepository {
  final AlertApiService apiService;

  ApiAlertRepository({ApiClient? apiClient, AlertApiService? apiService})
      : apiService = apiService ??
            AlertApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<AlertResponse> getAlerts({
    int page = 1,
    int size = 20,
    String? severity,
    String search = '',
  }) async {
    try {
      final response = await apiService
          .fetchAlerts(
            page: page,
            size: size,
            severity: severity,
            search: search,
          )
          .timeout(const Duration(seconds: 12));

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAlertRepository] Error fetching alerts from API: $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> markAsRead(String alertId) async {
    try {
      return await apiService.markAsRead(alertId);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAlertRepository] Error marking alert as read: $e');
      }
      return false;
    }
  }
}

class MockAlertRepository implements AlertRepository {
  static final List<Alert> _mockAlerts = [
    Alert.fromJson({
      'id': '41',
      'machine_code': 'A800 HDD (8595)',
      'vendor_name': 'HARPAL INFRA DEVELOPMENT',
      'severity': 'CRITICAL',
      'timestamp': '18m ago',
      'alert_type': 'ENGINE_OVERHEAT',
      'title': 'Engine Overheat Warning - A800 HDD (8595)',
      'message': 'Coolant temperature reached 98°C during operation. (A800 HDD (8595))',
      'time_ago_str': '18m ago',
      'alert_severity': 'CRITICAL',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(minutes: 18)).toIso8601String(),
      'vendor': 8,
      'machine': 63,
    }),
    Alert.fromJson({
      'id': '40',
      'machine_code': 'A600 HDD (8400)',
      'vendor_name': 'Naveen Telecom',
      'severity': 'WARNING',
      'timestamp': '45m ago',
      'alert_type': 'LOW_FUEL',
      'title': 'Low Fuel Level Warning - A600 HDD (8400)',
      'message': 'Fuel level dropped below 15%. Scheduled refueling required.',
      'time_ago_str': '45m ago',
      'alert_severity': 'WARNING',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
      'vendor': 2,
      'machine': 12,
    }),
    Alert.fromJson({
      'id': '39',
      'machine_code': 'A600 HDD (8396)',
      'vendor_name': 'Gurukripa Enterprises',
      'severity': 'INFO',
      'timestamp': '2h ago',
      'alert_type': 'GPS_RESTORED',
      'title': 'GPS Signal Restored - A600 HDD (8396)',
      'message': 'High precision satellite telemetry connection re-established.',
      'time_ago_str': '2h ago',
      'alert_severity': 'INFO',
      'is_read': true,
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'vendor': 1,
      'machine': 1,
    }),
  ];

  @override
  Future<AlertResponse> getAlerts({
    int page = 1,
    int size = 20,
    String? severity,
    String search = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final filtered = _mockAlerts.where((a) {
      if (severity != null && severity.isNotEmpty && severity != 'ALL') {
        if (a.severity.toUpperCase() != severity.toUpperCase()) return false;
      }
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return a.title.toLowerCase().contains(q) ||
            a.message.toLowerCase().contains(q) ||
            a.chassisNumber.toLowerCase().contains(q) ||
            (a.vendorName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return AlertResponse(
      alerts: filtered,
      totalCount: filtered.length,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<bool> markAsRead(String alertId) async {
    final index = _mockAlerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _mockAlerts[index] = _mockAlerts[index].copyWith(isRead: true);
      return true;
    }
    return false;
  }
}

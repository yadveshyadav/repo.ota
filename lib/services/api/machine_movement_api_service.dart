import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Dedicated REST API Service communicating with /api/v1/machine-shift/ backend endpoints
class MachineMovementApiService {
  final ApiClient apiClient;

  MachineMovementApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Fetch dynamic reasons list from GET /api/v1/machine-shift/machine-shift-reasons/
  Future<dynamic> fetchShiftReasons() async {
    const primaryEndpoint = '/api/v1/machine-shift/machine-shift-reasons/';
    if (kDebugMode) {
      print('[MachineMovementApiService] GET $primaryEndpoint');
    }
    return await apiClient.get(primaryEndpoint);
  }

  /// List machine shift requests from GET /api/v1/machine-shift/machine-shift-requests/
  Future<dynamic> fetchShiftRequests({
    String? statusFilter,
    String? machineFilter,
    String? vendorFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'all') {
      params.add('status=${Uri.encodeComponent(statusFilter.toUpperCase())}');
    }
    if (machineFilter != null && machineFilter.isNotEmpty) {
      params.add('machine=${Uri.encodeComponent(machineFilter)}');
    }
    if (vendorFilter != null && vendorFilter.isNotEmpty) {
      params.add('vendor=${Uri.encodeComponent(vendorFilter)}');
    }

    final queryStr = params.join('&');
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/?$queryStr';

    if (kDebugMode) {
      print('[MachineMovementApiService] GET $primaryEndpoint');
    }

    return await apiClient.get(primaryEndpoint);
  }

  /// Create new shift request via POST /api/v1/machine-shift/machine-shift-requests/
  Future<dynamic> createShiftRequest(Map<String, dynamic> body) async {
    const primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/';

    if (kDebugMode) {
      print('[MachineMovementApiService] POST $primaryEndpoint body: $body');
    }

    return await apiClient.post(primaryEndpoint, body: body);
  }

  /// Get single request details via GET /api/v1/machine-shift/machine-shift-requests/{id}/
  Future<dynamic> fetchRequestDetail(dynamic requestId) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/';
    return await apiClient.get(primaryEndpoint);
  }

  /// Start Shifting via POST /api/v1/machine-shift/machine-shift-requests/{id}/start-shifting/
  Future<dynamic> startShifting(dynamic requestId) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/start-shifting/';
    if (kDebugMode) {
      print('[MachineMovementApiService] POST $primaryEndpoint');
    }
    return await apiClient.post(primaryEndpoint, body: {});
  }

  /// Update Shifting Details via POST or PATCH /api/v1/machine-shift/machine-shift-requests/{id}/shifter-update/
  Future<dynamic> updateShiftingProgress(
    dynamic requestId, {
    required Map<String, String> fields,
  }) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/shifter-update/';
    return await apiClient.post(primaryEndpoint, body: fields);
  }

  /// Mark as SHIFTED with mandatory photo upload via POST /api/v1/machine-shift/machine-shift-requests/{id}/mark-shifted/
  Future<dynamic> markShifted(
    dynamic requestId, {
    required Map<String, String> fields,
    List<int>? photoBytes,
    String photoFilename = 'rig_photo.jpg',
  }) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/mark-shifted/';

    if (kDebugMode) {
      print('[MachineMovementApiService] POST Multipart $primaryEndpoint with ${photoBytes?.length ?? 0} photo bytes');
    }

    http.MultipartFile? photoFile;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoFile = http.MultipartFile.fromBytes(
        'machine_picture',
        photoBytes,
        filename: photoFilename,
      );
    }

    return await apiClient.postMultipart(
      primaryEndpoint,
      fields: fields,
      file: photoFile,
    );
  }

  /// Cancel shift request via POST /api/v1/machine-shift/machine-shift-requests/{id}/cancel/
  Future<dynamic> cancelShiftRequest(dynamic requestId, {required String remarks}) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/cancel/';
    return await apiClient.post(primaryEndpoint, body: {'remarks': remarks});
  }

  /// View Audit Trail timeline via GET /api/v1/machine-shift/machine-shift-requests/{id}/audit-trail/
  Future<dynamic> fetchAuditTrail(dynamic requestId) async {
    final primaryEndpoint = '/api/v1/machine-shift/machine-shift-requests/$requestId/audit-trail/';
    return await apiClient.get(primaryEndpoint);
  }
}

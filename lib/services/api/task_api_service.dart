import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../models/task_execution_model.dart';
import '../../models/task_filter.dart';
import '../../models/task_model.dart';
import '../../models/task_response.dart';
import '../../features/auth/services/auth_storage_service.dart';
import 'api_client.dart';

/// Dedicated Task API Service for HERO Tasks API
class TaskApiService {
  final ApiClient apiClient;

  TaskApiService({ApiClient? apiClient})
    : apiClient = apiClient ?? ApiClient(baseUrl: AppConstants.devApiBaseUrl);

  /// Task reads use the token issued by the same task-service environment.
  /// Data sources can own separate ApiClient instances, so never depend on
  /// another API request having run first.
  void _useTaskServiceToken() {
    final storage = AuthStorageService();
    final isDev = apiClient.baseUrl == AppConstants.devApiBaseUrl;
    final taskToken = isDev
        ? storage.devTaskAccessToken
        : storage.uatTaskAccessToken;
    if (taskToken == null || taskToken.isEmpty) {
      throw StateError(
        isDev
            ? 'Sign in again to establish Dev task access.'
            : 'Sign in again to establish UAT task access.',
      );
    }
    apiClient.setAuthToken(taskToken);
  }

  /// Fetches authenticated planning/master data with the token for this
  /// environment. Hindrance choices come from master data and approved BoQ
  /// plans; `/my-tasks` contains only assigned task rows.
  Future<dynamic> fetchPlanningData(String endpoint) async {
    _useTaskServiceToken();
    // These planning endpoints are served without Django's trailing-slash
    // normalization. ApiClient appends a slash to ordinary relative paths,
    // which makes `/api/master/data/` return a server error on Dev.
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return apiClient.get('${apiClient.baseUrl}$cleanEndpoint');
  }

  /// Fetch paginated task list from GET /api/v1/integrations/tasks/my-tasks/
  Future<TaskResponse> fetchTasks({
    int page = 0,
    int size = 100,
    TaskFilterModel? filters,
    String search = '',
  }) async {
    _useTaskServiceToken();
    final queryParams = StringBuffer('page=$page&size=$size&page_size=$size');

    final f = filters ?? const TaskFilterModel();

    if (f.taskType.isNotEmpty && f.taskType != 'ALL') {
      queryParams.write('&taskType=${Uri.encodeComponent(f.taskType)}');
    }
    if (f.status.isNotEmpty && f.status != 'ALL') {
      queryParams.write('&status=${Uri.encodeComponent(f.status)}');
    }
    if (f.vendor.isNotEmpty && f.vendor != 'ALL') {
      queryParams.write('&vendor=${Uri.encodeComponent(f.vendor)}');
    }
    if (f.supervisor.isNotEmpty && f.supervisor != 'ALL') {
      queryParams.write('&supervisor=${Uri.encodeComponent(f.supervisor)}');
    }
    if (f.district.isNotEmpty && f.district != 'ALL') {
      queryParams.write('&district=${Uri.encodeComponent(f.district)}');
    }
    if (f.circle.isNotEmpty && f.circle != 'ALL') {
      queryParams.write('&circle=${Uri.encodeComponent(f.circle)}');
    }
    if (f.stage.isNotEmpty && f.stage != 'ALL') {
      queryParams.write('&stage=${Uri.encodeComponent(f.stage)}');
    }
    if (f.approvalStatus.isNotEmpty && f.approvalStatus != 'ALL') {
      queryParams.write(
        '&approvalStatus=${Uri.encodeComponent(f.approvalStatus)}',
      );
    }
    if (search.trim().isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search.trim())}');
    }

    final queryString = queryParams.toString();
    final endpoints = [
      // Routes shown by the UAT network capture. Keep the authenticated task
      // read on GET; Hindrance offline work does not submit report mutations.
      '/api/tasks/my-tasks/?$queryString',
      '/api/tasks/my-tasks?$queryString',
      '/api/v1/integrations/tasks/my-tasks/?$queryString',
      '/api/v1/integrations/tasks/my-tasks?$queryString',
      '/api/v1/tasks/my-tasks/?$queryString',
      '/api/v1/tasks/my-tasks?$queryString',
      '/api/v1/integrations/tasks/?$queryString',
      '/api/v1/tasks/?$queryString',
    ];

    dynamic response;
    Object? lastError;

    for (final ep in endpoints) {
      try {
        if (kDebugMode) {
          print('[TaskApiService] Trying GET $ep');
        }
        response = await apiClient.get(ep).timeout(const Duration(seconds: 12));
        if (response != null) {
          break;
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          print('[TaskApiService] GET $ep failed: $e');
        }
      }
    }

    if (response == null) {
      if (lastError != null) {
        throw lastError;
      }
      throw Exception('Failed to fetch tasks from API endpoints.');
    }

    final taskResponse = TaskResponse.fromJson(
      response,
      requestPage: page,
      requestSize: size,
    );

    if (kDebugMode) {
      print(
        '[TaskApiService] Received ${taskResponse.tasks.length} tasks (Total: ${taskResponse.totalCount}, Page: ${taskResponse.currentPage}/${taskResponse.totalPages})',
      );
    }

    return taskResponse;
  }

  /// Fetch task type summary counts from GET /api/v1/integrations/tasks/my-tasks/type-counts/
  Future<Map<String, int>> fetchTaskTypeCounts() async {
    const endpoints = [
      '/api/tasks/my-tasks/type-counts',
      '/api/v1/integrations/tasks/my-tasks/type-counts/',
      '/api/v1/tasks/type-counts/',
    ];

    if (kDebugMode) {
      print('[TaskApiService] GET ${endpoints.first}');
    }

    for (final endpoint in endpoints) {
      try {
        final response = await apiClient
            .get(endpoint)
            .timeout(const Duration(seconds: 5));
        return _parseTypeCountsResponse(response);
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  Map<String, int> _parseTypeCountsResponse(dynamic response) {
    final Map<String, int> counts = {};
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        data.forEach((key, value) {
          int parseVal(dynamic v) {
            if (v is int) return v;
            if (v is num) return v.toInt();
            if (v is String) return int.tryParse(v.trim()) ?? 0;
            return 0;
          }

          counts[key] = parseVal(value);
        });
      }
    }
    return counts;
  }

  /// Fetch full Task Master Details for a specific task ID
  Future<TaskModel> fetchTaskDetails(String taskId) async {
    _useTaskServiceToken();
    final endpoints = [
      '/api/tasks/my-tasks/$taskId',
      '/api/v1/integrations/tasks/my-tasks/$taskId/',
      '/api/v1/tasks/$taskId/',
    ];

    if (kDebugMode) {
      print('[TaskApiService] GET ${endpoints.first}');
    }

    for (final endpoint in endpoints) {
      try {
        final response = await apiClient
            .get(endpoint)
            .timeout(const Duration(seconds: 10));
        return TaskModel.fromJson(response);
      } catch (err) {
        continue;
      }
    }
    throw Exception('Failed to fetch task details from API endpoints.');
  }

  /// Fetch standalone Task Execution payload for a specific task ID
  Future<TaskExecutionModel?> fetchTaskExecutionDetails(String taskId) async {
    _useTaskServiceToken();
    final primaryEndpoint =
        '/api/v1/integrations/tasks/my-tasks/$taskId/execution/';
    final secondaryEndpoint = '/api/v1/task-executions/by-task/$taskId/';

    if (kDebugMode) {
      print('[TaskApiService] GET $primaryEndpoint');
    }

    try {
      final response = await apiClient
          .get(primaryEndpoint)
          .timeout(const Duration(seconds: 3));
      if (response != null) {
        return TaskExecutionModel.fromJson(response);
      }
    } catch (_) {
      try {
        final response = await apiClient
            .get(secondaryEndpoint)
            .timeout(const Duration(seconds: 2));
        if (response != null) {
          return TaskExecutionModel.fromJson(response);
        }
      } catch (e) {
        if (kDebugMode) {
          print('[TaskApiService] Fetch task execution error: $e');
        }
        return null;
      }
    }
    return null;
  }
}

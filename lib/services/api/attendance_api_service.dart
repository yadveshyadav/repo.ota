import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/attendance_model.dart';
import '../../models/machine.dart';
import '../../models/muster_model.dart';
import '../../core/constants/app_constants.dart';
import '../attendance_storage_service.dart';
import 'api_client.dart';

/// Dedicated Netinfra Task Service API Service for DailyMuster and Attendance transactions
class AttendanceApiService {
  final ApiClient apiClient;

  AttendanceApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient(baseUrl: AppConstants.defaultBaseUrl);

  /// Cleanly extract user ID string without modifying alphanumeric characters or ObjectIds
  String _getCleanUserId(UserModel? user) {
    if (user == null) return '1';
    if (user.id.trim().isNotEmpty) return user.id.trim();
    if (user.externalUserId != null && user.externalUserId!.trim().isNotEmpty) {
      return user.externalUserId!.trim();
    }
    return '1';
  }

  String _toBase64Photo(List<int>? photoBytes) {
    if (photoBytes == null || photoBytes.isEmpty) return '';
    final encoded = base64Encode(photoBytes);
    return 'data:image/jpeg;base64,$encoded';
  }

  // ============================================================================
  // DOCUMENTED NETINFRA MUSTER API ENDPOINTS
  // ============================================================================

  /// A. CHECK TODAY'S MUSTER: GET /api/tasks/{taskId}/musters/today
  Future<DailyMuster?> getTodaysMuster(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return null;

    final primaryEndpoint = '/api/tasks/$cleanTaskId/musters/today';
    final fallbackEndpoint = '/api/v1/tasks/$cleanTaskId/musters/today';

    try {
      final response = await apiClient.get(primaryEndpoint);
      if (response != null) {
        return _parseDailyMuster(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary getTodaysMuster failed ($e), trying fallback...');
      }
      try {
        final response = await apiClient.get(fallbackEndpoint);
        if (response != null) {
          return _parseDailyMuster(response);
        }
      } catch (e2) {
        if (kDebugMode) {
          print('[AttendanceApiService] Fallback getTodaysMuster failed: $e2');
        }
      }
    }
    return null;
  }

  /// B. CREATE MUSTER: POST /api/tasks/{taskId}/musters
  Future<DailyMuster> createMuster(String taskId, Map<String, dynamic> body) async {
    final cleanTaskId = taskId.trim();
    final primaryEndpoint = '/api/tasks/$cleanTaskId/musters';
    final fallbackEndpoint = '/api/v1/tasks/$cleanTaskId/musters';

    dynamic response;
    try {
      response = await apiClient.post(primaryEndpoint, body: body);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary createMuster failed ($e), trying fallback...');
      }
      response = await apiClient.post(fallbackEndpoint, body: body);
    }

    final parsed = _parseDailyMuster(response);
    if (parsed != null) return parsed;
    throw Exception('Failed to parse created muster response.');
  }

  /// C. GET MUSTER DETAIL: GET /api/musters/{musterId}
  Future<DailyMuster> getMusterDetail(String musterId) async {
    final cleanMusterId = musterId.trim();
    final primaryEndpoint = '/api/musters/$cleanMusterId';
    final fallbackEndpoint = '/api/v1/musters/$cleanMusterId';

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint);
    } catch (e) {
      response = await apiClient.get(fallbackEndpoint);
    }

    final parsed = _parseDailyMuster(response);
    if (parsed != null) return parsed;
    throw Exception('Failed to fetch muster detail for $musterId');
  }

  /// D. UPDATE/SAVE MUSTER: PUT /api/musters/{musterId}
  Future<DailyMuster> updateMuster(String musterId, Map<String, dynamic> body) async {
    final cleanMusterId = musterId.trim();
    final primaryEndpoint = '/api/musters/$cleanMusterId';
    final fallbackEndpoint = '/api/v1/musters/$cleanMusterId';

    dynamic response;
    try {
      response = await apiClient.put(primaryEndpoint, body: body);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary updateMuster failed ($e), trying fallback...');
      }
      response = await apiClient.put(fallbackEndpoint, body: body);
    }

    final parsed = _parseDailyMuster(response);
    if (parsed != null) return parsed;
    throw Exception('Failed to parse updated muster response.');
  }

  /// E. SUBMIT MUSTER: POST /api/musters/{musterId}/submit
  Future<bool> submitMuster(String musterId, {String? stepUpToken}) async {
    final cleanMusterId = musterId.trim();
    final effectiveToken = (stepUpToken != null && stepUpToken.isNotEmpty)
        ? stepUpToken
        : (apiClient.authToken != null && apiClient.authToken!.isNotEmpty
            ? apiClient.authToken!
            : 'stepup_default');

    final primaryEndpoint = '/api/musters/$cleanMusterId/submit?stepUpToken=${Uri.encodeComponent(effectiveToken)}';
    final fallbackEndpoint = '/api/v1/musters/$cleanMusterId/submit?stepUpToken=${Uri.encodeComponent(effectiveToken)}';

    final body = <String, dynamic>{
      'stepUpToken': effectiveToken,
    };

    try {
      await apiClient.post(primaryEndpoint, body: body);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary submitMuster failed ($e), trying fallback...');
      }
      try {
        await apiClient.post(fallbackEndpoint, body: body);
        return true;
      } catch (e2) {
        if (kDebugMode) {
          print('[AttendanceApiService] Fallback submitMuster failed: $e2');
        }
        rethrow;
      }
    }
  }

  /// F. GET PENDING APPROVALS: GET /api/musters/pending-approval
  Future<List<DailyMuster>> getPendingMusterApprovals() async {
    const primaryEndpoint = '/api/musters/pending-approval';
    const fallbackEndpoint = '/api/v1/musters/pending-approval';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseDailyMusterList(response);
    } catch (_) {
      try {
        final response = await apiClient.get(fallbackEndpoint);
        return _parseDailyMusterList(response);
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] getPendingMusterApprovals error: $e');
        }
        return [];
      }
    }
  }

  /// G. APPROVE MUSTER: POST /api/musters/{musterId}/approve
  Future<bool> approveMuster(String musterId, {String remarks = 'Attendance approved'}) async {
    final cleanMusterId = musterId.trim();
    final primaryEndpoint = '/api/musters/$cleanMusterId/approve';
    final fallbackEndpoint = '/api/v1/musters/$cleanMusterId/approve';

    final body = {'remarks': remarks};

    try {
      await apiClient.post(primaryEndpoint, body: body);
      return true;
    } catch (_) {
      try {
        await apiClient.post(fallbackEndpoint, body: body);
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] approveMuster error: $e');
        }
        return false;
      }
    }
  }

  /// APPROVE ATTENDANCE: POST /api/v1/attendance/{attendanceId}/approve/
  Future<bool> approveAttendance(String attendanceId) async {
    final cleanId = attendanceId.trim();
    final primaryEndpoint = '/api/v1/attendance/$cleanId/approve/';
    final secondaryEndpoint = '/api/v1/attendance/$cleanId/approve';

    try {
      await apiClient.post(primaryEndpoint, body: {});
      return true;
    } catch (_) {
      try {
        await apiClient.post(secondaryEndpoint, body: {});
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] approveAttendance error: $e');
        }
        return false;
      }
    }
  }

  /// REJECT ATTENDANCE: POST /api/v1/attendance/{attendanceId}/reject/
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    final cleanId = attendanceId.trim();
    final cleanReason = reason.trim();
    final primaryEndpoint = '/api/v1/attendance/$cleanId/reject/';
    final secondaryEndpoint = '/api/v1/attendance/$cleanId/reject';

    final body = {'rejection_reason': cleanReason, 'reason': cleanReason};

    try {
      await apiClient.post(primaryEndpoint, body: body);
      return true;
    } catch (_) {
      try {
        await apiClient.post(secondaryEndpoint, body: body);
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] rejectAttendance error: $e');
        }
        return false;
      }
    }
  }

  /// I. GET MUSTER HISTORY: GET /api/tasks/{taskId}/musters
  Future<List<DailyMuster>> getMusterHistoryForTask(String taskId) async {
    final cleanTaskId = taskId.trim();
    final primaryEndpoint = '/api/tasks/$cleanTaskId/musters';
    final fallbackEndpoint = '/api/v1/tasks/$cleanTaskId/musters';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseDailyMusterList(response);
    } catch (_) {
      try {
        final response = await apiClient.get(fallbackEndpoint);
        return _parseDailyMusterList(response);
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] getMusterHistoryForTask error: $e');
        }
        return [];
      }
    }
  }

  /// J. GET GENERAL MUSTER LIST: GET /api/musters
  Future<List<DailyMuster>> getGeneralMusterList() async {
    const primaryEndpoint = '/api/musters';
    const fallbackEndpoint = '/api/v1/musters';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseDailyMusterList(response);
    } catch (_) {
      try {
        final response = await apiClient.get(fallbackEndpoint);
        return _parseDailyMusterList(response);
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] getGeneralMusterList error: $e');
        }
        return [];
      }
    }
  }

  /// K. GET PHOTO UPLOAD URL: GET /api/musters/photo-upload-url
  Future<PhotoUploadUrlResponse> getPhotoUploadUrl({
    required String musterId,
    required String entryId,
    String contentType = 'image/jpeg',
  }) async {
    final queryParams = 'musterId=${Uri.encodeComponent(musterId)}&entryId=${Uri.encodeComponent(entryId)}&contentType=${Uri.encodeComponent(contentType)}';
    final primaryEndpoint = '/api/musters/photo-upload-url?$queryParams';
    final fallbackEndpoint = '/api/v1/musters/photo-upload-url?$queryParams';

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint);
    } catch (_) {
      response = await apiClient.get(fallbackEndpoint);
    }

    if (response is Map<String, dynamic>) {
      return PhotoUploadUrlResponse.fromJson(response);
    }
    throw Exception('Invalid photo upload URL response received.');
  }

  /// L. UPLOAD ACTUAL RAW JPEG IMAGE TO PRESIGNED URL
  Future<bool> uploadAttendancePhoto({
    required String uploadUrl,
    required List<int> imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    if (uploadUrl.isEmpty || imageBytes.isEmpty) {
      throw Exception('Upload URL and image bytes are required.');
    }

    final response = await apiClient.putRawBytes(
      uploadUrl,
      imageBytes,
      contentType: contentType,
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// M. GET PHOTO VIEW URL: GET /api/musters/photo-url
  Future<String> getPhotoUrl({
    required String musterId,
    required String photoKey,
  }) async {
    if (photoKey.isEmpty) return '';

    final queryParams = 'musterId=${Uri.encodeComponent(musterId)}&photoKey=${Uri.encodeComponent(photoKey)}';
    final primaryEndpoint = '/api/musters/photo-url?$queryParams';
    final fallbackEndpoint = '/api/v1/musters/photo-url?$queryParams';

    dynamic response;
    try {
      response = await apiClient.get(primaryEndpoint);
    } catch (_) {
      try {
        response = await apiClient.get(fallbackEndpoint);
      } catch (_) {}
    }

    if (response is Map<String, dynamic>) {
      final photoResp = PhotoViewResponse.fromJson(response);
      if (photoResp.photoUrl.isNotEmpty) {
        return photoResp.photoUrl;
      }
    }
    return '';
  }

  // ============================================================================
  // LEGACY/COMPATIBILITY ENDPOINTS FOR EXISTING UI
  // ============================================================================

  Future<AttendanceModel> _ensurePhotoUrl(
    AttendanceModel model,
    List<int>? photoBytes,
    String photoBase64, {
    String prefix = 'check_in',
    bool isCheckOut = false,
  }) async {
    final existingPhoto = isCheckOut ? model.checkOutPhotoUrl : model.checkInPhotoUrl;
    if (existingPhoto != null && existingPhoto.trim().isNotEmpty) {
      return model;
    }

    String photoPath = photoBase64;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        photoPath = await AttendanceStorageService().savePhotoLocally(
          attendanceId: model.id,
          photoBytes: photoBytes,
          prefix: prefix,
        );
      } catch (_) {}
    }

    return AttendanceModel(
      id: model.id,
      userId: model.userId,
      userName: model.userName,
      employeeId: model.employeeId,
      reportingManagerId: model.reportingManagerId,
      reportingManagerName: model.reportingManagerName,
      attendanceType: model.attendanceType,
      machineId: model.machineId,
      machineChassisNo: model.machineChassisNo,
      machineAssignmentId: model.machineAssignmentId,
      vendorId: model.vendorId,
      siteId: model.siteId,
      markedForUserId: model.markedForUserId,
      markedForUserName: model.markedForUserName,
      markedByUserId: model.markedByUserId,
      markedByUserName: model.markedByUserName,
      status: model.status,
      checkInTime: model.checkInTime,
      checkOutTime: model.checkOutTime,
      checkInLat: model.checkInLat,
      checkInLng: model.checkInLng,
      checkInAccuracy: model.checkInAccuracy,
      checkInPhotoUrl: isCheckOut ? model.checkInPhotoUrl : photoPath,
      locationSource: model.locationSource,
      checkOutLat: model.checkOutLat,
      checkOutLng: model.checkOutLng,
      checkOutAccuracy: model.checkOutAccuracy,
      checkOutPhotoUrl: isCheckOut ? photoPath : model.checkOutPhotoUrl,
      totalWorkingSeconds: model.totalWorkingSeconds,
      formattedWorkingHours: model.formattedWorkingHours,
      approvalStatus: model.approvalStatus,
      approvedBy: model.approvedBy,
      approvedAt: model.approvedAt,
      rejectionReason: model.rejectionReason,
      createdAt: model.createdAt,
    );
  }

  /// Fetch today's active attendance record for the authenticated user
  Future<AttendanceModel?> fetchTodayAttendance() async {
    const primaryEndpoint = '/api/v1/attendance/today/';
    const secondaryEndpoint = '/api/v1/attendance/today';

    try {
      final response = await apiClient.get(primaryEndpoint);
      final parsed = _parseTodayAttendanceResponse(response);
      if (parsed != null) return parsed;
    } catch (_) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        final parsed = _parseTodayAttendanceResponse(response);
        if (parsed != null) return parsed;
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] Today attendance fetch error: $e');
        }
      }
    }
    return null;
  }

  AttendanceModel? _parseTodayAttendanceResponse(dynamic response) {
    if (response == null) return null;

    Map<String, dynamic>? itemMap;

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        if (data.containsKey('id') || data.containsKey('attendance_id') || data.containsKey('check_in_time')) {
          itemMap = data;
        }
      } else if (data is List && data.isNotEmpty) {
        if (data.first is Map<String, dynamic>) {
          itemMap = data.first as Map<String, dynamic>;
        }
      } else if (response['results'] is List) {
        final results = response['results'] as List;
        if (results.isNotEmpty && results.first is Map<String, dynamic>) {
          itemMap = results.first as Map<String, dynamic>;
        }
      } else if (response.containsKey('id') || response.containsKey('attendance_id') || response.containsKey('check_in_time')) {
        itemMap = response;
      }
    } else if (response is List && response.isNotEmpty) {
      if (response.first is Map<String, dynamic>) {
        itemMap = response.first as Map<String, dynamic>;
      }
    }

    if (itemMap != null) {
      return AttendanceModel.fromJson(itemMap);
    }
    return null;
  }

  /// Fetch machines assigned to the currently authenticated user
  Future<List<Machine>> fetchMyAssignedMachines({String? date}) async {
    final todayStr = date ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final endpoints = [
      '/api/v1/attendance/my-assigned-machines/',
      '/api/v1/attendance/team-attendance/?date=$todayStr',
      '/api/v1/machines/assigned/',
      '/api/v1/machines/',
      '/api/musters/machines',
    ];

    for (final ep in endpoints) {
      try {
        final response = await apiClient.get(ep);
        final machines = _parseMachineList(response);
        if (machines.isNotEmpty) {
          if (kDebugMode) {
            print('[AttendanceApiService] Fetched ${machines.length} assigned machines from $ep');
          }
          return machines;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetch authorized team members for supervisor
  Future<List<UserModel>> fetchAuthorizedTeamMembers({String? date}) async {
    final todayStr = date ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final primaryEndpoint = '/api/v1/attendance/team-attendance/?date=$todayStr';
    const secondaryEndpoint = '/api/v1/attendance/team-members/';
    const tertiaryEndpoint = '/api/v1/users/my-team/';

    try {
      final response = await apiClient.get(primaryEndpoint);
      final users = _parseUserList(response);
      if (users.isNotEmpty) return users;
    } catch (_) {}

    try {
      final response = await apiClient.get(secondaryEndpoint);
      final users = _parseUserList(response);
      if (users.isNotEmpty) return users;
    } catch (_) {}

    try {
      final response = await apiClient.get(tertiaryEndpoint);
      return _parseUserList(response);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Fetch authorized team members error: $e');
      }
      return [];
    }
  }

  /// Submit Machine Attendance transaction
  Future<AttendanceModel> checkInMachine({
    required String machineChassisNo,
    required String? assignmentId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    const primaryEndpoint = '/api/v1/attendance/machine-check-in/';
    const fallbackEndpoint = '/api/v1/attendance/check-in/';

    final user = AuthStorageService().currentUser;
    final userIdStr = _getCleanUserId(user);
    final photoBase64 = _toBase64Photo(photoBytes);

    final mChassis = machineChassisNo.isNotEmpty ? machineChassisNo : 'N/A';
    final mId = (assignmentId != null && assignmentId.isNotEmpty) ? assignmentId : mChassis;
    dynamic parsedUserId = int.tryParse(userIdStr) ?? userIdStr;

    final jsonBody = <String, dynamic>{
      'user_id': parsedUserId,
      'machine_id': mId,
      'machine_chassis_no': mChassis,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'MACHINE',
      'check_in_photo': photoBase64,
    };

    dynamic response;
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      try {
        response = await apiClient.post(fallbackEndpoint, body: jsonBody);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'machine_check_in');
    }

    throw Exception('Invalid response received from machine check-in endpoint.');
  }

  /// Submit Team Attendance transaction
  Future<AttendanceModel> checkInTeamMember({
    required String targetUserId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    const primaryEndpoint = '/api/v1/attendance/check-in/';

    final user = AuthStorageService().currentUser;
    final currentUserIdStr = _getCleanUserId(user);
    final targetUserIdStr = targetUserId.trim().isNotEmpty ? targetUserId.trim() : currentUserIdStr;

    if (targetUserIdStr == currentUserIdStr) {
      return checkIn(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
    }

    final photoBase64 = _toBase64Photo(photoBytes);

    dynamic parsedTargetId = int.tryParse(targetUserIdStr) ?? targetUserIdStr;
    dynamic parsedCurrentId = int.tryParse(currentUserIdStr) ?? currentUserIdStr;

    final jsonBody = <String, dynamic>{
      'user_id': parsedTargetId,
      'marked_for_user_id': parsedTargetId,
      'marked_by_user_id': parsedCurrentId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'TEAM',
      'check_in_photo': photoBase64,
    };

    dynamic response;
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      try {
        const secondaryEndpoint = '/api/v1/attendance/check-in';
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'team_check_in');
    }

    throw Exception('Failed to record team attendance on portal endpoint.');
  }

  /// Submit employee Check-In transaction
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    const primaryEndpoint = '/api/v1/attendance/check-in/';
    const secondaryEndpoint = '/api/v1/attendance/check-in';

    final user = AuthStorageService().currentUser;
    final userIdStr = _getCleanUserId(user);
    final photoBase64 = _toBase64Photo(photoBytes);
    dynamic parsedUserId = int.tryParse(userIdStr) ?? userIdStr;

    final jsonBody = <String, dynamic>{
      'user_id': parsedUserId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'TEAM',
      'check_in_photo': photoBase64,
    };

    dynamic response;
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      try {
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'check_in');
    }

    throw Exception('Failed to record check-in on portal endpoint.');
  }

  /// Submit employee Check-Out transaction
  Future<AttendanceModel> checkOut({
    required String attendanceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    const primaryEndpoint = '/api/v1/attendance/check-out/';

    final user = AuthStorageService().currentUser;
    final userIdStr = _getCleanUserId(user);
    final photoBase64 = _toBase64Photo(photoBytes);

    final jsonBody = <String, dynamic>{
      'attendance_id': attendanceId,
      'user_id': userIdStr,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'check_out_photo_base64': photoBase64,
      'check_out_photo': photoBase64,
      'photo_base64': photoBase64,
      'photo': photoBase64,
      'image': photoBase64,
    };

    dynamic response;
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      try {
        const secondaryEndpoint = '/api/v1/attendance/check-out';
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'check_out', isCheckOut: true);
    }

    throw Exception('Failed to record check-out on portal endpoint.');
  }

  /// Fetch user attendance history timeline
  Future<List<AttendanceModel>> fetchHistory({
    int page = 0,
    int size = 50,
    String? statusFilter,
  }) async {
    final queryParams = 'page=$page&size=$size${statusFilter != null && statusFilter.isNotEmpty ? "&status=$statusFilter" : ""}';
    final primaryEndpoint = '/api/v1/attendance/history/?$queryParams';
    final secondaryEndpoint = '/api/v1/attendance/?$queryParams';

    List<AttendanceModel> allRecords = [];

    try {
      final response = await apiClient.get(primaryEndpoint);
      final parsed = _parseAttendanceList(response);
      allRecords.addAll(parsed);
    } catch (_) {}

    if (allRecords.isEmpty) {
      try {
        final response = await apiClient.get(secondaryEndpoint);
        final parsed = _parseAttendanceList(response);
        allRecords.addAll(parsed);
      } catch (_) {}
    }

    return allRecords;
  }

  /// Fetch team pending attendance approvals
  Future<List<AttendanceModel>> fetchPendingApprovals({
    int page = 0,
    int size = 20,
  }) async {
    final queryParams = 'page=$page&size=$size';
    final primaryEndpoint = '/api/v1/attendance/pending-approvals/?$queryParams';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseAttendanceList(response);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Pending approvals endpoint error: $e');
      }
      return [];
    }
  }

  // Helper parsing methods
  DailyMuster? _parseDailyMuster(dynamic response) {
    if (response == null) return null;
    if (response is Map<String, dynamic>) {
      if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
        return DailyMuster.fromJson(response['data'] as Map<String, dynamic>);
      }
      return DailyMuster.fromJson(response);
    }
    return null;
  }

  List<DailyMuster> _parseDailyMusterList(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response['results'] ?? response['content'] ?? response['items'] ?? response;
      if (data is List) {
        list = data;
      } else if (response['musters'] is List) {
        list = response['musters'] as List;
      }
    } else if (response is List) {
      list = response;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => DailyMuster.fromJson(json))
        .toList();
  }

  List<AttendanceModel> _parseAttendanceList(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        if (data['team_members'] is List) {
          list = data['team_members'] as List<dynamic>;
        } else if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['history'] is List) {
          list = data['history'] as List<dynamic>;
        } else if (data['records'] is List) {
          list = data['records'] as List<dynamic>;
        } else if (data['machines'] is List) {
          list = data['machines'] as List<dynamic>;
        } else if (data['content'] is List) {
          list = data['content'] as List<dynamic>;
        } else if (data['items'] is List) {
          list = data['items'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      } else if (response['team_members'] is List) {
        list = response['team_members'] as List<dynamic>;
      } else if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      } else if (response['history'] is List) {
        list = response['history'] as List<dynamic>;
      } else if (response['records'] is List) {
        list = response['records'] as List<dynamic>;
      } else if (response['machines'] is List) {
        list = response['machines'] as List<dynamic>;
      } else if (response['items'] is List) {
        list = response['items'] as List<dynamic>;
      }
    } else if (response is List) {
      list = response;
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => AttendanceModel.fromJson(json))
        .toList();
  }

  List<Machine> _parseMachineList(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        if (data['assigned_machines'] is List) {
          list = data['assigned_machines'] as List<dynamic>;
        } else if (data['machines'] is List) {
          list = data['machines'] as List<dynamic>;
        } else if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['content'] is List) {
          list = data['content'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      } else if (response['assigned_machines'] is List) {
        list = response['assigned_machines'] as List<dynamic>;
      } else if (response['machines'] is List) {
        list = response['machines'] as List<dynamic>;
      } else if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      }
    } else if (response is List) {
      list = response;
    }
    return list.whereType<Map<String, dynamic>>().map((j) => Machine.fromJson(j)).toList();
  }

  List<UserModel> _parseUserList(dynamic response) {
    List<dynamic> list = [];
    if (response is Map<String, dynamic>) {
      dynamic data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        if (data['team_members'] is List) {
          list = data['team_members'] as List<dynamic>;
        } else if (data['results'] is List) {
          list = data['results'] as List<dynamic>;
        } else if (data['content'] is List) {
          list = data['content'] as List<dynamic>;
        }
      } else if (data is List) {
        list = data;
      } else if (response['team_members'] is List) {
        list = response['team_members'] as List<dynamic>;
      } else if (response['results'] is List) {
        list = response['results'] as List<dynamic>;
      }
    } else if (response is List) {
      list = response;
    }
    return list.whereType<Map<String, dynamic>>().map((j) => UserModel.fromJson(j)).toList();
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_storage_service.dart';
import '../../models/attendance_model.dart';
import '../../models/machine.dart';
import '../attendance_storage_service.dart';
import 'api_client.dart';

/// Dedicated API Service for Employee Attendance transactions, Machine Attendance, Team Attendance, and Manager Approvals
class AttendanceApiService {
  final ApiClient apiClient;

  AttendanceApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

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

  /// Fetch today's active attendance record for the authenticated user from GET /api/v1/attendance/today/
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

  /// Fetch machines assigned to the currently authenticated user from GET /api/v1/attendance/my-assigned-machines/
  Future<List<Machine>> fetchMyAssignedMachines({String? date}) async {
    final todayStr = date ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final teamEndpoint = '/api/v1/attendance/team-attendance/?date=$todayStr';
    const primaryEndpoint = '/api/v1/attendance/my-assigned-machines/';
    const secondaryEndpoint = '/api/v1/machines/assigned/';
    const tertiaryEndpoint = '/api/v1/machines/';

    try {
      final response = await apiClient.get(teamEndpoint);
      final machines = _parseMachineList(response);
      if (machines.isNotEmpty) return machines;
    } catch (_) {}

    try {
      final response = await apiClient.get(primaryEndpoint);
      final machines = _parseMachineList(response);
      if (machines.isNotEmpty) return machines;
    } catch (_) {}

    try {
      final response = await apiClient.get(secondaryEndpoint);
      final machines = _parseMachineList(response);
      if (machines.isNotEmpty) return machines;
    } catch (_) {}

    try {
      final response = await apiClient.get(tertiaryEndpoint);
      return _parseMachineList(response);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Fetch assigned machines error: $e');
      }
      return [];
    }
  }

  /// Fetch authorized team members for supervisor from GET /api/v1/attendance/team-attendance/
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

  /// Submit Machine Attendance transaction via POST /api/v1/attendance/machine-check-in/
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

    final jsonBody = <String, dynamic>{
      'user_id': userIdStr,
      'machine_id': mId,
      'machine_chassis_no': mChassis,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'MACHINE',
      'check_in_photo_base64': photoBase64,
      'check_in_photo': photoBase64,
      'photo_base64': photoBase64,
      'photo': photoBase64,
      'image': photoBase64,
    };

    if (kDebugMode) {
      print('[AttendanceApiService] MACHINE CHECK-IN STARTED for machine_id: $mId, chassis: $mChassis, user_id: $userIdStr');
    }

    dynamic response;

    // 1. Primary JSON POST
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary JSON machine check-in failed ($e), trying fallback...');
      }
      try {
        response = await apiClient.post(fallbackEndpoint, body: jsonBody);
      } catch (_) {}
    }

    // 2. Fallback to Multipart Upload
    if (response == null && photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final filename = photoFilename ?? 'check_in_photo.jpg';
        final fields = <String, String>{
          'user_id': userIdStr,
          'machine_id': mId,
          'machine_chassis_no': mChassis,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'accuracy': accuracy.toString(),
          'location_source': locationSource,
          'attendance_type': 'MACHINE',
          'check_in_photo_base64': photoBase64,
        };
        final fileParts = <http.MultipartFile>[
          http.MultipartFile.fromBytes('check_in_photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('image', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('machine_photo', photoBytes, filename: filename),
        ];
        response = await apiClient.postMultipart(primaryEndpoint, fields: fields, files: fileParts);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      if (kDebugMode) {
        print('[AttendanceApiService] MACHINE CHECK-IN SUCCESS RESPONSE: $response');
      }
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'machine_check_in');
    }

    throw Exception('Invalid response received from machine check-in endpoint.');
  }

  /// Submit Team Attendance transaction for self or a team member via POST /api/v1/attendance/check-in/
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

    // If marking attendance for self, route directly to self check-in endpoint
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

    final jsonBody = <String, dynamic>{
      'user_id': targetUserIdStr,
      'marked_for_user_id': targetUserIdStr,
      'marked_by_user_id': currentUserIdStr,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'TEAM',
      'check_in_photo_base64': photoBase64,
      'check_in_photo': photoBase64,
      'photo_base64': photoBase64,
      'photo': photoBase64,
      'image': photoBase64,
    };

    if (kDebugMode) {
      print('[AttendanceApiService] TEAM CHECK-IN STARTED for target_user_id: $targetUserIdStr by supervisor: $currentUserIdStr');
    }

    dynamic response;

    // 1. Primary JSON POST
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary JSON team check-in failed ($e), trying secondary endpoint...');
      }
      try {
        const secondaryEndpoint = '/api/v1/attendance/check-in';
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (e2) {
        if (kDebugMode) {
          print('[AttendanceApiService] Secondary JSON team check-in failed ($e2)...');
        }
      }
    }

    // 2. Fallback to Multipart Upload
    if (response == null && photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final filename = photoFilename ?? 'check_in_photo.jpg';
        final fields = <String, String>{
          'user_id': targetUserIdStr,
          'marked_for_user_id': targetUserIdStr,
          'marked_by_user_id': currentUserIdStr,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'accuracy': accuracy.toString(),
          'location_source': locationSource,
          'attendance_type': 'TEAM',
          'check_in_photo_base64': photoBase64,
        };
        final fileParts = <http.MultipartFile>[
          http.MultipartFile.fromBytes('check_in_photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('image', photoBytes, filename: filename),
        ];
        response = await apiClient.postMultipart(primaryEndpoint, fields: fields, files: fileParts);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      if (kDebugMode) {
        print('[AttendanceApiService] TEAM CHECK-IN SUCCESS RESPONSE: $response');
      }
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'team_check_in');
    }

    throw Exception('Failed to record team attendance on portal endpoint.');
  }

  /// Submit employee Check-In transaction with photo and real-time GPS coordinates via POST /api/v1/attendance/check-in/
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

    final jsonBody = <String, dynamic>{
      'user_id': userIdStr,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'attendance_type': 'TEAM',
      'check_in_photo_base64': photoBase64,
      'check_in_photo': photoBase64,
      'photo_base64': photoBase64,
      'photo': photoBase64,
      'image': photoBase64,
    };

    if (kDebugMode) {
      print('[AttendanceApiService] CHECK-IN STARTED for user_id: $userIdStr');
      print('[AttendanceApiService] endpoint: $primaryEndpoint, lat: $latitude, lng: $longitude, acc: $accuracy, source: $locationSource');
    }

    dynamic response;

    // 1. Primary JSON POST
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary JSON check-in failed ($e), trying secondary endpoint...');
      }
      try {
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (e2) {
        if (kDebugMode) {
          print('[AttendanceApiService] Secondary JSON check-in failed ($e2), trying multipart...');
        }
      }
    }

    // 2. Fallback to Multipart Upload
    if (response == null && photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final filename = photoFilename ?? 'check_in_photo.jpg';
        final fields = <String, String>{
          'user_id': userIdStr,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'accuracy': accuracy.toString(),
          'location_source': locationSource,
          'attendance_type': 'TEAM',
          'check_in_photo_base64': photoBase64,
        };
        final fileParts = <http.MultipartFile>[
          http.MultipartFile.fromBytes('check_in_photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('image', photoBytes, filename: filename),
        ];
        response = await apiClient.postMultipart(primaryEndpoint, fields: fields, files: fileParts);
      } catch (e) {
        if (kDebugMode) {
          print('[AttendanceApiService] Multipart check-in fallback failed: $e');
        }
      }
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      if (kDebugMode) {
        print('[AttendanceApiService] CHECK-IN SUCCESS RESPONSE: $response');
      }
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'check_in');
    }

    throw Exception('Failed to record check-in on portal endpoint.');
  }

  /// Submit employee Check-Out transaction with photo and real-time GPS coordinates via POST /api/v1/attendance/check-out/
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

    if (kDebugMode) {
      print('[AttendanceApiService] CHECK-OUT STARTED for attendance_id: $attendanceId, user_id: $userIdStr');
    }

    dynamic response;

    // 1. Primary JSON POST
    try {
      response = await apiClient.post(primaryEndpoint, body: jsonBody);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Primary JSON check-out failed ($e), trying secondary endpoint...');
      }
      try {
        const secondaryEndpoint = '/api/v1/attendance/check-out';
        response = await apiClient.post(secondaryEndpoint, body: jsonBody);
      } catch (_) {}
    }

    // 2. Fallback to Multipart Upload
    if (response == null && photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final filename = photoFilename ?? 'check_out_photo.jpg';
        final fields = <String, String>{
          'attendance_id': attendanceId,
          'user_id': userIdStr,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'accuracy': accuracy.toString(),
          'location_source': locationSource,
          'check_out_photo_base64': photoBase64,
        };
        final fileParts = <http.MultipartFile>[
          http.MultipartFile.fromBytes('check_out_photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('photo', photoBytes, filename: filename),
          http.MultipartFile.fromBytes('image', photoBytes, filename: filename),
        ];
        response = await apiClient.postMultipart(primaryEndpoint, fields: fields, files: fileParts);
      } catch (_) {}
    }

    AttendanceModel? parsed = _parseTodayAttendanceResponse(response);
    if (parsed == null && response is Map<String, dynamic>) {
      parsed = AttendanceModel.fromJson(response);
    }

    if (parsed != null) {
      if (kDebugMode) {
        print('[AttendanceApiService] CHECK-OUT SUCCESS RESPONSE: $response');
      }
      return await _ensurePhotoUrl(parsed, photoBytes, photoBase64, prefix: 'check_out', isCheckOut: true);
    }

    throw Exception('Failed to record check-out on portal endpoint.');
  }

  /// Fetch user attendance history timeline from GET /api/v1/attendance/history/
  Future<List<AttendanceModel>> fetchHistory({
    int page = 0,
    int size = 20,
    String? statusFilter,
  }) async {
    final queryParams = 'page=$page&size=$size${statusFilter != null && statusFilter.isNotEmpty ? "&status=$statusFilter" : ""}';
    final primaryEndpoint = '/api/v1/attendance/history/?$queryParams';

    try {
      final response = await apiClient.get(primaryEndpoint);
      return _parseAttendanceList(response);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] History endpoint error: $e');
      }
      return [];
    }
  }

  /// Fetch team pending attendance approvals for reporting manager from GET /api/v1/attendance/pending-approvals/
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

  /// Reporting manager approves attendance transaction via POST /api/v1/attendance/{id}/approve/
  Future<bool> approveAttendance(String attendanceId) async {
    final endpoint = '/api/v1/attendance/$attendanceId/approve/';
    try {
      await apiClient.post(endpoint, body: {});
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Approve attendance error: $e');
      }
      return false;
    }
  }

  /// Reporting manager rejects attendance transaction via POST /api/v1/attendance/{id}/reject/
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    final endpoint = '/api/v1/attendance/$attendanceId/reject/';
    try {
      await apiClient.post(endpoint, body: {'reason': reason});
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceApiService] Reject attendance error: $e');
      }
      return false;
    }
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

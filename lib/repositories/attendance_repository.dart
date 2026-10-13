import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/utils/vendor_utils.dart';
import '../features/auth/models/user_model.dart';
import '../features/auth/services/auth_storage_service.dart';
import '../models/app_notification.dart';
import '../models/attendance_model.dart';
import '../models/machine.dart';
import '../models/muster_model.dart';
import '../services/api/attendance_api_service.dart';
import '../services/attendance_storage_service.dart';
import '../services/notification_service.dart';
import 'machine_repository.dart';
import 'user_repository.dart';

abstract class AttendanceRepository {
  // Documented DailyMuster APIs
  Future<DailyMuster?> getTodaysMuster(String taskId);
  Future<DailyMuster> createMuster(String taskId, Map<String, dynamic> body);
  Future<DailyMuster> getMusterDetail(String musterId);
  Future<DailyMuster> updateMuster(String musterId, Map<String, dynamic> body);
  Future<bool> submitMuster(String musterId, {String? stepUpToken});
  Future<List<DailyMuster>> getPendingMusterApprovals();
  Future<bool> approveMuster(String musterId, {String remarks});
  Future<bool> rejectMuster(String musterId, {required String reason});
  Future<List<DailyMuster>> getMusterHistoryForTask(String taskId);
  Future<List<DailyMuster>> getGeneralMusterList();
  Future<PhotoUploadUrlResponse> getPhotoUploadUrl({
    required String musterId,
    required String entryId,
    String contentType = 'image/jpeg',
  });
  Future<bool> uploadAttendancePhoto({
    required String uploadUrl,
    required List<int> imageBytes,
    String contentType = 'image/jpeg',
  });
  Future<String> getPhotoUrl({
    required String musterId,
    required String photoKey,
  });

  // Standard Attendance API methods
  Future<AttendanceModel?> getTodayAttendance();
  Future<List<Machine>> getAssignedMachines(String userId);
  Future<List<Machine>> getTeamAttendanceMachines(String userId);
  Future<List<UserModel>> getAuthorizedTeamMembers(String supervisorId);
  Future<AttendanceModel> checkInMachine({
    required Machine machine,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  });
  Future<AttendanceModel> checkInTeamMember({
    required UserModel targetMember,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  });
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  });
  Future<AttendanceModel> checkOut({
    required String attendanceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  });
  Future<List<AttendanceModel>> getHistory({
    int page = 0,
    String? statusFilter,
  });
  Future<List<AttendanceModel>> getPendingApprovals({int page = 0});
  Future<bool> approveAttendance(String attendanceId);
  Future<bool> rejectAttendance(String attendanceId, String reason);
  Future<int> syncPendingRecords();
}

/// Local Persistent Repository for Local/Testing Mode
class LocalAttendanceRepository implements AttendanceRepository {
  final AttendanceStorageService storageService;
  final MachineRepository machineRepository;
  final UserRepository userRepository;

  final Map<String, DailyMuster> _localMusters = {};

  LocalAttendanceRepository({
    AttendanceStorageService? storageService,
    MachineRepository? machineRepository,
    UserRepository? userRepository,
  }) : storageService = storageService ?? AttendanceStorageService(),
       machineRepository = machineRepository ?? MockMachineRepository(),
       userRepository = userRepository ?? ApiUserRepository();

  @override
  Future<DailyMuster?> getTodaysMuster(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return null;
    for (final muster in _localMusters.values) {
      if (muster.workedOnTaskIds.contains(cleanTaskId)) {
        return muster;
      }
    }
    return null;
  }

  @override
  Future<DailyMuster> createMuster(
    String taskId,
    Map<String, dynamic> body,
  ) async {
    final cleanTaskId = taskId.trim();
    final id = 'muster_${DateTime.now().millisecondsSinceEpoch}';

    List<MusterEntry> entryList = [];
    if (body['entries'] is List) {
      entryList = (body['entries'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MusterEntry.fromJson(e))
          .toList();
    }

    final muster = DailyMuster(
      id: id,
      clientMusterId: body['clientMusterId']?.toString() ?? id,
      workedOnTaskIds: cleanTaskId.isNotEmpty ? [cleanTaskId] : [],
      teamSource: body['teamSource']?.toString() ?? 'LOCAL_CREW',
      vendorId: body['vendorId']?.toString() ?? 'VEND-01',
      vendorName: body['vendorName']?.toString() ?? 'Hero Vendor',
      headcount: body['headcount'] as int? ?? 1,
      resources: body['resources'] is List
          ? body['resources'] as List
          : const [],
      entries: entryList,
      nilWork: body['nilWork'] as bool? ?? false,
      nilWorkReason: body['nilWorkReason']?.toString(),
      remarks: body['remarks']?.toString() ?? '',
      status: 'DRAFT',
      approvalStatus: 'PENDING',
      createdAt: DateTime.now(),
    );

    _localMusters[id] = muster;
    return muster;
  }

  @override
  Future<DailyMuster> getMusterDetail(String musterId) async {
    final m = _localMusters[musterId];
    if (m != null) return m;
    throw Exception('Muster $musterId not found in local store.');
  }

  @override
  Future<DailyMuster> updateMuster(
    String musterId,
    Map<String, dynamic> body,
  ) async {
    final existing = _localMusters[musterId];

    List<MusterEntry> updatedEntries = existing?.entries ?? [];
    if (body['entries'] is List) {
      updatedEntries = (body['entries'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MusterEntry.fromJson(e))
          .toList();
    }

    final updated =
        (existing ??
                DailyMuster(
                  id: musterId,
                  clientMusterId: musterId,
                  workedOnTaskIds: const [],
                ))
            .copyWith(
              entries: updatedEntries,
              remarks: body['remarks']?.toString() ?? existing?.remarks ?? '',
              updatedAt: DateTime.now(),
            );

    _localMusters[musterId] = updated;
    return updated;
  }

  @override
  Future<bool> submitMuster(String musterId, {String? stepUpToken}) async {
    final existing = _localMusters[musterId];
    if (existing != null) {
      _localMusters[musterId] = existing.copyWith(
        status: 'SUBMITTED',
        approvalStatus: 'PENDING',
        submittedAt: DateTime.now(),
      );
      return true;
    }
    return true;
  }

  @override
  Future<List<DailyMuster>> getPendingMusterApprovals() async {
    return _localMusters.values
        .where((m) => m.status == 'SUBMITTED' || m.approvalStatus == 'PENDING')
        .toList();
  }

  @override
  Future<bool> approveMuster(
    String musterId, {
    String remarks = 'Attendance approved',
  }) async {
    final existing = _localMusters[musterId];
    if (existing != null) {
      _localMusters[musterId] = existing.copyWith(
        status: 'APPROVED',
        approvalStatus: 'APPROVED',
        approvedBy: 'Reporting Manager',
        approvedAt: DateTime.now(),
        remarks: remarks,
      );
      return true;
    }
    return true;
  }

  @override
  Future<bool> rejectMuster(String musterId, {required String reason}) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Rejection reason is mandatory.');
    }
    final existing = _localMusters[musterId];
    if (existing != null) {
      _localMusters[musterId] = existing.copyWith(
        status: 'REJECTED',
        approvalStatus: 'REJECTED',
        rejectionReason: cleanReason,
        updatedAt: DateTime.now(),
      );
      return true;
    }
    return true;
  }

  @override
  Future<List<DailyMuster>> getMusterHistoryForTask(String taskId) async {
    final cleanTaskId = taskId.trim();
    return _localMusters.values
        .where((m) => m.workedOnTaskIds.contains(cleanTaskId))
        .toList();
  }

  @override
  Future<List<DailyMuster>> getGeneralMusterList() async {
    return _localMusters.values.toList();
  }

  @override
  Future<PhotoUploadUrlResponse> getPhotoUploadUrl({
    required String musterId,
    required String entryId,
    String contentType = 'image/jpeg',
  }) async {
    final key =
        'attendance/${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}/${musterId}_$entryId.jpg';
    return PhotoUploadUrlResponse(
      success: true,
      data: PhotoUploadData(
        uploadUrl: 'https://hero-app-mock-s3.s3.amazonaws.com/$key',
        photoKey: key,
      ),
    );
  }

  @override
  Future<bool> uploadAttendancePhoto({
    required String uploadUrl,
    required List<int> imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    return true;
  }

  @override
  Future<String> getPhotoUrl({
    required String musterId,
    required String photoKey,
  }) async {
    if (photoKey.isEmpty) return '';
    if (photoKey.startsWith('http://') || photoKey.startsWith('https://')) {
      return photoKey;
    }
    return 'https://hero-app-mock-s3.s3.amazonaws.com/$photoKey?temp_token=abc123val';
  }

  // Standard Attendance methods
  @override
  Future<AttendanceModel?> getTodayAttendance() async {
    final user = AuthStorageService().currentUser;
    final userId = user?.id ?? 'user_1';
    return await storageService.getTodayRecord(userId);
  }

  @override
  Future<List<Machine>> getAssignedMachines(String userId) async {
    final user = AuthStorageService().currentUser;
    final allMachines = await machineRepository.getAllMachines();

    if (allMachines.isEmpty) return [];

    // System Admins see all fleet machines
    if (user != null && user.isAdmin) {
      return allMachines;
    }

    final cleanUserId = userId.trim().toLowerCase();
    final currentUserId = (user?.id ?? '').trim().toLowerCase();
    final displayName = (user?.displayName ?? '').trim().toLowerCase();
    final username = (user?.username ?? '').trim().toLowerCase();
    final name = (user?.name ?? '').trim().toLowerCase();
    final phone = (user?.phoneNumber ?? '').trim().toLowerCase();
    final empId = (user?.employeeId ?? '').trim().toLowerCase();

    final matched = allMachines.where((m) {
      final mChassis = m.machineChassisNo.trim().toLowerCase();

      String mOpName = '';
      String mOpMobile = '';
      String mOpUserId = '';

      if (m.operatorInfo is Map) {
        final map = m.operatorInfo as Map;
        mOpName = (map['name'] ?? map['operator_name'] ?? map['userName'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        mOpMobile = (map['mobile'] ?? map['phoneNumber'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        mOpUserId = (map['id'] ?? map['user_id'] ?? map['userId'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
      } else if (m.operatorInfo != null) {
        mOpName = m.operatorInfo.toString().trim().toLowerCase();
      }

      // 1. Direct Operator Match
      final bool isOperatorMatch =
          (mOpUserId.isNotEmpty &&
              (mOpUserId == cleanUserId || mOpUserId == currentUserId)) ||
          (mOpName.isNotEmpty &&
              ((displayName.isNotEmpty &&
                      (mOpName.contains(displayName) ||
                          displayName.contains(mOpName))) ||
                  (username.isNotEmpty &&
                      (mOpName.contains(username) ||
                          username.contains(mOpName))) ||
                  (name.isNotEmpty &&
                      (mOpName.contains(name) || name.contains(mOpName))))) ||
          (mOpMobile.isNotEmpty &&
              phone.isNotEmpty &&
              (mOpMobile.contains(phone) || phone.contains(mOpMobile))) ||
          (empId.isNotEmpty &&
              (mChassis.contains(empId) || mOpName.contains(empId)));

      // 2. Vendor Match
      final bool isVendorMatch =
          VendorUtils.isVendorMatch(m.vendorName, user?.vendorName) ||
          VendorUtils.isVendorMatch(m.vendorName, user?.displayVendor) ||
          (user != null &&
              user.vendors.isNotEmpty &&
              VendorUtils.matchesUserVendors(
                m.vendorName,
                user.vendors.map((v) => v['name']?.toString() ?? '').toSet(),
              ));

      return isOperatorMatch || isVendorMatch;
    }).toList();

    return matched;
  }

  @override
  Future<List<Machine>> getTeamAttendanceMachines(String userId) async =>
      getAssignedMachines(userId);

  @override
  Future<List<UserModel>> getAuthorizedTeamMembers(String supervisorId) async {
    final res = await userRepository.getUsersResponse(page: 0, size: 50);
    return res.users;
  }

  @override
  Future<AttendanceModel> checkInMachine({
    required Machine machine,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final user = AuthStorageService().currentUser;
    final userId = user?.id ?? '';
    final userName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? '');
    final empId = user?.employeeId ?? '';
    final managerId = user?.reportingManagerId ?? '';
    final managerName = user?.reportingManagerName ?? '';

    final attId = 'ATT_MACH_${DateTime.now().millisecondsSinceEpoch}';

    String? localPhotoPath;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      localPhotoPath = await storageService.savePhotoLocally(
        attendanceId: attId,
        photoBytes: photoBytes,
        prefix: 'machine_check_in',
      );
    }

    final now = DateTime.now();

    final model = AttendanceModel(
      id: attId,
      userId: userId,
      userName: userName,
      employeeId: empId,
      attendanceType: 'MACHINE',
      machineId: machine.machineChassisNo,
      machineChassisNo: machine.machineChassisNo,
      machineAssignmentId: 'ASSIGN_${machine.machineChassisNo}',
      vendorId: machine.vendorName,
      siteId: machine.siteName,
      reportingManagerId: managerId,
      reportingManagerName: managerName,
      status: 'PENDING',
      checkInTime: now,
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      checkInPhotoUrl: localPhotoPath,
      locationSource: locationSource,
      approvalStatus: 'PENDING',
      createdAt: now,
      isSynced: false,
    );

    await storageService.saveRecord(model);
    return model;
  }

  @override
  Future<AttendanceModel> checkInTeamMember({
    required UserModel targetMember,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final currentUser = AuthStorageService().currentUser;
    final currentUserId = currentUser?.id ?? '1';
    final currentUserName = currentUser?.displayName ?? 'Supervisor';

    final managerId = targetMember.reportingManagerId ?? currentUserId;
    final managerName = targetMember.reportingManagerName ?? currentUserName;

    final attId = 'ATT_TEAM_${DateTime.now().millisecondsSinceEpoch}';

    String? localPhotoPath;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      localPhotoPath = await storageService.savePhotoLocally(
        attendanceId: attId,
        photoBytes: photoBytes,
        prefix: 'team_check_in',
      );
    }

    final now = DateTime.now();

    final model = AttendanceModel(
      id: attId,
      userId: targetMember.id,
      userName: targetMember.displayName,
      employeeId: targetMember.displayEmployeeId,
      attendanceType: 'TEAM',
      markedForUserId: targetMember.id,
      markedForUserName: targetMember.displayName,
      markedByUserId: currentUserId,
      markedByUserName: currentUserName,
      reportingManagerId: managerId,
      reportingManagerName: managerName,
      status: 'PENDING',
      checkInTime: now,
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      checkInPhotoUrl: localPhotoPath,
      locationSource: locationSource,
      approvalStatus: 'PENDING',
      createdAt: now,
      isSynced: false,
    );

    await storageService.saveRecord(model);
    return model;
  }

  @override
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final user = AuthStorageService().currentUser;
    final userId = user?.id ?? '';
    final userName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.username ?? '');
    final empId = user?.employeeId ?? '';
    final managerId = user?.reportingManagerId ?? '';
    final managerName = user?.reportingManagerName ?? '';

    final attId = 'ATT_${DateTime.now().millisecondsSinceEpoch}';

    String? localPhotoPath;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      localPhotoPath = await storageService.savePhotoLocally(
        attendanceId: attId,
        photoBytes: photoBytes,
        prefix: 'check_in',
      );
    }

    final now = DateTime.now();

    final model = AttendanceModel(
      id: attId,
      userId: userId,
      userName: userName,
      employeeId: empId,
      attendanceType: 'TEAM',
      markedForUserId: userId,
      markedForUserName: userName,
      markedByUserId: userId,
      markedByUserName: userName,
      reportingManagerId: managerId,
      reportingManagerName: managerName,
      status: 'PENDING',
      checkInTime: now,
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      checkInPhotoUrl: localPhotoPath,
      locationSource: locationSource,
      approvalStatus: 'PENDING',
      createdAt: now,
      isSynced: false,
    );

    await storageService.saveRecord(model);
    return model;
  }

  @override
  Future<AttendanceModel> checkOut({
    required String attendanceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final all = await storageService.getAllRecords();
    final existing = all.firstWhere(
      (r) => r.id == attendanceId,
      orElse: () =>
          throw Exception('Attendance record not found for check-out'),
    );

    String? localPhotoPath;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      localPhotoPath = await storageService.savePhotoLocally(
        attendanceId: attendanceId,
        photoBytes: photoBytes,
        prefix: 'check_out',
      );
    }

    final now = DateTime.now();

    int totalSec = 0;
    String formattedHours = '00h 00m';
    if (existing.checkInTime != null) {
      totalSec = now.difference(existing.checkInTime!).inSeconds;
      final hrs = totalSec ~/ 3600;
      final mins = (totalSec % 3600) ~/ 60;
      formattedHours =
          '${hrs.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
    }

    final updated = AttendanceModel(
      id: existing.id,
      userId: existing.userId,
      userName: existing.userName,
      employeeId: existing.employeeId,
      attendanceType: existing.attendanceType,
      machineId: existing.machineId,
      machineChassisNo: existing.machineChassisNo,
      machineAssignmentId: existing.machineAssignmentId,
      vendorId: existing.vendorId,
      siteId: existing.siteId,
      markedForUserId: existing.markedForUserId,
      markedForUserName: existing.markedForUserName,
      markedByUserId: existing.markedByUserId,
      markedByUserName: existing.markedByUserName,
      reportingManagerId: existing.reportingManagerId,
      reportingManagerName: existing.reportingManagerName,
      status: 'CHECKED_OUT',
      checkInTime: existing.checkInTime,
      checkInLat: existing.checkInLat,
      checkInLng: existing.checkInLng,
      checkInAccuracy: existing.checkInAccuracy,
      checkInPhotoUrl: existing.checkInPhotoUrl,
      locationSource: existing.locationSource,
      checkOutTime: now,
      checkOutLat: latitude,
      checkOutLng: longitude,
      checkOutAccuracy: accuracy,
      checkOutPhotoUrl: localPhotoPath,
      totalWorkingSeconds: totalSec,
      formattedWorkingHours: formattedHours,
      approvalStatus: existing.approvalStatus,
      approvedBy: existing.approvedBy,
      approvedAt: existing.approvedAt,
      createdAt: existing.createdAt,
      isSynced: false,
    );

    await storageService.saveRecord(updated);
    return updated;
  }

  @override
  Future<List<AttendanceModel>> getHistory({
    int page = 0,
    String? statusFilter,
  }) async {
    final records = await storageService.getAllRecords();
    if (statusFilter != null && statusFilter != 'ALL') {
      return records.where((r) {
        if (statusFilter == 'APPROVED' || statusFilter == 'PRESENT')
          return r.isApproved || r.status == 'PRESENT';
        if (statusFilter == 'PENDING')
          return r.isPendingApproval || r.status == 'PENDING';
        if (statusFilter == 'REJECTED')
          return r.isRejected || r.status == 'REJECTED';
        return true;
      }).toList();
    }
    return records;
  }

  @override
  Future<List<AttendanceModel>> getPendingApprovals({int page = 0}) async {
    final user = AuthStorageService().currentUser;
    final currentUserId = user?.id ?? '1';
    final currentUsername = (user?.username ?? '').toLowerCase();
    final currentName = (user?.displayName ?? '').toLowerCase();

    final records = await storageService.getAllRecords();

    if (user != null && user.isAdmin) {
      return records
          .where((r) => r.isPendingApproval || r.status == 'PENDING')
          .toList();
    }

    return records.where((r) {
      final isPending = r.isPendingApproval || r.status == 'PENDING';
      final isAssignedManager =
          r.reportingManagerId == currentUserId ||
          (r.reportingManagerName != null &&
              (r.reportingManagerName!.toLowerCase() == currentUsername ||
                  r.reportingManagerName!.toLowerCase() == currentName));
      return isPending && isAssignedManager;
    }).toList();
  }

  @override
  Future<bool> approveAttendance(String attendanceId) async {
    final user = AuthStorageService().currentUser;
    final currentAdminId = user?.id ?? '1';
    final currentAdminUsername = user?.username ?? 'admin';
    final currentAdminName = user?.displayName ?? 'admin';

    final all = await storageService.getAllRecords();
    final index = all.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      final existing = all[index];

      if (existing.userId == currentAdminId ||
          existing.userName.toLowerCase() ==
              currentAdminUsername.toLowerCase() ||
          existing.userName.toLowerCase() == currentAdminName.toLowerCase()) {
        throw Exception('You cannot approve your own attendance.');
      }

      final managerName = currentAdminName.isNotEmpty
          ? currentAdminName
          : currentAdminUsername;

      final updated = AttendanceModel(
        id: existing.id,
        userId: existing.userId,
        userName: existing.userName,
        employeeId: existing.employeeId,
        attendanceType: existing.attendanceType,
        machineId: existing.machineId,
        machineChassisNo: existing.machineChassisNo,
        machineAssignmentId: existing.machineAssignmentId,
        vendorId: existing.vendorId,
        siteId: existing.siteId,
        markedForUserId: existing.markedForUserId,
        markedForUserName: existing.markedForUserName,
        markedByUserId: existing.markedByUserId,
        markedByUserName: existing.markedByUserName,
        reportingManagerId: existing.reportingManagerId,
        reportingManagerName: existing.reportingManagerName,
        status: 'PRESENT',
        checkInTime: existing.checkInTime,
        checkInLat: existing.checkInLat,
        checkInLng: existing.checkInLng,
        checkInAccuracy: existing.checkInAccuracy,
        checkInPhotoUrl: existing.checkInPhotoUrl,
        locationSource: existing.locationSource,
        checkOutTime: existing.checkOutTime,
        checkOutLat: existing.checkOutLat,
        checkOutLng: existing.checkOutLng,
        checkOutAccuracy: existing.checkOutAccuracy,
        checkOutPhotoUrl: existing.checkOutPhotoUrl,
        totalWorkingSeconds: existing.totalWorkingSeconds,
        formattedWorkingHours: existing.formattedWorkingHours,
        approvalStatus: 'APPROVED',
        approvedBy: managerName,
        approvedAt: DateTime.now(),
        createdAt: existing.createdAt,
      );
      await storageService.saveRecord(updated);

      final dateStr = existing.checkInTime != null
          ? DateFormat('dd MMM yyyy').format(existing.checkInTime!)
          : 'Today';

      await NotificationService().addNotification(
        AppNotification(
          id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: existing.userId,
          type: 'ATTENDANCE_APPROVED',
          title: 'Attendance Approved',
          message:
              'Your attendance for $dateStr has been approved by $managerName.',
          attendanceId: existing.id,
          createdAt: DateTime.now(),
        ),
      );

      return true;
    }
    return false;
  }

  @override
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Reason for rejection is required.');
    }

    final user = AuthStorageService().currentUser;
    final currentAdminUsername = user?.username ?? 'admin';
    final currentAdminName = user?.displayName ?? 'admin';

    final all = await storageService.getAllRecords();
    final index = all.indexWhere((r) => r.id == attendanceId);
    if (index != -1) {
      final existing = all[index];
      final managerName = currentAdminName.isNotEmpty
          ? currentAdminName
          : currentAdminUsername;

      final updated = AttendanceModel(
        id: existing.id,
        userId: existing.userId,
        userName: existing.userName,
        employeeId: existing.employeeId,
        attendanceType: existing.attendanceType,
        machineId: existing.machineId,
        machineChassisNo: existing.machineChassisNo,
        machineAssignmentId: existing.machineAssignmentId,
        vendorId: existing.vendorId,
        siteId: existing.siteId,
        markedForUserId: existing.markedForUserId,
        markedForUserName: existing.markedForUserName,
        markedByUserId: existing.markedByUserId,
        markedByUserName: existing.markedByUserName,
        reportingManagerId: existing.reportingManagerId,
        reportingManagerName: existing.reportingManagerName,
        status: 'REJECTED',
        checkInTime: existing.checkInTime,
        checkInLat: existing.checkInLat,
        checkInLng: existing.checkInLng,
        checkInAccuracy: existing.checkInAccuracy,
        checkInPhotoUrl: existing.checkInPhotoUrl,
        locationSource: existing.locationSource,
        checkOutTime: existing.checkOutTime,
        checkOutLat: existing.checkOutLat,
        checkOutLng: existing.checkOutLng,
        checkOutAccuracy: existing.checkOutAccuracy,
        checkOutPhotoUrl: existing.checkOutPhotoUrl,
        totalWorkingSeconds: existing.totalWorkingSeconds,
        formattedWorkingHours: existing.formattedWorkingHours,
        approvalStatus: 'REJECTED',
        approvedBy: managerName,
        approvedAt: DateTime.now(),
        rejectionReason: cleanReason,
        createdAt: existing.createdAt,
      );
      await storageService.saveRecord(updated);

      final dateStr = existing.checkInTime != null
          ? DateFormat('dd MMM yyyy').format(existing.checkInTime!)
          : 'Today';

      await NotificationService().addNotification(
        AppNotification(
          id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: existing.userId,
          type: 'ATTENDANCE_REJECTED',
          title: 'Attendance Rejected',
          message:
              'Your attendance for $dateStr has been rejected by $managerName. Reason: $cleanReason',
          reason: cleanReason,
          attendanceId: existing.id,
          createdAt: DateTime.now(),
        ),
      );

      return true;
    }
    return false;
  }

  @override
  Future<int> syncPendingRecords() async => 0;
}

class ApiAttendanceRepository implements AttendanceRepository {
  final AttendanceApiService apiService;
  final LocalAttendanceRepository localFallback;

  ApiAttendanceRepository({
    AttendanceApiService? apiService,
    LocalAttendanceRepository? localFallback,
  }) : apiService = apiService ?? AttendanceApiService(),
       localFallback = localFallback ?? LocalAttendanceRepository();

  @override
  Future<DailyMuster?> getTodaysMuster(String taskId) async {
    try {
      final remote = await apiService.getTodaysMuster(taskId);
      if (remote != null) return remote;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getTodaysMuster error: $e');
      }
    }
    return await localFallback.getTodaysMuster(taskId);
  }

  @override
  Future<DailyMuster> createMuster(
    String taskId,
    Map<String, dynamic> body,
  ) async {
    try {
      final remote = await apiService.createMuster(taskId, body);
      return remote;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote createMuster failed ($e), saving locally...',
        );
      }
      return await localFallback.createMuster(taskId, body);
    }
  }

  @override
  Future<DailyMuster> getMusterDetail(String musterId) async {
    try {
      final remote = await apiService.getMusterDetail(musterId);
      return remote;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getMusterDetail error: $e');
      }
      return await localFallback.getMusterDetail(musterId);
    }
  }

  @override
  Future<DailyMuster> updateMuster(
    String musterId,
    Map<String, dynamic> body,
  ) async {
    try {
      final remote = await apiService.updateMuster(musterId, body);
      return remote;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote updateMuster failed ($e), updating locally...',
        );
      }
      return await localFallback.updateMuster(musterId, body);
    }
  }

  @override
  Future<bool> submitMuster(String musterId, {String? stepUpToken}) async {
    try {
      return await apiService.submitMuster(musterId, stepUpToken: stepUpToken);
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote submitMuster failed ($e), submitting locally...',
        );
      }
      return await localFallback.submitMuster(
        musterId,
        stepUpToken: stepUpToken,
      );
    }
  }

  @override
  Future<List<DailyMuster>> getPendingMusterApprovals() async {
    try {
      final list = await apiService.getPendingMusterApprovals();
      if (list.isNotEmpty) return list;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getPendingMusterApprovals error: $e');
      }
    }
    return await localFallback.getPendingMusterApprovals();
  }

  @override
  Future<bool> approveMuster(
    String musterId, {
    String remarks = 'Attendance approved',
  }) async {
    try {
      return await apiService.approveAttendance(musterId);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] approveMuster error: $e');
      }
      return await localFallback.approveMuster(musterId, remarks: remarks);
    }
  }

  @override
  Future<bool> rejectMuster(String musterId, {required String reason}) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Rejection reason is mandatory.');
    }
    try {
      return await apiService.rejectAttendance(musterId, cleanReason);
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] rejectMuster error: $e');
      }
      return await localFallback.rejectMuster(musterId, reason: cleanReason);
    }
  }

  @override
  Future<List<DailyMuster>> getMusterHistoryForTask(String taskId) async {
    try {
      final list = await apiService.getMusterHistoryForTask(taskId);
      if (list.isNotEmpty) return list;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getMusterHistoryForTask error: $e');
      }
    }
    return await localFallback.getMusterHistoryForTask(taskId);
  }

  @override
  Future<List<DailyMuster>> getGeneralMusterList() async {
    try {
      final list = await apiService.getGeneralMusterList();
      if (list.isNotEmpty) return list;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getGeneralMusterList error: $e');
      }
    }
    return await localFallback.getGeneralMusterList();
  }

  @override
  Future<PhotoUploadUrlResponse> getPhotoUploadUrl({
    required String musterId,
    required String entryId,
    String contentType = 'image/jpeg',
  }) async {
    try {
      return await apiService.getPhotoUploadUrl(
        musterId: musterId,
        entryId: entryId,
        contentType: contentType,
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] getPhotoUploadUrl error ($e), falling back...',
        );
      }
      return await localFallback.getPhotoUploadUrl(
        musterId: musterId,
        entryId: entryId,
        contentType: contentType,
      );
    }
  }

  @override
  Future<bool> uploadAttendancePhoto({
    required String uploadUrl,
    required List<int> imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      return await apiService.uploadAttendancePhoto(
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        contentType: contentType,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] uploadAttendancePhoto error: $e');
      }
      return await localFallback.uploadAttendancePhoto(
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        contentType: contentType,
      );
    }
  }

  @override
  Future<String> getPhotoUrl({
    required String musterId,
    required String photoKey,
  }) async {
    try {
      final url = await apiService.getPhotoUrl(
        musterId: musterId,
        photoKey: photoKey,
      );
      if (url.isNotEmpty) return url;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getPhotoUrl error: $e');
      }
    }
    return await localFallback.getPhotoUrl(
      musterId: musterId,
      photoKey: photoKey,
    );
  }

  // Standard Attendance API methods
  @override
  Future<AttendanceModel?> getTodayAttendance() async {
    try {
      final remote = await apiService.fetchTodayAttendance();
      if (remote != null) {
        await localFallback.storageService.saveRecord(remote);
        return remote;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getTodayAttendance error: $e');
      }
    }
    return await localFallback.getTodayAttendance();
  }

  @override
  Future<List<Machine>> getAssignedMachines(String userId) async {
    try {
      return await apiService.fetchMyAssignedMachines();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getAssignedMachines error: $e');
      }
      // Do not substitute the demo/mock fleet for a signed-in account.
      return const <Machine>[];
    }
  }

  @override
  Future<List<Machine>> getTeamAttendanceMachines(String userId) async {
    try {
      return await apiService.fetchTeamAttendanceMachines();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getTeamAttendanceMachines error: $e');
      }
      // Keep the attendance roster empty on failure instead of showing the
      // different, broader personal-assignment list.
      return const <Machine>[];
    }
  }

  @override
  Future<List<UserModel>> getAuthorizedTeamMembers(String supervisorId) async {
    try {
      return await apiService.fetchAuthorizedTeamMembers();
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getAuthorizedTeamMembers error: $e');
      }
      return const <UserModel>[];
    }
  }

  @override
  Future<AttendanceModel> checkInMachine({
    required Machine machine,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    try {
      final record = await apiService.checkInMachine(
        machineChassisNo: machine.machineChassisNo,
        assignmentId: machine.id.isNotEmpty
            ? machine.id
            : machine.machineChassisNo,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      await localFallback.storageService.saveRecord(record);
      return record;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote checkInMachine failed ($e), saving locally...',
        );
      }
      return await localFallback.checkInMachine(
        machine: machine,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
    }
  }

  @override
  Future<AttendanceModel> checkInTeamMember({
    required UserModel targetMember,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    try {
      final record = await apiService.checkInTeamMember(
        targetUserId: targetMember.id,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      await localFallback.storageService.saveRecord(record);
      return record;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote checkInTeamMember failed ($e), saving locally...',
        );
      }
      return await localFallback.checkInTeamMember(
        targetMember: targetMember,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
    }
  }

  @override
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    try {
      final record = await apiService.checkIn(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      await localFallback.storageService.saveRecord(record);
      return record;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote checkIn failed ($e), saving locally...',
        );
      }
      return await localFallback.checkIn(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
    }
  }

  @override
  Future<AttendanceModel> checkOut({
    required String attendanceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    try {
      final record = await apiService.checkOut(
        attendanceId: attendanceId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
      await localFallback.storageService.saveRecord(record);
      return record;
    } catch (e) {
      if (kDebugMode) {
        print(
          '[ApiAttendanceRepository] Remote checkOut failed ($e), saving locally...',
        );
      }
      return await localFallback.checkOut(
        attendanceId: attendanceId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        locationSource: locationSource,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
      );
    }
  }

  @override
  Future<List<AttendanceModel>> getHistory({
    int page = 0,
    String? statusFilter,
  }) async {
    try {
      final list = await apiService.fetchHistory(
        page: page,
        statusFilter: statusFilter,
      );
      if (list.isNotEmpty) {
        for (final item in list) {
          await localFallback.storageService.saveRecord(item);
        }
        return list;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getHistory error: $e');
      }
    }
    return await localFallback.getHistory(
      page: page,
      statusFilter: statusFilter,
    );
  }

  @override
  Future<List<AttendanceModel>> getPendingApprovals({int page = 0}) async {
    try {
      final list = await apiService.fetchPendingApprovals(page: page);
      if (list.isNotEmpty) {
        return list;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getPendingApprovals error: $e');
      }
    }
    return await localFallback.getPendingApprovals(page: page);
  }

  @override
  Future<bool> approveAttendance(String attendanceId) async {
    return await apiService.approveAttendance(attendanceId);
  }

  @override
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    return await apiService.rejectAttendance(attendanceId, reason);
  }

  @override
  Future<int> syncPendingRecords() async {
    final unsynced = await localFallback.storageService.getUnsyncedRecords();
    if (unsynced.isEmpty) return 0;

    final currentUser = AuthStorageService().currentUser;
    final currentUserId = currentUser?.id ?? '';

    final results = await Future.wait(
      unsynced.map((record) async {
        try {
          List<int>? photoBytes;
          final photoPath = record.checkInPhotoUrl ?? record.checkOutPhotoUrl;
          if (photoPath != null &&
              photoPath.isNotEmpty &&
              !photoPath.startsWith('http') &&
              !photoPath.startsWith('data:')) {
            try {
              final file = File(photoPath);
              if (await file.exists()) {
                photoBytes = await file.readAsBytes();
              }
            } catch (_) {}
          }

          AttendanceModel? synced;

          final targetUserIdStr =
              (record.markedForUserId != null &&
                  record.markedForUserId!.isNotEmpty)
              ? record.markedForUserId!
              : record.userId;

          if (record.isMachineAttendance) {
            final chassis =
                record.machineChassisNo ?? record.machineId ?? 'N/A';
            synced = await apiService.checkInMachine(
              machineChassisNo: chassis,
              assignmentId: record.machineAssignmentId ?? chassis,
              latitude: record.checkInLat ?? 0.0,
              longitude: record.checkInLng ?? 0.0,
              accuracy: record.checkInAccuracy ?? 10.0,
              locationSource: record.locationSource ?? 'GPS',
              photoBytes: photoBytes,
            );
          } else if (targetUserIdStr.isNotEmpty &&
              (targetUserIdStr != currentUserId ||
                  record.markedForUserId != null)) {
            synced = await apiService.checkInTeamMember(
              targetUserId: targetUserIdStr,
              latitude: record.checkInLat ?? 0.0,
              longitude: record.checkInLng ?? 0.0,
              accuracy: record.checkInAccuracy ?? 10.0,
              locationSource: record.locationSource ?? 'GPS',
              photoBytes: photoBytes,
            );
          } else if (record.isCheckedOut && record.checkOutTime != null) {
            synced = await apiService.checkOut(
              attendanceId: record.id,
              latitude: record.checkOutLat ?? record.checkInLat ?? 0.0,
              longitude: record.checkOutLng ?? record.checkInLng ?? 0.0,
              accuracy:
                  record.checkOutAccuracy ?? record.checkInAccuracy ?? 10.0,
              locationSource: record.locationSource ?? 'GPS',
              photoBytes: photoBytes,
            );
          } else {
            synced = await apiService.checkIn(
              latitude: record.checkInLat ?? 0.0,
              longitude: record.checkInLng ?? 0.0,
              accuracy: record.checkInAccuracy ?? 10.0,
              locationSource: record.locationSource ?? 'GPS',
              photoBytes: photoBytes,
            );
          }

          final updated = synced.copyWith(isSynced: true);
          await localFallback.storageService.saveRecord(updated);
          return 1;
        } catch (e) {
          if (kDebugMode) {
            print(
              '[ApiAttendanceRepository] Auto-sync error for attendance ${record.id}: $e',
            );
          }
          return 0;
        }
      }),
    );

    int totalSynced = 0;
    for (final res in results) {
      totalSynced += res;
    }
    return totalSynced;
  }
}

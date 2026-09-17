import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../features/auth/models/user_model.dart';
import '../features/auth/services/auth_storage_service.dart';
import '../models/app_notification.dart';
import '../models/attendance_model.dart';
import '../models/machine.dart';
import '../services/api/attendance_api_service.dart';
import '../services/attendance_storage_service.dart';
import '../services/notification_service.dart';
import 'machine_repository.dart';
import 'user_repository.dart';

abstract class AttendanceRepository {
  Future<AttendanceModel?> getTodayAttendance();
  Future<List<Machine>> getAssignedMachines(String userId);
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
  Future<List<AttendanceModel>> getPendingApprovals({
    int page = 0,
  });
  Future<bool> approveAttendance(String attendanceId);
  Future<bool> rejectAttendance(String attendanceId, String reason);
}

/// Local Persistent Repository for Local/Testing Mode
class LocalAttendanceRepository implements AttendanceRepository {
  final AttendanceStorageService storageService;
  final MachineRepository machineRepository;
  final UserRepository userRepository;

  LocalAttendanceRepository({
    AttendanceStorageService? storageService,
    MachineRepository? machineRepository,
    UserRepository? userRepository,
  })  : storageService = storageService ?? AttendanceStorageService(),
        machineRepository = machineRepository ?? MockMachineRepository(),
        userRepository = userRepository ?? ApiUserRepository();

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

    if (user != null && user.isAdmin) {
      return allMachines;
    }

    final query = (user?.displayName.isNotEmpty == true ? user!.displayName : user?.username ?? '').toLowerCase();
    final username = (user?.username ?? '').toLowerCase();
    final phone = (user?.phoneNumber ?? '').toLowerCase();
    final empId = (user?.employeeId ?? '').toLowerCase();

    final matched = allMachines.where((m) {
      final opName = (m.operatorInfo is Map ? m.operatorInfo['name']?.toString() : m.operatorInfo?.toString())?.toLowerCase() ?? '';
      final opMobile = (m.operatorInfo is Map ? m.operatorInfo['mobile']?.toString() : '')?.toLowerCase() ?? '';
      final vendorName = m.vendorName?.toLowerCase() ?? '';
      final chassis = m.machineChassisNo.toLowerCase();

      return opName.contains(query) ||
          opName.contains(username) ||
          (opMobile.isNotEmpty && phone.isNotEmpty && opMobile.contains(phone)) ||
          vendorName.contains(query) ||
          vendorName.contains(username) ||
          (empId.isNotEmpty && (chassis.contains(empId) || opName.contains(empId)));
    }).toList();

    if (matched.isNotEmpty) {
      return matched;
    }

    // Fallback: Return primary assigned machine for logged-in operator/vendor
    return [allMachines.first];
  }

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
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? '');
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
    final userName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? '');
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
      orElse: () => throw Exception('Attendance record not found for check-out'),
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
      formattedHours = '${hrs.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
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
        if (statusFilter == 'APPROVED' || statusFilter == 'PRESENT') return r.isApproved || r.status == 'PRESENT';
        if (statusFilter == 'PENDING') return r.isPendingApproval || r.status == 'PENDING';
        if (statusFilter == 'REJECTED') return r.isRejected || r.status == 'REJECTED';
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
      return records.where((r) => r.isPendingApproval || r.status == 'PENDING').toList();
    }

    return records.where((r) {
      final isPending = r.isPendingApproval || r.status == 'PENDING';
      final isAssignedManager = r.reportingManagerId == currentUserId ||
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

      // Self approval check: Manager cannot approve their own attendance!
      if (existing.userId == currentAdminId ||
          existing.userName.toLowerCase() == currentAdminUsername.toLowerCase() ||
          existing.userName.toLowerCase() == currentAdminName.toLowerCase()) {
        throw Exception('You cannot approve your own attendance.');
      }

      final managerName = currentAdminName.isNotEmpty ? currentAdminName : currentAdminUsername;

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

      // Trigger In-App Notification for Employee
      final dateStr = existing.checkInTime != null
          ? DateFormat('dd MMM yyyy').format(existing.checkInTime!)
          : 'Today';

      await NotificationService().addNotification(
        AppNotification(
          id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: existing.userId,
          type: 'ATTENDANCE_APPROVED',
          title: 'Attendance Approved',
          message: 'Your attendance for $dateStr has been approved by $managerName.',
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
      final managerName = currentAdminName.isNotEmpty ? currentAdminName : currentAdminUsername;

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

      // Trigger In-App Notification for Employee
      final dateStr = existing.checkInTime != null
          ? DateFormat('dd MMM yyyy').format(existing.checkInTime!)
          : 'Today';

      await NotificationService().addNotification(
        AppNotification(
          id: 'NOTIF_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: existing.userId,
          type: 'ATTENDANCE_REJECTED',
          title: 'Attendance Rejected',
          message: 'Your attendance for $dateStr has been rejected by $managerName. Reason: $cleanReason',
          reason: cleanReason,
          attendanceId: existing.id,
          createdAt: DateTime.now(),
        ),
      );

      return true;
    }
    return false;
  }
}

class ApiAttendanceRepository implements AttendanceRepository {
  final AttendanceApiService apiService;
  final LocalAttendanceRepository localFallback;

  ApiAttendanceRepository({
    AttendanceApiService? apiService,
    LocalAttendanceRepository? localFallback,
  })  : apiService = apiService ?? AttendanceApiService(),
        localFallback = localFallback ?? LocalAttendanceRepository();

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
      final list = await apiService.fetchMyAssignedMachines();
      if (list.isNotEmpty) return list;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getAssignedMachines error: $e');
      }
    }
    return await localFallback.getAssignedMachines(userId);
  }

  @override
  Future<List<UserModel>> getAuthorizedTeamMembers(String supervisorId) async {
    try {
      final list = await apiService.fetchAuthorizedTeamMembers();
      if (list.isNotEmpty) return list;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiAttendanceRepository] getAuthorizedTeamMembers error: $e');
      }
    }
    return await localFallback.getAuthorizedTeamMembers(supervisorId);
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
        assignmentId: machine.id.isNotEmpty ? machine.id : machine.machineChassisNo,
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
        print('[ApiAttendanceRepository] Remote checkInMachine failed ($e), saving locally...');
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
        print('[ApiAttendanceRepository] Remote checkInTeamMember failed ($e), saving locally...');
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
        print('[ApiAttendanceRepository] Remote checkIn failed ($e), saving locally...');
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
        print('[ApiAttendanceRepository] Remote checkOut failed ($e), saving locally...');
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
      final list = await apiService.fetchHistory(page: page, statusFilter: statusFilter);
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
    return await localFallback.getHistory(page: page, statusFilter: statusFilter);
  }

  @override
  Future<List<AttendanceModel>> getPendingApprovals({
    int page = 0,
  }) async {
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
}

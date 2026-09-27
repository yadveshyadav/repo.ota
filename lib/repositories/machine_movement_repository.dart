import 'package:flutter/foundation.dart';
import '../models/machine_movement.dart';
import '../services/api/api_client.dart';
import '../services/api/machine_movement_api_service.dart';

/// Abstract Machine Movement / Shift Request Repository interface
abstract class MachineMovementRepository {
  Future<List<MachineShiftReason>> getReasons();

  Future<List<MachineMovement>> getRequests({
    String? statusFilter,
    String? machineFilter,
    String? vendorFilter,
    int page = 1,
    int pageSize = 20,
  });

  Future<MachineMovement?> getRequestById(dynamic id);

  Future<MachineMovement> createRequest({
    required dynamic vendorId,
    required dynamic machineId,
    required dynamic reasonId,
    required String aPointName,
    double aPointLatitude = 0.0,
    double aPointLongitude = 0.0,
    required String bPointName,
    double bPointLatitude = 0.0,
    double bPointLongitude = 0.0,
    required String requiredDate,
    required String modeOfShifting,
    String? machineName,
    String? machineChassisNo,
    String? vendorName,
    String? reasonName,
  });

  Future<MachineMovement> startShifting(dynamic id);

  Future<MachineMovement> updateShiftingProgress({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    String? remarks,
  });

  Future<MachineMovement> markShifted({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    List<int>? photoBytes,
    String photoFilename = 'rig_photo.jpg',
    String? remarks,
  });

  Future<MachineMovement> cancelRequest(dynamic id, {required String remarks});

  Future<List<MovementAuditTrailItem>> getAuditTrail(dynamic id);
}

/// Production ApiMachineMovementRepository consuming MachineMovementApiService directly
class ApiMachineMovementRepository implements MachineMovementRepository {
  final MachineMovementApiService apiService;

  ApiMachineMovementRepository({ApiClient? apiClient, MachineMovementApiService? apiService})
      : apiService = apiService ?? MachineMovementApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<List<MachineShiftReason>> getReasons() async {
    final res = await apiService.fetchShiftReasons();
    if (res is Map<String, dynamic> && res['data'] is List) {
      return (res['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MachineShiftReason.fromJson(e))
          .toList();
    } else if (res is List) {
      return res
          .whereType<Map<String, dynamic>>()
          .map((e) => MachineShiftReason.fromJson(e))
          .toList();
    }
    return [];
  }

  @override
  Future<List<MachineMovement>> getRequests({
    String? statusFilter,
    String? machineFilter,
    String? vendorFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await apiService.fetchShiftRequests(
        statusFilter: statusFilter,
        machineFilter: machineFilter,
        vendorFilter: vendorFilter,
        page: page,
        pageSize: pageSize,
      );

      List<dynamic> list = [];
      if (res is Map<String, dynamic>) {
        if (res['results'] is List) {
          list = res['results'] as List;
        } else if (res['data'] is Map<String, dynamic> && res['data']['results'] is List) {
          list = res['data']['results'] as List;
        } else if (res['data'] is List) {
          list = res['data'] as List;
        }
      } else if (res is List) {
        list = res;
      }

      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map((e) => MachineMovement.fromJson(e))
          .toList();

      return parsed;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiMachineMovementRepository] Error fetching requests: $e');
      }
      return [];
    }
  }

  @override
  Future<MachineMovement?> getRequestById(dynamic id) async {
    final res = await apiService.fetchRequestDetail(id);
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    return null;
  }

  @override
  Future<MachineMovement> createRequest({
    required dynamic vendorId,
    required dynamic machineId,
    required dynamic reasonId,
    required String aPointName,
    double aPointLatitude = 0.0,
    double aPointLongitude = 0.0,
    required String bPointName,
    double bPointLatitude = 0.0,
    double bPointLongitude = 0.0,
    required String requiredDate,
    required String modeOfShifting,
    String? machineName,
    String? machineChassisNo,
    String? vendorName,
    String? reasonName,
  }) async {
    final mPk = int.tryParse(machineId.toString()) ?? machineId;
    final vPk = int.tryParse(vendorId.toString()) ?? vendorId;
    final rPk = int.tryParse(reasonId.toString()) ?? reasonId;

    final body = <String, dynamic>{
      'vendor': vPk,
      'machine': mPk,
      'reason': rPk,
      'a_point_name': aPointName,
      'a_point_latitude': aPointLatitude,
      'a_point_longitude': aPointLongitude,
      'b_point_name': bPointName,
      'b_point_latitude': bPointLatitude,
      'b_point_longitude': bPointLongitude,
      'required_date': requiredDate,
      'mode_of_shifting': modeOfShifting,
    };
    if (machineChassisNo != null && machineChassisNo.trim().isNotEmpty) {
      body['machine_chassis_no'] = machineChassisNo.trim();
    }

    final res = await apiService.createShiftRequest(body);
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    throw Exception('Failed to create shift request.');
  }

  @override
  Future<MachineMovement> startShifting(dynamic id) async {
    final res = await apiService.startShifting(id);
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    throw Exception('Failed to start shifting.');
  }

  @override
  Future<MachineMovement> updateShiftingProgress({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    String? remarks,
  }) async {
    final fields = {
      'shifting_date': shiftingDate,
      'shifting_mode': shiftingMode,
      'shifting_contact_person': shiftingContactPerson,
      'shifting_expense_amount': shiftingExpenseAmount,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    final res = await apiService.updateShiftingProgress(id, fields: fields);
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    throw Exception('Failed to update shifting progress.');
  }

  @override
  Future<MachineMovement> markShifted({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    List<int>? photoBytes,
    String photoFilename = 'rig_photo.jpg',
    String? remarks,
  }) async {
    final fields = {
      'shifting_date': shiftingDate,
      'shifting_mode': shiftingMode,
      'shifting_contact_person': shiftingContactPerson,
      'shifting_expense_amount': shiftingExpenseAmount,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    final res = await apiService.markShifted(
      id,
      fields: fields,
      photoBytes: photoBytes,
      photoFilename: photoFilename,
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    throw Exception('Failed to mark machine as shifted.');
  }

  @override
  Future<MachineMovement> cancelRequest(dynamic id, {required String remarks}) async {
    final res = await apiService.cancelShiftRequest(id, remarks: remarks);
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic> ? res['data'] as Map<String, dynamic> : res;
      return MachineMovement.fromJson(data);
    }
    throw Exception('Failed to cancel shift request.');
  }

  @override
  Future<List<MovementAuditTrailItem>> getAuditTrail(dynamic id) async {
    final res = await apiService.fetchAuditTrail(id);
    if (res is Map<String, dynamic> && res['data'] is List) {
      return (res['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MovementAuditTrailItem.fromJson(e))
          .toList();
    } else if (res is List) {
      return res
          .whereType<Map<String, dynamic>>()
          .map((e) => MovementAuditTrailItem.fromJson(e))
          .toList();
    }
    return [];
  }
}

/// In-Memory Seeded Repository matching official backend specification exactly
class MockMachineMovementRepository implements MachineMovementRepository {
  static final List<MachineShiftReason> _reasons = const [
    MachineShiftReason(
      id: 1,
      name: 'New Task',
      code: 'NEW_TASK',
      description: 'Shift required for new task execution',
      isActive: true,
    ),
    MachineShiftReason(
      id: 2,
      name: 'Project Completion',
      code: 'PROJECT_COMPLETED',
      description: 'Shift after completing active work segment',
      isActive: true,
    ),
    MachineShiftReason(
      id: 3,
      name: 'Maintenance & Service',
      code: 'MAINTENANCE',
      description: 'Shift to workshop for scheduled maintenance',
      isActive: true,
    ),
    MachineShiftReason(
      id: 4,
      name: 'Resource Optimization',
      code: 'RESOURCE_OPTIMIZATION',
      description: 'Shift to optimize fleet deployment across sites',
      isActive: true,
    ),
  ];

  static final List<MachineMovement> _requests = [
    MachineMovement(
      id: '5',
      requestId: 'MSR-20260925-0005',
      status: MovementStatus.approvedByScm,
      vendorId: 3,
      vendorName: 'Primelink Infratel Enterprise',
      vendorCode: 'VND',
      machineId: 8,
      machineName: 'Drill Rig Alpha',
      machineCode: 'MCH-001',
      machineChassisNo: '600202608397',
      reasonId: 1,
      reasonName: 'New Task',
      aPointName: 'Ring 3 Crossing, Jaipur',
      aPointLatitude: 26.9124,
      aPointLongitude: 75.7873,
      bPointName: 'Block C Feeder, Alwar',
      bPointLatitude: 27.5530,
      bPointLongitude: 76.6346,
      requiredDate: '2026-09-26',
      modeOfShifting: 'OWN_HDD',
      shiftingStatus: 'APPROVED_BY_SCM',
      auditTrail: [
        MovementAuditTrailItem(
          action: 'REQUEST_CREATED',
          performedByName: 'Site Supervisor',
          previousStatus: '',
          newStatus: 'PENDING_SHIFTING',
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        MovementAuditTrailItem(
          action: 'SCM_APPROVED',
          performedByName: 'SCM Officer',
          previousStatus: 'PENDING_SHIFTING',
          newStatus: 'APPROVED_BY_SCM',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    MachineMovement(
      id: '4',
      requestId: 'MSR-20260924-0004',
      status: MovementStatus.inProgress,
      vendorId: 3,
      vendorName: 'Gurukripa Enterprises',
      vendorCode: 'VND',
      machineId: 3,
      machineName: 'APOLLO A600 V2',
      machineCode: 'A600',
      machineChassisNo: '600202608396',
      reasonId: 2,
      reasonName: 'Project Completion',
      aPointName: 'Sujangarh Feeder, Churu',
      aPointLatitude: 27.7379,
      aPointLongitude: 74.6460,
      bPointName: 'Ratangarh Substation Yard',
      bPointLatitude: 28.0825,
      bPointLongitude: 74.6189,
      requiredDate: '2026-09-25',
      modeOfShifting: 'BY_TRUCK',
      shiftingStatus: 'IN_PROGRESS',
      shiftingDate: '2026-09-25',
      shiftingMode: 'BY_TRUCK',
      shiftingContactPerson: 'Ramesh Kumar (+91 9876543210)',
      shiftingExpenseAmount: '14500.00',
      remarks: 'Rig loaded on flatbed trailer RJ-14-GA-1029',
      auditTrail: [
        MovementAuditTrailItem(
          action: 'REQUEST_CREATED',
          performedByName: 'Mahaveer Gurjar',
          previousStatus: '',
          newStatus: 'PENDING_SHIFTING',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        ),
        MovementAuditTrailItem(
          action: 'SCM_APPROVED',
          performedByName: 'SCM Manager',
          previousStatus: 'PENDING_SHIFTING',
          newStatus: 'APPROVED_BY_SCM',
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        ),
        MovementAuditTrailItem(
          action: 'START_SHIFTING',
          performedByName: 'Ramesh Kumar',
          previousStatus: 'APPROVED_BY_SCM',
          newStatus: 'IN_PROGRESS',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
  ];

  @override
  Future<List<MachineShiftReason>> getReasons() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _reasons;
  }

  @override
  Future<List<MachineMovement>> getRequests({
    String? statusFilter,
    String? machineFilter,
    String? vendorFilter,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _requests.where((r) {
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        final filter = statusFilter.toUpperCase();
        if (r.status.apiValue != filter && r.status.displayName.toUpperCase() != filter) {
          if (filter == 'ACTIVE' && !r.status.isActive) return false;
          if (filter == 'COMPLETED' && !r.status.isCompleted) return false;
        }
      }
      if (machineFilter != null && machineFilter.isNotEmpty) {
        final q = machineFilter.toLowerCase();
        if (!r.machineChassisNo.toLowerCase().contains(q) && !r.machineName.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<MachineMovement?> getRequestById(dynamic id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final strId = id.toString();
      return _requests.firstWhere((r) => r.id == strId || r.requestId == strId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MachineMovement> createRequest({
    required dynamic vendorId,
    required dynamic machineId,
    required dynamic reasonId,
    required String aPointName,
    double aPointLatitude = 0.0,
    double aPointLongitude = 0.0,
    required String bPointName,
    double bPointLatitude = 0.0,
    double bPointLongitude = 0.0,
    required String requiredDate,
    required String modeOfShifting,
    String? machineName,
    String? machineChassisNo,
    String? vendorName,
    String? reasonName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final newId = '${_requests.length + 10}';
    final newReqId = 'MSR-20260927-00$newId';
    final now = DateTime.now();

    final newRequest = MachineMovement(
      id: newId,
      requestId: newReqId,
      status: MovementStatus.pendingShifting,
      vendorId: vendorId,
      vendorName: vendorName ?? 'Partner Vendor',
      machineId: machineId,
      machineName: machineName ?? 'HDD Drill Rig',
      machineChassisNo: machineChassisNo ?? '600202608396',
      reasonId: reasonId,
      reasonName: reasonName ?? 'New Task',
      aPointName: aPointName,
      aPointLatitude: aPointLatitude,
      aPointLongitude: aPointLongitude,
      bPointName: bPointName,
      bPointLatitude: bPointLatitude,
      bPointLongitude: bPointLongitude,
      requiredDate: requiredDate,
      modeOfShifting: modeOfShifting,
      shiftingStatus: 'PENDING_SHIFTING',
      auditTrail: [
        MovementAuditTrailItem(
          action: 'REQUEST_CREATED',
          performedByName: 'Site Engineer',
          previousStatus: '',
          newStatus: 'PENDING_SHIFTING',
          createdAt: now,
        ),
      ],
      createdAt: now,
    );

    _requests.insert(0, newRequest);
    return newRequest;
  }

  @override
  Future<MachineMovement> startShifting(dynamic id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _requests.indexWhere((r) => r.id == id.toString() || r.requestId == id.toString());
    if (index == -1) throw Exception('Shift request $id not found');

    final existing = _requests[index];
    final now = DateTime.now();
    final updatedTrail = List<MovementAuditTrailItem>.from(existing.auditTrail)
      ..add(MovementAuditTrailItem(
        action: 'START_SHIFTING',
        performedByName: 'Field Shifter',
        previousStatus: existing.status.apiValue,
        newStatus: 'IN_PROGRESS',
        createdAt: now,
      ));

    final updated = MachineMovement(
      id: existing.id,
      requestId: existing.requestId,
      status: MovementStatus.inProgress,
      vendorId: existing.vendorId,
      vendorName: existing.vendorName,
      vendorCode: existing.vendorCode,
      machineId: existing.machineId,
      machineName: existing.machineName,
      machineCode: existing.machineCode,
      machineChassisNo: existing.machineChassisNo,
      reasonId: existing.reasonId,
      reasonName: existing.reasonName,
      aPointName: existing.aPointName,
      aPointLatitude: existing.aPointLatitude,
      aPointLongitude: existing.aPointLongitude,
      bPointName: existing.bPointName,
      bPointLatitude: existing.bPointLatitude,
      bPointLongitude: existing.bPointLongitude,
      requiredDate: existing.requiredDate,
      modeOfShifting: existing.modeOfShifting,
      shiftingStatus: 'IN_PROGRESS',
      auditTrail: updatedTrail,
      createdAt: existing.createdAt,
    );

    _requests[index] = updated;
    return updated;
  }

  @override
  Future<MachineMovement> updateShiftingProgress({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    String? remarks,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _requests.indexWhere((r) => r.id == id.toString() || r.requestId == id.toString());
    if (index == -1) throw Exception('Shift request $id not found');

    final existing = _requests[index];

    final updated = MachineMovement(
      id: existing.id,
      requestId: existing.requestId,
      status: existing.status,
      vendorId: existing.vendorId,
      vendorName: existing.vendorName,
      vendorCode: existing.vendorCode,
      machineId: existing.machineId,
      machineName: existing.machineName,
      machineCode: existing.machineCode,
      machineChassisNo: existing.machineChassisNo,
      reasonId: existing.reasonId,
      reasonName: existing.reasonName,
      aPointName: existing.aPointName,
      aPointLatitude: existing.aPointLatitude,
      aPointLongitude: existing.aPointLongitude,
      bPointName: existing.bPointName,
      bPointLatitude: existing.bPointLatitude,
      bPointLongitude: existing.bPointLongitude,
      requiredDate: existing.requiredDate,
      modeOfShifting: existing.modeOfShifting,
      shiftingStatus: existing.shiftingStatus,
      shiftingDate: shiftingDate,
      shiftingMode: shiftingMode,
      shiftingContactPerson: shiftingContactPerson,
      shiftingExpenseAmount: shiftingExpenseAmount,
      machinePictureUrl: existing.machinePictureUrl,
      remarks: remarks ?? existing.remarks,
      auditTrail: existing.auditTrail,
      createdAt: existing.createdAt,
    );

    _requests[index] = updated;
    return updated;
  }

  @override
  Future<MachineMovement> markShifted({
    required dynamic id,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    List<int>? photoBytes,
    String photoFilename = 'rig_photo.jpg',
    String? remarks,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _requests.indexWhere((r) => r.id == id.toString() || r.requestId == id.toString());
    if (index == -1) throw Exception('Shift request $id not found');

    final existing = _requests[index];
    final now = DateTime.now();
    final updatedTrail = List<MovementAuditTrailItem>.from(existing.auditTrail)
      ..add(MovementAuditTrailItem(
        action: 'MARKED_SHIFTED',
        performedByName: shiftingContactPerson.isNotEmpty ? shiftingContactPerson : 'Field Shifter',
        previousStatus: existing.status.apiValue,
        newStatus: 'SHIFTED',
        createdAt: now,
      ));

    final updated = MachineMovement(
      id: existing.id,
      requestId: existing.requestId,
      status: MovementStatus.shifted,
      vendorId: existing.vendorId,
      vendorName: existing.vendorName,
      vendorCode: existing.vendorCode,
      machineId: existing.machineId,
      machineName: existing.machineName,
      machineCode: existing.machineCode,
      machineChassisNo: existing.machineChassisNo,
      reasonId: existing.reasonId,
      reasonName: existing.reasonName,
      aPointName: existing.aPointName,
      aPointLatitude: existing.aPointLatitude,
      aPointLongitude: existing.aPointLongitude,
      bPointName: existing.bPointName,
      bPointLatitude: existing.bPointLatitude,
      bPointLongitude: existing.bPointLongitude,
      requiredDate: existing.requiredDate,
      modeOfShifting: existing.modeOfShifting,
      shiftingStatus: 'SHIFTED',
      shiftingDate: shiftingDate,
      shiftingMode: shiftingMode,
      shiftingContactPerson: shiftingContactPerson,
      shiftingExpenseAmount: shiftingExpenseAmount,
      machinePictureUrl: photoBytes != null && photoBytes.isNotEmpty
          ? 'https://hero.pramaanu.co.in/media/machine_shift/pictures/rig_photo_$id.jpg'
          : 'https://hero.pramaanu.co.in/media/machine_shift/pictures/rig_photo_sample.jpg',
      remarks: remarks ?? existing.remarks,
      auditTrail: updatedTrail,
      createdAt: existing.createdAt,
    );

    _requests[index] = updated;
    return updated;
  }

  @override
  Future<MachineMovement> cancelRequest(dynamic id, {required String remarks}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _requests.indexWhere((r) => r.id == id.toString() || r.requestId == id.toString());
    if (index == -1) throw Exception('Shift request $id not found');

    final existing = _requests[index];
    final now = DateTime.now();
    final updatedTrail = List<MovementAuditTrailItem>.from(existing.auditTrail)
      ..add(MovementAuditTrailItem(
        action: 'REQUEST_CANCELLED',
        performedByName: 'User',
        previousStatus: existing.status.apiValue,
        newStatus: 'CANCELLED',
        createdAt: now,
      ));

    final updated = MachineMovement(
      id: existing.id,
      requestId: existing.requestId,
      status: MovementStatus.cancelled,
      vendorId: existing.vendorId,
      vendorName: existing.vendorName,
      vendorCode: existing.vendorCode,
      machineId: existing.machineId,
      machineName: existing.machineName,
      machineCode: existing.machineCode,
      machineChassisNo: existing.machineChassisNo,
      reasonId: existing.reasonId,
      reasonName: existing.reasonName,
      aPointName: existing.aPointName,
      aPointLatitude: existing.aPointLatitude,
      aPointLongitude: existing.aPointLongitude,
      bPointName: existing.bPointName,
      bPointLatitude: existing.bPointLatitude,
      bPointLongitude: existing.bPointLongitude,
      requiredDate: existing.requiredDate,
      modeOfShifting: existing.modeOfShifting,
      shiftingStatus: 'CANCELLED',
      remarks: remarks,
      auditTrail: updatedTrail,
      createdAt: existing.createdAt,
    );

    _requests[index] = updated;
    return updated;
  }

  @override
  Future<List<MovementAuditTrailItem>> getAuditTrail(dynamic id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final req = await getRequestById(id);
    return req?.auditTrail ?? [];
  }
}

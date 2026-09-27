/// Official Backend Lifecycle Status Enum for Machine Shift Requests
enum MovementStatus {
  pendingShifting,
  approvedByScm,
  inProgress,
  shifted,
  confirmed,
  cancelled;

  String get apiValue {
    switch (this) {
      case MovementStatus.pendingShifting:
        return 'PENDING_SHIFTING';
      case MovementStatus.approvedByScm:
        return 'APPROVED_BY_SCM';
      case MovementStatus.inProgress:
        return 'IN_PROGRESS';
      case MovementStatus.shifted:
        return 'SHIFTED';
      case MovementStatus.confirmed:
        return 'CONFIRMED';
      case MovementStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get displayName {
    switch (this) {
      case MovementStatus.pendingShifting:
        return 'Pending SCM Approval';
      case MovementStatus.approvedByScm:
        return 'Approved by SCM';
      case MovementStatus.inProgress:
        return 'In Progress';
      case MovementStatus.shifted:
        return 'Shifted';
      case MovementStatus.confirmed:
        return 'Confirmed';
      case MovementStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive =>
      this == MovementStatus.pendingShifting ||
      this == MovementStatus.approvedByScm ||
      this == MovementStatus.inProgress;

  bool get isInProgress => this == MovementStatus.inProgress;
  bool get isCompleted => this == MovementStatus.shifted || this == MovementStatus.confirmed;
  bool get isLocked => this == MovementStatus.confirmed;
  bool get isTerminal => isCompleted || this == MovementStatus.cancelled;

  static MovementStatus fromString(String val) {
    final clean = val.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (clean) {
      case 'PENDING_SHIFTING':
      case 'PENDING_SCM':
      case 'PENDING':
      case 'PENDING_APPROVAL':
        return MovementStatus.pendingShifting;
      case 'APPROVED_BY_SCM':
      case 'APPROVED':
        return MovementStatus.approvedByScm;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
      case 'DISPATCHED':
      case 'IN_TRANSIT':
        return MovementStatus.inProgress;
      case 'SHIFTED':
      case 'ACCEPTED':
        return MovementStatus.shifted;
      case 'CONFIRMED':
      case 'COMPLETED':
        return MovementStatus.confirmed;
      case 'CANCELLED':
      case 'CANCELED':
      case 'REJECTED':
        return MovementStatus.cancelled;
      default:
        return MovementStatus.pendingShifting;
    }
  }
}

/// DTO for Dynamic Reason Master Dropdown (GET /api/v1/machine-shift/machine-shift-reasons/)
class MachineShiftReason {
  final int id;
  final String name;
  final String code;
  final String description;
  final bool isActive;

  const MachineShiftReason({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.isActive = true,
  });

  factory MachineShiftReason.fromJson(Map<String, dynamic> json) {
    return MachineShiftReason(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '1') ?? 1,
      name: json['name']?.toString() ?? json['code']?.toString() ?? 'General Reason',
      code: json['code']?.toString() ?? 'REASON',
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'is_active': isActive,
      };
}

/// DTO for Shift Request Audit Trail (GET /api/v1/machine-shift/machine-shift-requests/{id}/audit-trail/)
class MovementAuditTrailItem {
  final String action;
  final String performedByName;
  final String previousStatus;
  final String newStatus;
  final DateTime createdAt;

  const MovementAuditTrailItem({
    required this.action,
    required this.performedByName,
    required this.previousStatus,
    required this.newStatus,
    required this.createdAt,
  });

  factory MovementAuditTrailItem.fromJson(Map<String, dynamic> json) {
    final rawTime = json['created_at'] ?? json['timestamp'];
    DateTime dt = DateTime.now();
    if (rawTime != null) {
      dt = DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
    }

    return MovementAuditTrailItem(
      action: json['action']?.toString() ?? 'STATUS_CHANGE',
      performedByName: json['performed_by_name']?.toString() ?? json['user_name']?.toString() ?? json['performed_by']?.toString() ?? 'User',
      previousStatus: json['previous_status']?.toString() ?? '',
      newStatus: json['new_status']?.toString() ?? '',
      createdAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'performed_by_name': performedByName,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Core Domain Entity: MachineMovement (Machine Shift Request)
class MachineMovement {
  final String id;
  final String requestId; // MSR-20260925-0005
  final MovementStatus status;

  final dynamic vendorId;
  final String vendorName;
  final String vendorCode;

  final dynamic machineId;
  final String machineName;
  final String machineCode;
  final String machineChassisNo;

  final dynamic reasonId;
  final String reasonName;

  final String aPointName;
  final double aPointLatitude;
  final double aPointLongitude;

  final String bPointName;
  final double bPointLatitude;
  final double bPointLongitude;

  final String requiredDate; // YYYY-MM-DD
  final String modeOfShifting; // OWN_HDD or BY_TRUCK
  final String shiftingStatus;

  final String? shiftingDate;
  final String? shiftingMode;
  final String? shiftingContactPerson;
  final String? shiftingExpenseAmount;
  final String? machinePictureUrl;
  final String? remarks;

  final List<MovementAuditTrailItem> auditTrail;
  final DateTime createdAt;

  const MachineMovement({
    required this.id,
    required this.requestId,
    required this.status,
    this.vendorId,
    required this.vendorName,
    this.vendorCode = 'VND',
    this.machineId,
    required this.machineName,
    this.machineCode = 'MCH',
    required this.machineChassisNo,
    this.reasonId,
    required this.reasonName,
    required this.aPointName,
    this.aPointLatitude = 0.0,
    this.aPointLongitude = 0.0,
    required this.bPointName,
    this.bPointLatitude = 0.0,
    this.bPointLongitude = 0.0,
    required this.requiredDate,
    this.modeOfShifting = 'OWN_HDD',
    this.shiftingStatus = 'PENDING',
    this.shiftingDate,
    this.shiftingMode,
    this.shiftingContactPerson,
    this.shiftingExpenseAmount,
    this.machinePictureUrl,
    this.remarks,
    this.auditTrail = const [],
    required this.createdAt,
  });

  bool get isInProgress => status == MovementStatus.inProgress;
  bool get isApprovedByScm => status == MovementStatus.approvedByScm;
  bool get isPendingShifting => status == MovementStatus.pendingShifting;
  bool get isShifted => status == MovementStatus.shifted;
  bool get isConfirmed => status == MovementStatus.confirmed;
  bool get isCancelled => status == MovementStatus.cancelled;

  String get transferNumber => requestId.isNotEmpty ? requestId : 'MSR-$id';
  String get statusDisplay => status.displayName;

  factory MachineMovement.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString().trim()) ?? 0.0;
    }

    final vendorMap = json['vendor'] is Map<String, dynamic> ? json['vendor'] as Map<String, dynamic> : null;
    final machineMap = json['machine'] is Map<String, dynamic> ? json['machine'] as Map<String, dynamic> : null;
    final reasonMap = json['reason'] is Map<String, dynamic> ? json['reason'] as Map<String, dynamic> : null;

    final rawHistory = json['audit_logs'] as List<dynamic>? ??
        json['audit_trail'] as List<dynamic>? ??
        json['auditTrail'] as List<dynamic>?;

    final parsedHistory = rawHistory != null
        ? rawHistory.map((e) => MovementAuditTrailItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <MovementAuditTrailItem>[];

    final rawId = json['id']?.toString() ?? '0';
    final reqId = json['request_id']?.toString() ?? json['requestId']?.toString() ?? json['code']?.toString() ?? 'MSR-$rawId';

    final vName = vendorMap?['name']?.toString() ??
        vendorMap?['vendor_name']?.toString() ??
        json['vendor_name']?.toString() ??
        json['vendor_display']?.toString() ??
        (json['vendor'] is String ? json['vendor'] as String : 'Partner Vendor');

    final mName = machineMap?['name']?.toString() ??
        machineMap?['machine_name']?.toString() ??
        json['machine_name']?.toString() ??
        json['machine_display']?.toString() ??
        (json['machine'] is String ? json['machine'] as String : 'HDD Rig');

    final mCode = machineMap?['code']?.toString() ??
        json['machine_code']?.toString() ??
        'MAC';

    final mChassis = machineMap?['machine_chassis_no']?.toString() ??
        machineMap?['chassis_no']?.toString() ??
        machineMap?['chassis_number']?.toString() ??
        json['machine_chassis_no']?.toString() ??
        json['chassis_no']?.toString() ??
        json['chassis_number']?.toString() ??
        '';

    final aPoint = json['a_point_name']?.toString() ??
        json['aPointName']?.toString() ??
        json['origin']?.toString() ??
        json['origin_name']?.toString() ??
        json['source']?.toString() ??
        'Origin Point A';

    final bPoint = json['b_point_name']?.toString() ??
        json['bPointName']?.toString() ??
        json['destination']?.toString() ??
        json['destination_name']?.toString() ??
        json['target']?.toString() ??
        'Destination Point B';

    final rName = reasonMap?['name']?.toString() ??
        reasonMap?['reason_name']?.toString() ??
        json['reason_name']?.toString() ??
        json['reason_display']?.toString() ??
        (json['reason'] is String ? json['reason'] as String : 'General Task');

    return MachineMovement(
      id: rawId,
      requestId: reqId,
      status: MovementStatus.fromString(json['status']?.toString() ?? 'PENDING_SHIFTING'),
      vendorId: vendorMap?['id'] ?? json['vendor'] ?? json['vendor_id'],
      vendorName: vName,
      vendorCode: vendorMap?['code']?.toString() ?? json['vendor_code']?.toString() ?? 'VND',
      machineId: machineMap?['id'] ?? json['machine'] ?? json['machine_id'],
      machineName: mName,
      machineCode: mCode,
      machineChassisNo: mChassis,
      reasonId: reasonMap?['id'] ?? json['reason'],
      reasonName: rName,
      aPointName: aPoint,
      aPointLatitude: parseDouble(json['a_point_latitude'] ?? json['aPointLatitude']),
      aPointLongitude: parseDouble(json['a_point_longitude'] ?? json['aPointLongitude']),
      bPointName: bPoint,
      bPointLatitude: parseDouble(json['b_point_latitude'] ?? json['bPointLatitude']),
      bPointLongitude: parseDouble(json['b_point_longitude'] ?? json['bPointLongitude']),
      requiredDate: json['required_date']?.toString() ?? json['requiredDate']?.toString() ?? '2026-09-29',
      modeOfShifting: json['mode_of_shifting']?.toString() ?? json['modeOfShifting']?.toString() ?? json['mode']?.toString() ?? 'OWN_HDD',
      shiftingStatus: json['shifting_status']?.toString() ?? json['shiftingStatus']?.toString() ?? json['status']?.toString() ?? 'PENDING',
      shiftingDate: json['shifting_date']?.toString() ?? json['shiftingDate']?.toString(),
      shiftingMode: json['shifting_mode']?.toString() ?? json['shiftingMode']?.toString(),
      shiftingContactPerson: json['shifting_contact_person']?.toString() ?? json['shiftingContactPerson']?.toString(),
      shiftingExpenseAmount: json['shifting_expense_amount']?.toString() ?? json['shiftingExpenseAmount']?.toString(),
      machinePictureUrl: json['machine_picture']?.toString() ?? json['machinePicture']?.toString() ?? json['machine_picture_url']?.toString(),
      remarks: json['remarks']?.toString(),
      auditTrail: parsedHistory,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'status': status.apiValue,
        'vendor': vendorId,
        'vendor_name': vendorName,
        'machine': machineId,
        'machine_name': machineName,
        'machine_chassis_no': machineChassisNo,
        'reason': reasonId,
        'reason_name': reasonName,
        'a_point_name': aPointName,
        'a_point_latitude': aPointLatitude,
        'a_point_longitude': aPointLongitude,
        'b_point_name': bPointName,
        'b_point_latitude': bPointLatitude,
        'b_point_longitude': bPointLongitude,
        'required_date': requiredDate,
        'mode_of_shifting': modeOfShifting,
        'shifting_status': shiftingStatus,
        if (shiftingDate != null) 'shifting_date': shiftingDate,
        if (shiftingMode != null) 'shifting_mode': shiftingMode,
        if (shiftingContactPerson != null) 'shifting_contact_person': shiftingContactPerson,
        if (shiftingExpenseAmount != null) 'shifting_expense_amount': shiftingExpenseAmount,
        if (machinePictureUrl != null) 'machine_picture': machinePictureUrl,
        if (remarks != null) 'remarks': remarks,
        'audit_trail': auditTrail.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

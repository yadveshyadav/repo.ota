import '../core/utils/date_parser_utils.dart';
import 'task_execution_model.dart';
import 'task_master_snapshots.dart';

/// Data model representing a Task Segment entity
class TaskSegmentModel {
  final String segmentCode;
  final String startNode;
  final String targetNode;
  final double distanceKm;
  final double? startLat;
  final double? startLng;
  final double? targetLat;
  final double? targetLng;

  const TaskSegmentModel({
    required this.segmentCode,
    required this.startNode,
    required this.targetNode,
    required this.distanceKm,
    this.startLat,
    this.startLng,
    this.targetLat,
    this.targetLng,
  });

  factory TaskSegmentModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskSegmentModel(
        segmentCode: 'SEG-01',
        startNode: 'Start Node',
        targetNode: 'Target Node',
        distanceKm: 0.0,
      );
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return TaskSegmentModel(
      segmentCode: (json['segmentCode'] ?? json['code'] ?? json['segment_code'] ?? 'SEG-01').toString(),
      startNode: (json['startNode'] ?? json['start_node'] ?? 'Start Node').toString(),
      targetNode: (json['targetNode'] ?? json['target_node'] ?? 'Target Node').toString(),
      distanceKm: parseCoord(json['distanceKm'] ?? json['distance_km'] ?? json['distance']) ?? 0.0,
      startLat: parseCoord(json['startLat'] ?? json['start_lat']),
      startLng: parseCoord(json['startLng'] ?? json['start_lng']),
      targetLat: parseCoord(json['targetLat'] ?? json['target_lat']),
      targetLng: parseCoord(json['targetLng'] ?? json['target_lng']),
    );
  }

  Map<String, dynamic> toJson() => {
        'segmentCode': segmentCode,
        'startNode': startNode,
        'targetNode': targetNode,
        'distanceKm': distanceKm,
        if (startLat != null) 'startLat': startLat,
        if (startLng != null) 'startLng': startLng,
        if (targetLat != null) 'targetLat': targetLat,
        if (targetLng != null) 'targetLng': targetLng,
      };
}

/// Data model representing a Route in the Task Hierarchy
class TaskRouteModel {
  final String routeCode;
  final String routeName;
  final double distanceKm;
  final int segmentsCount;
  final String startNode;
  final String targetNode;
  final List<TaskSegmentModel> segments;
  final List<List<double>>? polylineCoordinates;

  const TaskRouteModel({
    required this.routeCode,
    required this.routeName,
    required this.distanceKm,
    required this.segmentsCount,
    required this.startNode,
    required this.targetNode,
    this.segments = const [],
    this.polylineCoordinates,
  });

  factory TaskRouteModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskRouteModel(
        routeCode: 'R01',
        routeName: 'Route 01',
        distanceKm: 0.0,
        segmentsCount: 0,
        startNode: 'Start Node',
        targetNode: 'Target Node',
      );
    }

    final segList = (json['segments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((s) => TaskSegmentModel.fromJson(s))
            .toList() ??
        const [];

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    List<List<double>>? coords;
    if (json['polylineCoordinates'] is List) {
      coords = (json['polylineCoordinates'] as List)
          .whereType<List>()
          .map((item) => item.map((e) => (e is num) ? e.toDouble() : 0.0).toList())
          .toList();
    }

    return TaskRouteModel(
      routeCode: (json['routeCode'] ?? json['code'] ?? json['route_code'] ?? 'R01').toString(),
      routeName: (json['routeName'] ?? json['name'] ?? json['route_name'] ?? 'Route 01').toString(),
      distanceKm: parseNum(json['distanceKm'] ?? json['distance_km'] ?? json['distance']) ?? 0.0,
      segmentsCount: (json['segmentsCount'] ?? json['segments_count'] ?? segList.length) is int
          ? (json['segmentsCount'] ?? json['segments_count'] ?? segList.length)
          : int.tryParse('${json['segmentsCount'] ?? json['segments_count'] ?? segList.length}') ?? segList.length,
      startNode: (json['startNode'] ?? json['start_node'] ?? 'Start Node').toString(),
      targetNode: (json['targetNode'] ?? json['target_node'] ?? 'Target Node').toString(),
      segments: segList,
      polylineCoordinates: coords,
    );
  }

  Map<String, dynamic> toJson() => {
        'routeCode': routeCode,
        'routeName': routeName,
        'distanceKm': distanceKm,
        'segmentsCount': segmentsCount,
        'startNode': startNode,
        'targetNode': targetNode,
        'segments': segments.map((s) => s.toJson()).toList(),
        if (polylineCoordinates != null) 'polylineCoordinates': polylineCoordinates,
      };
}

/// Data model for Network & Telemetry Attributes
class TaskTelemetryModel {
  final String oltIp;
  final String baCmp;
  final String companyPhase;

  const TaskTelemetryModel({
    required this.oltIp,
    required this.baCmp,
    required this.companyPhase,
  });

  factory TaskTelemetryModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskTelemetryModel(
        oltIp: '10.0.183.2',
        baCmp: 'BA-CMP-01',
        companyPhase: 'HERO Infra Phase 2',
      );
    }
    return TaskTelemetryModel(
      oltIp: (json['oltIp'] ?? json['olt_ip'] ?? json['ip'] ?? '10.0.183.2').toString(),
      baCmp: (json['baCmp'] ?? json['ba_cmp'] ?? json['ba'] ?? 'BA-CMP-01').toString(),
      companyPhase:
          (json['companyPhase'] ?? json['company_phase'] ?? json['phase'] ?? 'HERO Infra Phase 2').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'oltIp': oltIp,
        'baCmp': baCmp,
        'companyPhase': companyPhase,
      };
}

/// Data model for Pit & Telemetry item
class TaskPitModel {
  final String pitId;
  final String pitName;
  final String pitType;
  final double? latitude;
  final double? longitude;

  const TaskPitModel({
    required this.pitId,
    required this.pitName,
    required this.pitType,
    this.latitude,
    this.longitude,
  });

  factory TaskPitModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskPitModel(pitId: '', pitName: 'Pit', pitType: 'Standard');
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return TaskPitModel(
      pitId: (json['pitId'] ?? json['id'] ?? '').toString(),
      pitName: (json['pitName'] ?? json['name'] ?? 'Pit').toString(),
      pitType: (json['pitType'] ?? json['type'] ?? 'Standard').toString(),
      latitude: parseCoord(json['latitude'] ?? json['lat']),
      longitude: parseCoord(json['longitude'] ?? json['lng']),
    );
  }

  Map<String, dynamic> toJson() => {
        'pitId': pitId,
        'pitName': pitName,
        'pitType': pitType,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Primary strongly typed Task Master Model driven by API response
class TaskModel {
  final String id;
  final String taskCode;
  final String displayName;
  final String taskType;
  final String taskLevel;
  final String status;
  final String taskStage;
  final String approvalStatus;

  // Master Data & Ancestry
  final String? parentTaskId;
  final List<String> ancestors;
  final int depth;
  final String? rootTaskId;
  final String? vendorId;

  // Location & Snapshots
  final String locationCode;
  final RouteSnapshotModel? routeSnapshot;
  final LocationSnapshotModel? locationSnapshot;
  final AssigneeSnapshotModel? assigneeSnapshot;
  final List<ApproverSnapshotModel> approverSnapshots;
  final List<String> approverRoles;
  final AssigneeSnapshotModel? createdBySnapshot;

  // Embedded Execution Reference (Optional in Master)
  final TaskExecutionModel? taskExecution;

  // Approval Chain State
  final int currentApprovalStepIndex;
  final String? rejectionReason;
  final String? description;
  final String? remarks;

  // Quantities & Lengths
  final List<TaskSegmentModel> segmentSnapshots;
  final double totalLengthKm;
  final List<String> referenceTaskIds;
  final double coveredLengthKm;
  final double? dailyTaskTarget;
  final int? expectedCompletionDays;
  final DateTime? dueDate;
  final bool active;

  // Dates & Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? completedAt;

  // Additional Metadata
  final Map<String, dynamic>? meta;

  // Backward compatibility fields
  final String legacyVendorName;
  final String legacyPartnerName;
  final String legacySupervisorName;
  final String legacyAssigneeName;
  final String legacyDesignation;
  final String legacyMobile;
  final String legacyProjectManagerName;
  final String legacyCreatorName;
  final double legacyPlannedScope;
  final double legacyRemainingScope;
  final double legacyCompletedScope;
  final double legacyProgress;
  final List<TaskRouteModel> legacyRoutes;
  final int legacyPitsCount;
  final List<TaskPitModel> legacyPits;
  final TaskTelemetryModel legacyTelemetry;
  final double? legacyLatitude;
  final double? legacyLongitude;
  final String? legacyExecutionStatus;
  final Map<String, dynamic>? legacyRuntimeData;
  final List<dynamic>? legacyTrenchingLogs;
  final List<dynamic>? legacyHddLogs;
  final List<dynamic>? legacyDepthPhotos;

  const TaskModel({
    required this.id,
    required this.taskCode,
    required this.displayName,
    required this.taskType,
    this.taskLevel = 'BLOCK',
    required this.status,
    this.taskStage = 'PLANNING',
    required this.approvalStatus,
    this.parentTaskId,
    this.ancestors = const [],
    this.depth = 0,
    this.rootTaskId,
    this.vendorId,
    this.locationCode = 'N/A',
    this.routeSnapshot,
    this.locationSnapshot,
    this.assigneeSnapshot,
    this.approverSnapshots = const [],
    this.approverRoles = const [],
    this.createdBySnapshot,
    this.taskExecution,
    this.currentApprovalStepIndex = 0,
    this.rejectionReason,
    this.description,
    this.remarks,
    this.segmentSnapshots = const [],
    this.totalLengthKm = 0.0,
    this.referenceTaskIds = const [],
    this.coveredLengthKm = 0.0,
    this.dailyTaskTarget,
    this.expectedCompletionDays,
    this.dueDate,
    this.active = true,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.completedAt,
    this.meta,
    this.legacyVendorName = 'Unassigned Vendor',
    this.legacyPartnerName = 'N/A',
    this.legacySupervisorName = 'Unassigned Supervisor',
    this.legacyAssigneeName = 'Unassigned',
    this.legacyDesignation = 'Field-Supervisor',
    this.legacyMobile = 'N/A',
    this.legacyProjectManagerName = 'N/A',
    this.legacyCreatorName = 'System',
    this.legacyPlannedScope = 0.0,
    this.legacyRemainingScope = 0.0,
    this.legacyCompletedScope = 0.0,
    this.legacyProgress = 0.0,
    this.legacyRoutes = const [],
    this.legacyPitsCount = 0,
    this.legacyPits = const [],
    this.legacyTelemetry = const TaskTelemetryModel(
      oltIp: '10.0.183.2',
      baCmp: 'BA-CMP-01',
      companyPhase: 'HERO Infra Phase 2',
    ),
    this.legacyLatitude,
    this.legacyLongitude,
    this.legacyExecutionStatus,
    this.legacyRuntimeData,
    this.legacyTrenchingLogs,
    this.legacyHddLogs,
    this.legacyDepthPhotos,
  });

  // Derived Convenience Getters for presentation compatibility
  String get stage => taskStage;
  String get vendorName => legacyVendorName.isNotEmpty ? legacyVendorName : 'Unassigned Vendor';
  String get partnerName => legacyPartnerName;
  String get supervisorName => legacySupervisorName.isNotEmpty ? legacySupervisorName : 'Unassigned Supervisor';
  String get assigneeName => assigneeSnapshot?.name ?? legacyAssigneeName;
  String get designation => assigneeSnapshot?.designation ?? legacyDesignation;
  String get mobile => assigneeSnapshot?.mobile ?? legacyMobile;
  String get projectManagerName => legacyProjectManagerName;
  String get approverName => approverSnapshots.isNotEmpty ? approverSnapshots.first.name : legacySupervisorName;
  String get creatorName => createdBySnapshot?.name ?? legacyCreatorName;

  String get locationName => locationSnapshot?.name ?? 'Location';
  String get district => locationSnapshot?.district ?? 'N/A';
  String get circle => locationSnapshot?.circle ?? 'N/A';
  String get blockName => locationSnapshot?.blockName ?? 'N/A';
  String get state => locationSnapshot?.state ?? 'RAJASTHAN';

  double get plannedScope => totalLengthKm > 0 ? totalLengthKm : legacyPlannedScope;
  double get completedScope => coveredLengthKm > 0 ? coveredLengthKm : legacyCompletedScope;
  double get remainingScope => (plannedScope - completedScope).clamp(0.0, double.infinity);
  double get progress => plannedScope > 0 ? ((completedScope / plannedScope) * 100.0).clamp(0.0, 100.0) : legacyProgress;

  double? get calculatedTotalLength {
    if (totalLengthKm > 0) return totalLengthKm;
    if (routeSnapshot != null && routeSnapshot!.distanceKm > 0) return routeSnapshot!.distanceKm;
    if (legacyPlannedScope > 0) return legacyPlannedScope;
    return null;
  }

  double? get calculatedProgress {
    final tot = calculatedTotalLength;
    if (tot != null && tot > 0) {
      return ((completedScope / tot) * 100.0).clamp(0.0, 100.0);
    }
    return null;
  }

  List<TaskRouteModel> get routes => legacyRoutes;
  int get pitsCount => legacyPitsCount;
  List<TaskPitModel> get pits => legacyPits;
  TaskTelemetryModel get telemetry => legacyTelemetry;
  double? get latitude => locationSnapshot?.latitude ?? legacyLatitude;
  double? get longitude => locationSnapshot?.longitude ?? legacyLongitude;

  String? get executionStatus => legacyExecutionStatus;
  Map<String, dynamic>? get runtimeData => legacyRuntimeData;
  List<dynamic>? get trenchingLogs => legacyTrenchingLogs;
  List<dynamic>? get hddLogs => legacyHddLogs;
  List<dynamic>? get depthPhotos => legacyDepthPhotos;

  bool get isApproved => approvalStatus.toUpperCase() == 'APPROVED' || status.toUpperCase() == 'COMPLETED';

  bool get isEligibleForCompletion =>
      status.toUpperCase() != 'COMPLETED' &&
      status.toUpperCase() != 'CANCELLED' &&
      status.toUpperCase() != 'REJECTED';

  factory TaskModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskModel(
        id: '',
        taskCode: 'TASK-00000',
        displayName: 'Task',
        taskType: 'FIBER_TRENCHING_DUCTING_TASK',
        status: 'CREATED',
        approvalStatus: 'PENDING',
        locationCode: 'N/A',
      );
    }

    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    String parseNonEmptyString(dynamic val, [String fallback = '']) {
      if (val == null) return fallback;
      final str = val.toString().trim();
      return str.isNotEmpty ? str : fallback;
    }

    final rawId = parseNonEmptyString(source['id'] ?? source['taskId'] ?? source['task_id'] ?? source['_id'], '');
    final code = parseNonEmptyString(source['taskCode'] ?? source['code'] ?? source['task_code'] ?? source['taskNo'] ?? source['task_no'], 'TASK-2026-00000');
    final name = parseNonEmptyString(source['displayName'] ?? source['name'] ?? source['taskName'] ?? source['title'] ?? source['task_name'], code != 'TASK-2026-00000' && code.isNotEmpty ? code : 'Unnamed Task');
    final type = parseNonEmptyString(source['taskType'] ?? source['type'] ?? source['task_type'] ?? source['category'], 'FIBER_TRENCHING_DUCTING_TASK');
    final level = parseNonEmptyString(source['taskLevel'] ?? source['level'] ?? source['task_level'], 'BLOCK');
    final rawStatus = parseNonEmptyString(source['status'] ?? source['taskStatus'] ?? source['task_status'] ?? source['state'], 'CREATED');
    final rawStage = parseNonEmptyString(source['taskStage'] ?? source['stage'] ?? source['task_stage'], 'PLANNING');
    final rawApproval = parseNonEmptyString(source['approvalStatus'] ?? source['approval_status'] ?? source['approvalState'], 'PENDING');
    final locCode = parseNonEmptyString(source['locationCode'] ?? source['location_code'] ?? source['locCode'], 'N/A');

    // Ancestors
    final ancList = (source['ancestors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    final depthVal = (source['depth'] as int?) ?? int.tryParse('${source['depth'] ?? 0}') ?? 0;

    // Snapshots
    RouteSnapshotModel? routeSnap;
    if (source['routeSnapshot'] != null) {
      routeSnap = RouteSnapshotModel.fromJson(source['routeSnapshot']);
    }

    LocationSnapshotModel? locSnap;
    if (source['locationSnapshot'] != null) {
      locSnap = LocationSnapshotModel.fromJson(source['locationSnapshot']);
    } else if (source['location'] != null) {
      locSnap = LocationSnapshotModel.fromJson(source['location']);
    }

    AssigneeSnapshotModel? assigneeSnap;
    if (source['assigneeSnapshot'] != null) {
      assigneeSnap = AssigneeSnapshotModel.fromJson(source['assigneeSnapshot']);
    } else if (source['assignee'] != null) {
      assigneeSnap = AssigneeSnapshotModel.fromJson(source['assignee']);
    }

    AssigneeSnapshotModel? creatorSnap;
    if (source['createdBySnapshot'] != null) {
      creatorSnap = AssigneeSnapshotModel.fromJson(source['createdBySnapshot']);
    }

    final approverList = (source['approverSnapshots'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((a) => ApproverSnapshotModel.fromJson(a))
            .toList() ??
        const [];

    final appRoles = (source['approverRoles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

    // Embedded Task Execution (if present)
    TaskExecutionModel? execModel;
    if (source['taskExecution'] != null) {
      execModel = TaskExecutionModel.fromJson(source['taskExecution']);
    }

    // Segments
    final segSnapshots = (source['segmentSnapshots'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((s) => TaskSegmentModel.fromJson(s))
            .toList() ??
        const [];

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    dynamic scopePlanned;
    dynamic scopeCompleted;
    if (source['scope'] is Map<String, dynamic>) {
      scopePlanned = source['scope']['planned'];
      scopeCompleted = source['scope']['completed'];
    }

    final totLen = parseNum(source['totalLengthKm'] ?? source['total_length_km'] ?? source['plannedScope'] ?? scopePlanned) ?? 0.0;
    final covLen = parseNum(source['coveredLengthKm'] ?? source['covered_length_km'] ?? source['completedScope'] ?? scopeCompleted) ?? 0.0;

    final refTaskIds = (source['referenceTaskIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

    // Legacy vendor/supervisor fallback
    Map<String, dynamic> vendorMap = {};
    if (source['vendor'] is Map<String, dynamic>) vendorMap = source['vendor'] as Map<String, dynamic>;
    final vName = (source['vendorName'] ?? source['vendor_name'] ?? vendorMap['name'] ?? 'Unassigned Vendor').toString();
    final partnerVal = (source['partnerName'] ?? source['partner'] ?? 'N/A').toString();

    Map<String, dynamic> supervisorMap = {};
    if (source['supervisor'] is Map<String, dynamic>) supervisorMap = source['supervisor'] as Map<String, dynamic>;
    final supName = (source['supervisorName'] ?? source['supervisor_name'] ?? supervisorMap['name'] ?? 'Unassigned Supervisor').toString();

    Map<String, dynamic> assigneeMap = {};
    if (source['assigneeSnapshot'] is Map<String, dynamic>) {
      assigneeMap = source['assigneeSnapshot'] as Map<String, dynamic>;
    } else if (source['assignee'] is Map<String, dynamic>) {
      assigneeMap = source['assignee'] as Map<String, dynamic>;
    }
    final assName = (source['assigneeName'] ?? assigneeMap['name'] ?? 'Unassigned').toString();
    final desig = (source['designation'] ?? assigneeMap['designation'] ?? 'Field-Supervisor').toString();
    final mob = (source['mobile'] ?? assigneeMap['mobile'] ?? 'N/A').toString();

    final pmName = (source['projectManagerName'] ?? source['projectManager'] ?? 'N/A').toString();
    final creatName = (source['creatorName'] ?? source['creator'] ?? source['createdBy'] ?? creatorSnap?.name ?? 'System').toString();

    final routesList = (source['routes'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((r) => TaskRouteModel.fromJson(r))
            .toList() ??
        const [];

    final pitList = (source['pits'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((p) => TaskPitModel.fromJson(p))
            .toList() ??
        const [];

    TaskTelemetryModel telem = const TaskTelemetryModel(
      oltIp: '10.0.183.2',
      baCmp: 'BA-CMP-01',
      companyPhase: 'HERO Infra Phase 2',
    );
    if (source['telemetry'] is Map<String, dynamic>) {
      telem = TaskTelemetryModel.fromJson(source['telemetry'] as Map<String, dynamic>);
    }

    return TaskModel(
      id: rawId,
      taskCode: code,
      displayName: name,
      taskType: type,
      taskLevel: level,
      status: rawStatus,
      taskStage: rawStage,
      approvalStatus: rawApproval,
      parentTaskId: source['parentTaskId']?.toString() ?? source['parent_task_id']?.toString(),
      ancestors: ancList,
      depth: depthVal,
      rootTaskId: source['rootTaskId']?.toString() ?? source['root_task_id']?.toString(),
      vendorId: source['vendorId']?.toString() ?? source['vendor_id']?.toString(),
      locationCode: locCode,
      routeSnapshot: routeSnap,
      locationSnapshot: locSnap,
      assigneeSnapshot: assigneeSnap,
      approverSnapshots: approverList,
      approverRoles: appRoles,
      createdBySnapshot: creatorSnap,
      taskExecution: execModel,
      currentApprovalStepIndex: (source['currentApprovalStepIndex'] as int?) ?? 0,
      rejectionReason: source['rejectionReason']?.toString() ?? source['rejection_reason']?.toString(),
      description: source['description']?.toString(),
      remarks: source['remarks']?.toString(),
      segmentSnapshots: segSnapshots,
      totalLengthKm: totLen,
      referenceTaskIds: refTaskIds,
      coveredLengthKm: covLen,
      dailyTaskTarget: parseNum(source['dailyTaskTarget'] ?? source['daily_task_target']),
      expectedCompletionDays: source['expectedCompletionDays'] as int?,
      dueDate: DateParserUtils.parse(source['dueDate'] ?? source['due_date']),
      active: source['active'] as bool? ?? true,
      createdAt: DateParserUtils.parse(source['createdAt'] ?? source['created_at']),
      updatedAt: DateParserUtils.parse(source['updatedAt'] ?? source['updated_at']),
      submittedAt: DateParserUtils.parse(source['submittedAt'] ?? source['submitted_at']),
      completedAt: DateParserUtils.parse(source['completedAt'] ?? source['completed_at']),
      meta: source['meta'] is Map<String, dynamic> ? source['meta'] as Map<String, dynamic> : null,
      legacyVendorName: vName,
      legacyPartnerName: partnerVal,
      legacySupervisorName: supName,
      legacyAssigneeName: assName,
      legacyDesignation: desig,
      legacyMobile: mob,
      legacyProjectManagerName: pmName,
      legacyCreatorName: creatName,
      legacyPlannedScope: parseNum(source['plannedScope']) ?? 0.0,
      legacyRemainingScope: parseNum(source['remainingScope']) ?? 0.0,
      legacyCompletedScope: parseNum(source['completedScope']) ?? 0.0,
      legacyProgress: parseNum(source['progress']) ?? 0.0,
      legacyRoutes: routesList,
      legacyPitsCount: (source['pitsCount'] as int?) ?? pitList.length,
      legacyPits: pitList,
      legacyTelemetry: telem,
      legacyLatitude: parseNum(source['latitude'] ?? source['lat'] ?? (source['coordinates'] is Map ? source['coordinates']['latitude'] : null)),
      legacyLongitude: parseNum(source['longitude'] ?? source['lng'] ?? (source['coordinates'] is Map ? source['coordinates']['longitude'] : null)),
      legacyExecutionStatus: source['executionStatus']?.toString(),
      legacyRuntimeData: source['runtimeData'] is Map<String, dynamic> ? source['runtimeData'] as Map<String, dynamic> : null,
      legacyTrenchingLogs: source['trenchingLogs'] is List ? source['trenchingLogs'] as List : null,
      legacyHddLogs: source['hddLogs'] is List ? source['hddLogs'] as List : null,
      legacyDepthPhotos: source['depthPhotos'] is List ? source['depthPhotos'] as List : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskCode': taskCode,
        'displayName': displayName,
        'taskType': taskType,
        'taskLevel': taskLevel,
        'status': status,
        'taskStage': taskStage,
        'approvalStatus': approvalStatus,
        if (parentTaskId != null) 'parentTaskId': parentTaskId,
        'ancestors': ancestors,
        'depth': depth,
        if (rootTaskId != null) 'rootTaskId': rootTaskId,
        if (vendorId != null) 'vendorId': vendorId,
        'locationCode': locationCode,
        if (routeSnapshot != null) 'routeSnapshot': routeSnapshot!.toJson(),
        if (locationSnapshot != null) 'locationSnapshot': locationSnapshot!.toJson(),
        if (assigneeSnapshot != null) 'assigneeSnapshot': assigneeSnapshot!.toJson(),
        'approverSnapshots': approverSnapshots.map((a) => a.toJson()).toList(),
        'approverRoles': approverRoles,
        if (createdBySnapshot != null) 'createdBySnapshot': createdBySnapshot!.toJson(),
        if (taskExecution != null) 'taskExecution': taskExecution!.toJson(),
        'currentApprovalStepIndex': currentApprovalStepIndex,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (description != null) 'description': description,
        if (remarks != null) 'remarks': remarks,
        'segmentSnapshots': segmentSnapshots.map((s) => s.toJson()).toList(),
        'totalLengthKm': totalLengthKm,
        'referenceTaskIds': referenceTaskIds,
        'coveredLengthKm': coveredLengthKm,
        if (dailyTaskTarget != null) 'dailyTaskTarget': dailyTaskTarget,
        if (expectedCompletionDays != null) 'expectedCompletionDays': expectedCompletionDays,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'active': active,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (meta != null) 'meta': meta,
      };
}

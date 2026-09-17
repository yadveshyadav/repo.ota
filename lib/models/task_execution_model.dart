import '../core/utils/date_parser_utils.dart';
import 'task_master_snapshots.dart';
import 'task_media_model.dart';

/// Strongly typed Field Execution payload containing telemetry, pit details, HDD shots,
/// media attachments, officials, and menu configurations.
class FieldDataModel {
  final String? surveyKind;
  final String? currentStep;
  final DateTime? submittedAt;
  final String? workExecutionMode;
  final TaskMediaModel? routeWalkVideo;
  final bool hindranceFound;
  final List<HindranceItemModel> hindranceList;
  final bool trenchingWorkPossible;
  final List<String> hindranceTypes;
  final String? hindranceRemarks;
  final double? distanceCNRequired;

  // Feature menu flags
  final bool menuTrenching;
  final bool menuManhole;
  final bool menuRouteIndicator;
  final bool menuBlowing;
  final bool menuOtdr;
  final bool menuSplicing;
  final bool menuMbSheet;
  final bool menuAbd;

  // Field execution modules
  final Map<String, dynamic>? trenching;
  final TrenchingMachineDetailsModel? trenchingMachineDetails;
  final TaskMediaModel? machineImage;
  final PersonDetailsModel? operatorDetails;
  final PersonDetailsModel? locatorPilotDetails;
  final PersonDetailsModel? ieRepresentative;
  final PersonDetailsModel? districtNodalOfficer;
  final PersonDetailsModel? centralNodalOfficer;

  final List<TaskPitDetailModel> pitDetails;
  final List<HddShotModel> hddShot;

  final Map<String, dynamic>? openTrenching;
  final Map<String, dynamic>? aerial;
  final Map<String, dynamic>? blowing;
  final Map<String, dynamic>? otdr;
  final Map<String, dynamic>? splicing;

  final bool shotInProgress;
  final bool shotIsStopped;
  final List<String> attachmentKeys;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? meta;

  const FieldDataModel({
    this.surveyKind,
    this.currentStep,
    this.submittedAt,
    this.workExecutionMode,
    this.routeWalkVideo,
    this.hindranceFound = false,
    this.hindranceList = const [],
    this.trenchingWorkPossible = true,
    this.hindranceTypes = const [],
    this.hindranceRemarks,
    this.distanceCNRequired,
    this.menuTrenching = true,
    this.menuManhole = true,
    this.menuRouteIndicator = true,
    this.menuBlowing = true,
    this.menuOtdr = true,
    this.menuSplicing = true,
    this.menuMbSheet = true,
    this.menuAbd = true,
    this.trenching,
    this.trenchingMachineDetails,
    this.machineImage,
    this.operatorDetails,
    this.locatorPilotDetails,
    this.ieRepresentative,
    this.districtNodalOfficer,
    this.centralNodalOfficer,
    this.pitDetails = const [],
    this.hddShot = const [],
    this.openTrenching,
    this.aerial,
    this.blowing,
    this.otdr,
    this.splicing,
    this.shotInProgress = false,
    this.shotIsStopped = false,
    this.attachmentKeys = const [],
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.meta,
  });

  factory FieldDataModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const FieldDataModel();
    }

    // Parse hindrance list
    final hList = (json['hindranceList'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((h) => HindranceItemModel.fromJson(h))
            .toList() ??
        const [];

    final hTypes = (json['hindranceTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    // Parse pits & HDD shots
    final pits = (json['pitDetails'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((p) => TaskPitDetailModel.fromJson(p))
            .toList() ??
        const [];

    final shots = (json['hddShot'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((s) => HddShotModel.fromJson(s))
            .toList() ??
        const [];

    final attKeys = (json['attachmentKeys'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return FieldDataModel(
      surveyKind: json['surveyKind']?.toString() ?? json['survey_kind']?.toString(),
      currentStep: json['currentStep']?.toString() ?? json['current_step']?.toString(),
      submittedAt: DateParserUtils.parse(json['submittedAt'] ?? json['submitted_at']),
      workExecutionMode: json['workExecutionMode']?.toString() ?? json['execution_mode']?.toString(),
      routeWalkVideo: json['routeWalkVideo'] != null
          ? TaskMediaModel.fromJson(json['routeWalkVideo'], defaultLabel: 'Route Walk Video')
          : null,
      hindranceFound: json['hindranceFound'] as bool? ?? json['hindrance_found'] as bool? ?? hList.isNotEmpty,
      hindranceList: hList,
      trenchingWorkPossible: json['trenchingWorkPossible'] as bool? ?? true,
      hindranceTypes: hTypes,
      hindranceRemarks: json['hindranceRemarks']?.toString() ?? json['hindrance_remarks']?.toString(),
      distanceCNRequired: parseNum(json['distanceCNRequired'] ?? json['distance_cn_required']),
      menuTrenching: json['menuTrenching'] as bool? ?? true,
      menuManhole: json['menuManhole'] as bool? ?? true,
      menuRouteIndicator: json['menuRouteIndicator'] as bool? ?? true,
      menuBlowing: json['menuBlowing'] as bool? ?? true,
      menuOtdr: json['menuOtdr'] as bool? ?? true,
      menuSplicing: json['menuSplicing'] as bool? ?? true,
      menuMbSheet: json['menuMbSheet'] as bool? ?? true,
      menuAbd: json['menuAbd'] as bool? ?? true,
      trenching: json['trenching'] is Map<String, dynamic> ? json['trenching'] as Map<String, dynamic> : null,
      trenchingMachineDetails: json['trenchingMachineDetails'] != null
          ? TrenchingMachineDetailsModel.fromJson(json['trenchingMachineDetails'])
          : null,
      machineImage: json['machineImage'] != null
          ? TaskMediaModel.fromJson(json['machineImage'], defaultLabel: 'Machine Image')
          : null,
      operatorDetails: json['operatorDetails'] != null ? PersonDetailsModel.fromJson(json['operatorDetails']) : null,
      locatorPilotDetails:
          json['locatorPilotDetails'] != null ? PersonDetailsModel.fromJson(json['locatorPilotDetails']) : null,
      ieRepresentative:
          json['ieRepresentative'] != null ? PersonDetailsModel.fromJson(json['ieRepresentative']) : null,
      districtNodalOfficer:
          json['districtNodalOfficer'] != null ? PersonDetailsModel.fromJson(json['districtNodalOfficer']) : null,
      centralNodalOfficer:
          json['centralNodalOfficer'] != null ? PersonDetailsModel.fromJson(json['centralNodalOfficer']) : null,
      pitDetails: pits,
      hddShot: shots,
      openTrenching: json['openTrenching'] is Map<String, dynamic> ? json['openTrenching'] as Map<String, dynamic> : null,
      aerial: json['aerial'] is Map<String, dynamic> ? json['aerial'] as Map<String, dynamic> : null,
      blowing: json['blowing'] is Map<String, dynamic> ? json['blowing'] as Map<String, dynamic> : null,
      otdr: json['otdr'] is Map<String, dynamic> ? json['otdr'] as Map<String, dynamic> : null,
      splicing: json['splicing'] is Map<String, dynamic> ? json['splicing'] as Map<String, dynamic> : null,
      shotInProgress: json['shotInProgress'] as bool? ?? false,
      shotIsStopped: json['shotIsStopped'] as bool? ?? false,
      attachmentKeys: attKeys,
      notes: json['notes']?.toString() ?? json['remarks']?.toString(),
      createdAt: DateParserUtils.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateParserUtils.parse(json['updatedAt'] ?? json['updated_at']),
      meta: json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (surveyKind != null) 'surveyKind': surveyKind,
        if (currentStep != null) 'currentStep': currentStep,
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        if (workExecutionMode != null) 'workExecutionMode': workExecutionMode,
        if (routeWalkVideo != null) 'routeWalkVideo': routeWalkVideo!.toJson(),
        'hindranceFound': hindranceFound,
        'hindranceList': hindranceList.map((h) => h.toJson()).toList(),
        'trenchingWorkPossible': trenchingWorkPossible,
        'hindranceTypes': hindranceTypes,
        if (hindranceRemarks != null) 'hindranceRemarks': hindranceRemarks,
        if (distanceCNRequired != null) 'distanceCNRequired': distanceCNRequired,
        'menuTrenching': menuTrenching,
        'menuManhole': menuManhole,
        'menuRouteIndicator': menuRouteIndicator,
        'menuBlowing': menuBlowing,
        'menuOtdr': menuOtdr,
        'menuSplicing': menuSplicing,
        'menuMbSheet': menuMbSheet,
        'menuAbd': menuAbd,
        if (trenching != null) 'trenching': trenching,
        if (trenchingMachineDetails != null) 'trenchingMachineDetails': trenchingMachineDetails!.toJson(),
        if (machineImage != null) 'machineImage': machineImage!.toJson(),
        if (operatorDetails != null) 'operatorDetails': operatorDetails!.toJson(),
        if (locatorPilotDetails != null) 'locatorPilotDetails': locatorPilotDetails!.toJson(),
        if (ieRepresentative != null) 'ieRepresentative': ieRepresentative!.toJson(),
        if (districtNodalOfficer != null) 'districtNodalOfficer': districtNodalOfficer!.toJson(),
        if (centralNodalOfficer != null) 'centralNodalOfficer': centralNodalOfficer!.toJson(),
        'pitDetails': pitDetails.map((p) => p.toJson()).toList(),
        'hddShot': hddShot.map((s) => s.toJson()).toList(),
        if (openTrenching != null) 'openTrenching': openTrenching,
        if (aerial != null) 'aerial': aerial,
        if (blowing != null) 'blowing': blowing,
        if (otdr != null) 'otdr': otdr,
        if (splicing != null) 'splicing': splicing,
        'shotInProgress': shotInProgress,
        'shotIsStopped': shotIsStopped,
        'attachmentKeys': attachmentKeys,
        if (notes != null) 'notes': notes,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (meta != null) 'meta': meta,
      };
}

/// Standalone Task Execution Entity domain model
/// Kept strictly separate from Task master model.
class TaskExecutionModel {
  final String id; // Task Execution ID (e.g. exec_9831)
  final String taskId; // Task Master ID (e.g. task_6021)
  final String assigneeUserId;
  final FieldDataModel? fieldData;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? meta;

  const TaskExecutionModel({
    required this.id,
    required this.taskId,
    this.assigneeUserId = '',
    this.fieldData,
    this.createdAt,
    this.updatedAt,
    this.meta,
  });

  factory TaskExecutionModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskExecutionModel(id: '', taskId: '');
    }

    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final rawId = (source['id'] ?? source['executionId'] ?? source['execution_id'] ?? '').toString();
    final rawTaskId = (source['taskId'] ?? source['task_id'] ?? source['task']?['id'] ?? '').toString();
    final userId = (source['assigneeUserId'] ?? source['assignee_user_id'] ?? source['userId'] ?? '').toString();

    FieldDataModel? fieldDataVal;
    if (source['fieldData'] != null) {
      fieldDataVal = FieldDataModel.fromJson(source['fieldData']);
    } else if (source['field_data'] != null) {
      fieldDataVal = FieldDataModel.fromJson(source['field_data']);
    } else {
      fieldDataVal = FieldDataModel.fromJson(source);
    }

    return TaskExecutionModel(
      id: rawId,
      taskId: rawTaskId,
      assigneeUserId: userId,
      fieldData: fieldDataVal,
      createdAt: DateParserUtils.parse(source['createdAt'] ?? source['created_at']),
      updatedAt: DateParserUtils.parse(source['updatedAt'] ?? source['updated_at']),
      meta: source['meta'] is Map<String, dynamic> ? source['meta'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'assigneeUserId': assigneeUserId,
        if (fieldData != null) 'fieldData': fieldData!.toJson(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (meta != null) 'meta': meta,
      };
}

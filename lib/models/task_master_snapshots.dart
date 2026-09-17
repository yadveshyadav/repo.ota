import '../core/utils/date_parser_utils.dart';
import 'task_media_model.dart';
import 'task_model.dart';

/// Strongly typed Route Node entity in Task Master data
class RouteNodeModel {
  final String id;
  final String code;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? nodeType;

  const RouteNodeModel({
    required this.id,
    required this.code,
    required this.name,
    this.latitude,
    this.longitude,
    this.nodeType,
  });

  factory RouteNodeModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const RouteNodeModel(id: '', code: '', name: 'N/A');
    }
    return RouteNodeModel(
      id: (json['id'] ?? json['nodeId'] ?? '').toString(),
      code: (json['code'] ?? json['nodeCode'] ?? 'NODE').toString(),
      name: (json['name'] ?? json['nodeName'] ?? 'Node').toString(),
      latitude: (json['latitude'] ?? json['lat']) is num
          ? (json['latitude'] ?? json['lat']).toDouble()
          : double.tryParse('${json['latitude'] ?? json['lat'] ?? ''}'),
      longitude: (json['longitude'] ?? json['lng']) is num
          ? (json['longitude'] ?? json['lng']).toDouble()
          : double.tryParse('${json['longitude'] ?? json['lng'] ?? ''}'),
      nodeType: json['nodeType']?.toString() ?? json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (nodeType != null) 'nodeType': nodeType,
      };
}

/// Strongly typed Route Snapshot in Task Master data
class RouteSnapshotModel {
  final String routeCode;
  final String routeName;
  final double distanceKm;
  final int segmentsCount;
  final RouteNodeModel? startNode;
  final RouteNodeModel? targetNode;
  final List<TaskSegmentModel> segments;
  final List<List<double>>? polylineCoordinates;

  const RouteSnapshotModel({
    required this.routeCode,
    required this.routeName,
    required this.distanceKm,
    required this.segmentsCount,
    this.startNode,
    this.targetNode,
    this.segments = const [],
    this.polylineCoordinates,
  });

  factory RouteSnapshotModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const RouteSnapshotModel(
        routeCode: 'R01',
        routeName: 'Route 01',
        distanceKm: 0.0,
        segmentsCount: 0,
      );
    }

    final segs = (json['segments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((s) => TaskSegmentModel.fromJson(s))
            .toList() ??
        const [];

    return RouteSnapshotModel(
      routeCode: (json['routeCode'] ?? json['code'] ?? json['route_code'] ?? 'R01').toString(),
      routeName: (json['routeName'] ?? json['name'] ?? json['route_name'] ?? 'Route').toString(),
      distanceKm: (json['distanceKm'] ?? json['distance_km'] ?? 0.0) is num
          ? (json['distanceKm'] ?? json['distance_km'] ?? 0.0).toDouble()
          : double.tryParse('${json['distanceKm'] ?? json['distance_km'] ?? 0}') ?? 0.0,
      segmentsCount: (json['segmentsCount'] ?? json['segments_count'] ?? segs.length) is int
          ? (json['segmentsCount'] ?? json['segments_count'] ?? segs.length)
          : int.tryParse('${json['segmentsCount'] ?? json['segments_count'] ?? segs.length}') ?? segs.length,
      startNode: json['startNode'] != null ? RouteNodeModel.fromJson(json['startNode']) : null,
      targetNode: json['targetNode'] != null ? RouteNodeModel.fromJson(json['targetNode']) : null,
      segments: segs,
    );
  }

  Map<String, dynamic> toJson() => {
        'routeCode': routeCode,
        'routeName': routeName,
        'distanceKm': distanceKm,
        'segmentsCount': segmentsCount,
        if (startNode != null) 'startNode': startNode!.toJson(),
        if (targetNode != null) 'targetNode': targetNode!.toJson(),
        'segments': segments.map((s) => s.toJson()).toList(),
      };
}

/// Strongly typed Location Snapshot in Task Master data
class LocationSnapshotModel {
  final String code;
  final String name;
  final String district;
  final String circle;
  final String blockName;
  final String state;
  final String? enterpriseId;
  final String? company;
  final String? blockId;
  final String? oltIp;
  final String? baCmp;
  final String? companyPhase;
  final String? projectPhase;
  final double? latitude;
  final double? longitude;

  const LocationSnapshotModel({
    required this.code,
    required this.name,
    required this.district,
    required this.circle,
    required this.blockName,
    this.state = 'RAJASTHAN',
    this.enterpriseId,
    this.company,
    this.blockId,
    this.oltIp,
    this.baCmp,
    this.companyPhase,
    this.projectPhase,
    this.latitude,
    this.longitude,
  });

  factory LocationSnapshotModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const LocationSnapshotModel(
        code: 'N/A',
        name: 'Location',
        district: 'N/A',
        circle: 'N/A',
        blockName: 'N/A',
      );
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    dynamic latVal = json['latitude'] ?? json['lat'];
    dynamic lngVal = json['longitude'] ?? json['lng'];
    if (json['coordinates'] is Map<String, dynamic>) {
      latVal = json['coordinates']['latitude'] ?? json['coordinates']['lat'] ?? latVal;
      lngVal = json['coordinates']['longitude'] ?? json['coordinates']['lng'] ?? lngVal;
    }

    return LocationSnapshotModel(
      code: (json['code'] ?? json['locationCode'] ?? json['location_code'] ?? 'N/A').toString(),
      name: (json['name'] ?? json['locationName'] ?? json['location_name'] ?? 'Location').toString(),
      district: (json['district'] ?? 'N/A').toString(),
      circle: (json['circle'] ?? 'N/A').toString(),
      blockName: (json['blockName'] ?? json['block_name'] ?? json['block'] ?? 'N/A').toString(),
      state: (json['state'] ?? 'RAJASTHAN').toString(),
      enterpriseId: json['enterpriseId']?.toString() ?? json['enterprise_id']?.toString(),
      company: json['company']?.toString(),
      blockId: json['blockId']?.toString() ?? json['block_id']?.toString(),
      oltIp: json['oltIp']?.toString() ?? json['olt_ip']?.toString(),
      baCmp: json['baCmp']?.toString() ?? json['ba_cmp']?.toString(),
      companyPhase: json['companyPhase']?.toString() ?? json['company_phase']?.toString(),
      projectPhase: json['projectPhase']?.toString() ?? json['project_phase']?.toString(),
      latitude: parseCoord(latVal),
      longitude: parseCoord(lngVal),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'district': district,
        'circle': circle,
        'blockName': blockName,
        'state': state,
        if (oltIp != null) 'oltIp': oltIp,
        if (baCmp != null) 'baCmp': baCmp,
        if (companyPhase != null) 'companyPhase': companyPhase,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

/// Strongly typed Assignee / Creator User Snapshot
class AssigneeSnapshotModel {
  final String id;
  final String name;
  final String designation;
  final String mobile;
  final String? email;
  final String? avatarUrl;

  const AssigneeSnapshotModel({
    required this.id,
    required this.name,
    this.designation = 'Field-Supervisor',
    this.mobile = 'N/A',
    this.email,
    this.avatarUrl,
  });

  factory AssigneeSnapshotModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const AssigneeSnapshotModel(id: '', name: 'Unassigned');
    }

    return AssigneeSnapshotModel(
      id: (json['id'] ?? json['userId'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['userName'] ?? json['user_name'] ?? 'Unassigned').toString(),
      designation: (json['designation'] ?? json['role'] ?? 'Field-Supervisor').toString(),
      mobile: (json['mobile'] ?? json['phone'] ?? 'N/A').toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'designation': designation,
        'mobile': mobile,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}

/// Strongly typed Approver Snapshot in Task Master approval chain
class ApproverSnapshotModel {
  final String id;
  final String name;
  final String role;
  final int stepIndex;
  final String status;
  final DateTime? actionAt;
  final String? rejectionReason;

  const ApproverSnapshotModel({
    required this.id,
    required this.name,
    this.role = 'Approver',
    this.stepIndex = 0,
    this.status = 'PENDING',
    this.actionAt,
    this.rejectionReason,
  });

  factory ApproverSnapshotModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const ApproverSnapshotModel(id: '', name: 'Approver');
    }

    return ApproverSnapshotModel(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      name: (json['name'] ?? json['userName'] ?? 'Approver').toString(),
      role: (json['role'] ?? json['designation'] ?? 'Approver').toString(),
      stepIndex: (json['stepIndex'] ?? json['step_index'] ?? 0) is int
          ? (json['stepIndex'] ?? json['step_index'] ?? 0)
          : int.tryParse('${json['stepIndex'] ?? json['step_index'] ?? 0}') ?? 0,
      status: (json['status'] ?? json['approvalStatus'] ?? 'PENDING').toString().toUpperCase(),
      actionAt: DateParserUtils.parse(json['actionAt'] ?? json['action_at'] ?? json['approvedAt']),
      rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'stepIndex': stepIndex,
        'status': status,
        if (actionAt != null) 'actionAt': actionAt!.toIso8601String(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };
}

/// Strongly typed Hindrance Item entity
class HindranceItemModel {
  final String id;
  final String type;
  final String? description;
  final double? latitude;
  final double? longitude;
  final TaskMediaModel? media;
  final DateTime? createdAt;

  const HindranceItemModel({
    required this.id,
    required this.type,
    this.description,
    this.latitude,
    this.longitude,
    this.media,
    this.createdAt,
  });

  factory HindranceItemModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const HindranceItemModel(id: '', type: 'General');
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return HindranceItemModel(
      id: (json['id'] ?? json['hindranceId'] ?? '').toString(),
      type: (json['type'] ?? json['hindranceType'] ?? 'General').toString(),
      description: json['description']?.toString() ?? json['remarks']?.toString(),
      latitude: parseCoord(json['latitude'] ?? json['lat']),
      longitude: parseCoord(json['longitude'] ?? json['lng']),
      media: json['media'] != null ? TaskMediaModel.fromJson(json['media'], defaultLabel: 'Hindrance Photo') : null,
      createdAt: DateParserUtils.parse(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (description != null) 'description': description,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (media != null) 'media': media!.toJson(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

/// Strongly typed Trenching Machine details
class TrenchingMachineDetailsModel {
  final String? machineChassisNo;
  final String? modelName;
  final String? ownerVendor;
  final String? machineType;
  final String? serialNumber;
  final TaskMediaModel? image;

  const TrenchingMachineDetailsModel({
    this.machineChassisNo,
    this.modelName,
    this.ownerVendor,
    this.machineType,
    this.serialNumber,
    this.image,
  });

  factory TrenchingMachineDetailsModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TrenchingMachineDetailsModel();
    }

    return TrenchingMachineDetailsModel(
      machineChassisNo: json['machineChassisNo']?.toString() ?? json['chassis_no']?.toString(),
      modelName: json['modelName']?.toString() ?? json['model_name']?.toString(),
      ownerVendor: json['ownerVendor']?.toString() ?? json['vendor_name']?.toString(),
      machineType: json['machineType']?.toString() ?? json['type']?.toString(),
      serialNumber: json['serialNumber']?.toString() ?? json['serial_no']?.toString(),
      image: json['image'] != null ? TaskMediaModel.fromJson(json['image'], defaultLabel: 'Machine Photo') : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (machineChassisNo != null) 'machineChassisNo': machineChassisNo,
        if (modelName != null) 'modelName': modelName,
        if (ownerVendor != null) 'ownerVendor': ownerVendor,
        if (machineType != null) 'machineType': machineType,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (image != null) 'image': image!.toJson(),
      };
}

/// Strongly typed Person / Official Officer Contact Details
class PersonDetailsModel {
  final String name;
  final String? role;
  final String? mobile;
  final String? designation;
  final String? organization;

  const PersonDetailsModel({
    required this.name,
    this.role,
    this.mobile,
    this.designation,
    this.organization,
  });

  factory PersonDetailsModel.fromJson(dynamic json) {
    if (json == null) {
      return const PersonDetailsModel(name: 'N/A');
    }

    if (json is String) {
      return PersonDetailsModel(name: json);
    }

    if (json is Map<String, dynamic>) {
      return PersonDetailsModel(
        name: (json['name'] ?? json['userName'] ?? 'N/A').toString(),
        role: json['role']?.toString(),
        mobile: json['mobile']?.toString() ?? json['phone']?.toString(),
        designation: json['designation']?.toString(),
        organization: json['organization']?.toString() ?? json['department']?.toString(),
      );
    }

    return const PersonDetailsModel(name: 'N/A');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (role != null) 'role': role,
        if (mobile != null) 'mobile': mobile,
        if (designation != null) 'designation': designation,
        if (organization != null) 'organization': organization,
      };
}

/// Strongly typed Pit Detail item in Field Execution
class TaskPitDetailModel {
  final String pitId;
  final String pitName;
  final String pitType;
  final String? chamberType;
  final double? latitude;
  final double? longitude;
  final double? depthMeters;
  final double? widthMeters;
  final String? side;
  final String? couplingStatus;
  final String? refillStatus;
  final String? diggingTime;
  final String? remarks;
  final TaskMediaModel? photo;
  final String? status;

  const TaskPitDetailModel({
    required this.pitId,
    required this.pitName,
    required this.pitType,
    this.chamberType,
    this.latitude,
    this.longitude,
    this.depthMeters,
    this.widthMeters,
    this.side,
    this.couplingStatus,
    this.refillStatus,
    this.diggingTime,
    this.remarks,
    this.photo,
    this.status,
  });

  bool get isCouplingCompleted =>
      couplingStatus?.toUpperCase() == 'COMPLETED' || status?.toUpperCase() == 'COMPLETED';
  bool get isPitRefilled =>
      refillStatus?.toUpperCase() == 'REFILLED' || status?.toUpperCase() == 'COMPLETED';

  factory TaskPitDetailModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const TaskPitDetailModel(pitId: '', pitName: 'Pit', pitType: 'Standard');
    }

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return TaskPitDetailModel(
      pitId: (json['pitId'] ?? json['id'] ?? '').toString(),
      pitName: (json['pitName'] ?? json['name'] ?? 'Pit').toString(),
      pitType: (json['pitType'] ?? json['type'] ?? 'Standard').toString(),
      chamberType: json['chamberType']?.toString() ?? json['chamber_type']?.toString(),
      latitude: parseNum(json['latitude'] ?? json['lat']),
      longitude: parseNum(json['longitude'] ?? json['lng']),
      depthMeters: parseNum(json['depthMeters'] ?? json['depth_m'] ?? json['depth']),
      widthMeters: parseNum(json['widthMeters'] ?? json['width_m'] ?? json['width']),
      side: json['side']?.toString(),
      couplingStatus: json['couplingStatus']?.toString() ?? json['coupling_status']?.toString(),
      refillStatus: json['refillStatus']?.toString() ?? json['refill_status']?.toString(),
      diggingTime: json['diggingTime']?.toString() ?? json['digging_time']?.toString(),
      remarks: json['remarks']?.toString() ?? json['note']?.toString(),
      photo: json['photo'] != null ? TaskMediaModel.fromJson(json['photo'], defaultLabel: 'Pit Photo') : null,
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'pitId': pitId,
        'pitName': pitName,
        'pitType': pitType,
        if (chamberType != null) 'chamberType': chamberType,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (depthMeters != null) 'depthMeters': depthMeters,
        if (widthMeters != null) 'widthMeters': widthMeters,
        if (side != null) 'side': side,
        if (couplingStatus != null) 'couplingStatus': couplingStatus,
        if (refillStatus != null) 'refillStatus': refillStatus,
        if (diggingTime != null) 'diggingTime': diggingTime,
        if (remarks != null) 'remarks': remarks,
        if (photo != null) 'photo': photo!.toJson(),
        if (status != null) 'status': status,
      };
}

/// Strongly typed HDD Shot item in Field Execution
class HddShotModel {
  final String shotId;
  final int shotNumber;
  final double lengthMeters;
  final double? depthMeters;
  final double? pipeDiameterMm;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final String? status;
  final TaskMediaModel? photo;

  const HddShotModel({
    required this.shotId,
    required this.shotNumber,
    required this.lengthMeters,
    this.depthMeters,
    this.pipeDiameterMm,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.status,
    this.photo,
  });

  factory HddShotModel.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const HddShotModel(shotId: '', shotNumber: 1, lengthMeters: 0.0);
    }

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int parseNumInt(dynamic val) {
      if (val == null) return 1;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 1;
    }

    return HddShotModel(
      shotId: (json['shotId'] ?? json['id'] ?? '').toString(),
      shotNumber: parseNumInt(json['shotNumber'] ?? json['shot_no'] ?? json['number']),
      lengthMeters: parseNum(json['lengthMeters'] ?? json['length_m'] ?? json['length']) ?? 0.0,
      depthMeters: parseNum(json['depthMeters'] ?? json['depth_m'] ?? json['depth']),
      pipeDiameterMm: parseNum(json['pipeDiameterMm'] ?? json['dia_mm']),
      startLatitude: parseNum(json['startLatitude'] ?? json['start_lat']),
      startLongitude: parseNum(json['startLongitude'] ?? json['start_lng']),
      endLatitude: parseNum(json['endLatitude'] ?? json['end_lat']),
      endLongitude: parseNum(json['endLongitude'] ?? json['end_lng']),
      status: json['status']?.toString(),
      photo: json['photo'] != null ? TaskMediaModel.fromJson(json['photo'], defaultLabel: 'HDD Shot Photo') : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'shotId': shotId,
        'shotNumber': shotNumber,
        'lengthMeters': lengthMeters,
        if (depthMeters != null) 'depthMeters': depthMeters,
        if (pipeDiameterMm != null) 'pipeDiameterMm': pipeDiameterMm,
        if (startLatitude != null) 'startLatitude': startLatitude,
        if (startLongitude != null) 'startLongitude': startLongitude,
        if (endLatitude != null) 'endLatitude': endLatitude,
        if (endLongitude != null) 'endLongitude': endLongitude,
        if (status != null) 'status': status,
        if (photo != null) 'photo': photo!.toJson(),
      };
}

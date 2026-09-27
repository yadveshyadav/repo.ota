import 'dart:convert';

/// Attendance Proof model storing photo evidence reference and GPS telemetry
class AttendanceProof {
  final String photoKey;
  final String photoCapturedAt;
  final bool cameraLive;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String fixCapturedAt;
  final String provider;
  final bool mockLocationFlagged;
  final String? geoVerdict;
  final double? distanceFromTaskMeters;
  final String? geoCheckedAgainst;
  final String? geoCheckedAt;

  const AttendanceProof({
    required this.photoKey,
    required this.photoCapturedAt,
    this.cameraLive = true,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.fixCapturedAt,
    this.provider = 'gps',
    this.mockLocationFlagged = false,
    this.geoVerdict,
    this.distanceFromTaskMeters,
    this.geoCheckedAgainst,
    this.geoCheckedAt,
  });

  factory AttendanceProof.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    return AttendanceProof(
      photoKey: (json['photoKey'] ?? json['photo_key'] ?? '').toString(),
      photoCapturedAt: (json['photoCapturedAt'] ?? json['photo_captured_at'] ?? DateTime.now().toIso8601String()).toString(),
      cameraLive: json['cameraLive'] as bool? ?? json['camera_live'] as bool? ?? true,
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
      accuracyMeters: parseDouble(json['accuracyMeters'] ?? json['accuracy_meters'] ?? json['accuracy'], 10.0),
      fixCapturedAt: (json['fixCapturedAt'] ?? json['fix_captured_at'] ?? DateTime.now().toIso8601String()).toString(),
      provider: (json['provider'] ?? 'gps').toString(),
      mockLocationFlagged: json['mockLocationFlagged'] as bool? ?? json['mock_location_flagged'] as bool? ?? false,
      geoVerdict: json['geoVerdict']?.toString() ?? json['geo_verdict']?.toString(),
      distanceFromTaskMeters: parseDouble(json['distanceFromTaskMeters'] ?? json['distance_from_task_meters']),
      geoCheckedAgainst: json['geoCheckedAgainst']?.toString() ?? json['geo_checked_against']?.toString(),
      geoCheckedAt: json['geoCheckedAt']?.toString() ?? json['geo_checked_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'photoKey': photoKey,
        'photoCapturedAt': photoCapturedAt,
        'cameraLive': cameraLive,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'fixCapturedAt': fixCapturedAt,
        'provider': provider,
        'mockLocationFlagged': mockLocationFlagged,
        if (geoVerdict != null) 'geoVerdict': geoVerdict,
        if (distanceFromTaskMeters != null) 'distanceFromTaskMeters': distanceFromTaskMeters,
        if (geoCheckedAgainst != null) 'geoCheckedAgainst': geoCheckedAgainst,
        if (geoCheckedAt != null) 'geoCheckedAt': geoCheckedAt,
      };
}

/// Muster Entry representing an individual manpower or machine attendance entry within a DailyMuster
class MusterEntry {
  final String entryId;
  final String type; // 'MANPOWER' or 'MACHINE'
  final String userId;
  final Map<String, dynamic>? userSnapshot;
  final String? crewMemberId;
  final String? name;
  final String? mobile;
  final String? designation;
  final String? skill;
  final String? idProofType;
  final String? idProofLast4;
  final String mark; // 'PRESENT', 'ABSENT', 'LEAVE', etc.
  final num dayFraction; // Default 1
  final String? absenceReason;
  final num? kmTravelled;
  final String? machineId;
  final String? machineType;
  final String? registrationNumber;
  final String? ownership;
  final num? meterStart;
  final num? meterEnd;
  final AttendanceProof? proof;
  final String? inTime;
  final String? outTime;
  final String? remarks;

  const MusterEntry({
    required this.entryId,
    this.type = 'MANPOWER',
    required this.userId,
    this.userSnapshot,
    this.crewMemberId,
    this.name,
    this.mobile,
    this.designation,
    this.skill,
    this.idProofType,
    this.idProofLast4,
    this.mark = 'PRESENT',
    this.dayFraction = 1,
    this.absenceReason,
    this.kmTravelled,
    this.machineId,
    this.machineType,
    this.registrationNumber,
    this.ownership,
    this.meterStart,
    this.meterEnd,
    this.proof,
    this.inTime,
    this.outTime,
    this.remarks = '',
  });

  factory MusterEntry.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic val, [num defaultVal = 0]) {
      if (val == null) return defaultVal;
      if (val is num) return val;
      return num.tryParse(val.toString()) ?? defaultVal;
    }

    AttendanceProof? proofObj;
    if (json['proof'] != null && json['proof'] is Map<String, dynamic>) {
      proofObj = AttendanceProof.fromJson(json['proof'] as Map<String, dynamic>);
    }

    return MusterEntry(
      entryId: (json['entryId'] ?? json['entry_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? 'MANPOWER').toString().toUpperCase(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      userSnapshot: json['userSnapshot'] is Map<String, dynamic>
          ? json['userSnapshot'] as Map<String, dynamic>
          : json['user_snapshot'] is Map<String, dynamic>
              ? json['user_snapshot'] as Map<String, dynamic>
              : null,
      crewMemberId: json['crewMemberId']?.toString() ?? json['crew_member_id']?.toString(),
      name: json['name']?.toString(),
      mobile: json['mobile']?.toString(),
      designation: json['designation']?.toString(),
      skill: json['skill']?.toString(),
      idProofType: json['idProofType']?.toString() ?? json['id_proof_type']?.toString(),
      idProofLast4: json['idProofLast4']?.toString() ?? json['id_proof_last4']?.toString(),
      mark: (json['mark'] ?? 'PRESENT').toString().toUpperCase(),
      dayFraction: parseNum(json['dayFraction'] ?? json['day_fraction'], 1),
      absenceReason: json['absenceReason']?.toString() ?? json['absence_reason']?.toString(),
      kmTravelled: json['kmTravelled'] != null ? parseNum(json['kmTravelled']) : null,
      machineId: json['machineId']?.toString() ?? json['machine_id']?.toString(),
      machineType: json['machineType']?.toString() ?? json['machine_type']?.toString(),
      registrationNumber: json['registrationNumber']?.toString() ?? json['registration_number']?.toString(),
      ownership: json['ownership']?.toString(),
      meterStart: json['meterStart'] != null ? parseNum(json['meterStart']) : null,
      meterEnd: json['meterEnd'] != null ? parseNum(json['meterEnd']) : null,
      proof: proofObj,
      inTime: json['inTime']?.toString() ?? json['in_time']?.toString(),
      outTime: json['outTime']?.toString() ?? json['out_time']?.toString(),
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'type': type,
        'userId': userId,
        if (userSnapshot != null) 'userSnapshot': userSnapshot,
        if (crewMemberId != null) 'crewMemberId': crewMemberId,
        if (name != null) 'name': name,
        if (mobile != null) 'mobile': mobile,
        if (designation != null) 'designation': designation,
        if (skill != null) 'skill': skill,
        if (idProofType != null) 'idProofType': idProofType,
        if (idProofLast4 != null) 'idProofLast4': idProofLast4,
        'mark': mark,
        'dayFraction': dayFraction,
        if (absenceReason != null) 'absenceReason': absenceReason,
        if (kmTravelled != null) 'kmTravelled': kmTravelled,
        if (machineId != null) 'machineId': machineId,
        if (machineType != null) 'machineType': machineType,
        if (registrationNumber != null) 'registrationNumber': registrationNumber,
        if (ownership != null) 'ownership': ownership,
        if (meterStart != null) 'meterStart': meterStart,
        if (meterEnd != null) 'meterEnd': meterEnd,
        if (proof != null) 'proof': proof!.toJson(),
        if (inTime != null) 'inTime': inTime,
        if (outTime != null) 'outTime': outTime,
        'remarks': remarks ?? '',
      };
}

/// DailyMuster model for Netinfra Task Service Attendance API
class DailyMuster {
  final String id;
  final String clientMusterId;
  final List<String> workedOnTaskIds;
  final String teamSource;
  final String vendorId;
  final String vendorName;
  final int headcount;
  final List<dynamic> resources;
  final List<MusterEntry> entries;
  final bool nilWork;
  final String? nilWorkReason;
  final String remarks;
  final String status; // 'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'PENDING_APPROVAL'
  final String approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;

  const DailyMuster({
    required this.id,
    required this.clientMusterId,
    required this.workedOnTaskIds,
    this.teamSource = '',
    this.vendorId = '',
    this.vendorName = '',
    this.headcount = 1,
    this.resources = const [],
    this.entries = const [],
    this.nilWork = false,
    this.nilWorkReason,
    this.remarks = '',
    this.status = 'DRAFT',
    this.approvalStatus = 'PENDING',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
  });

  factory DailyMuster.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final rawId = (source['id'] ?? source['musterId'] ?? source['muster_id'] ?? '').toString();

    List<String> taskIds = [];
    if (source['workedOnTaskIds'] is List) {
      taskIds = (source['workedOnTaskIds'] as List).map((e) => e.toString()).toList();
    } else if (source['worked_on_task_ids'] is List) {
      taskIds = (source['worked_on_task_ids'] as List).map((e) => e.toString()).toList();
    }

    List<MusterEntry> entryList = [];
    if (source['entries'] is List) {
      entryList = (source['entries'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => MusterEntry.fromJson(e))
          .toList();
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return DailyMuster(
      id: rawId,
      clientMusterId: (source['clientMusterId'] ?? source['client_muster_id'] ?? rawId).toString(),
      workedOnTaskIds: taskIds,
      teamSource: (source['teamSource'] ?? source['team_source'] ?? '').toString(),
      vendorId: (source['vendorId'] ?? source['vendor_id'] ?? '').toString(),
      vendorName: (source['vendorName'] ?? source['vendor_name'] ?? '').toString(),
      headcount: source['headcount'] as int? ?? entryList.length,
      resources: source['resources'] is List ? source['resources'] as List : const [],
      entries: entryList,
      nilWork: source['nilWork'] as bool? ?? source['nil_work'] as bool? ?? false,
      nilWorkReason: source['nilWorkReason']?.toString() ?? source['nil_work_reason']?.toString(),
      remarks: (source['remarks'] ?? '').toString(),
      status: (source['status'] ?? 'DRAFT').toString().toUpperCase(),
      approvalStatus: (source['approvalStatus'] ?? source['approval_status'] ?? 'PENDING').toString().toUpperCase(),
      approvedBy: source['approvedBy']?.toString() ?? source['approved_by']?.toString(),
      approvedAt: parseDate(source['approvedAt'] ?? source['approved_at']),
      rejectionReason: source['rejectionReason']?.toString() ?? source['rejection_reason']?.toString(),
      createdAt: parseDate(source['createdAt'] ?? source['created_at']),
      updatedAt: parseDate(source['updatedAt'] ?? source['updated_at']),
      submittedAt: parseDate(source['submittedAt'] ?? source['submitted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'clientMusterId': clientMusterId,
        'workedOnTaskIds': workedOnTaskIds,
        'teamSource': teamSource,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'headcount': headcount,
        'resources': resources,
        'entries': entries.map((e) => e.toJson()).toList(),
        'nilWork': nilWork,
        if (nilWorkReason != null) 'nilWorkReason': nilWorkReason,
        'remarks': remarks,
      };

  DailyMuster copyWith({
    String? id,
    String? clientMusterId,
    List<String>? workedOnTaskIds,
    String? teamSource,
    String? vendorId,
    String? vendorName,
    int? headcount,
    List<dynamic>? resources,
    List<MusterEntry>? entries,
    bool? nilWork,
    String? nilWorkReason,
    String? remarks,
    String? status,
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) {
    return DailyMuster(
      id: id ?? this.id,
      clientMusterId: clientMusterId ?? this.clientMusterId,
      workedOnTaskIds: workedOnTaskIds ?? this.workedOnTaskIds,
      teamSource: teamSource ?? this.teamSource,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      headcount: headcount ?? this.headcount,
      resources: resources ?? this.resources,
      entries: entries ?? this.entries,
      nilWork: nilWork ?? this.nilWork,
      nilWorkReason: nilWorkReason ?? this.nilWorkReason,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}

/// Strongly typed response model for Presigned S3 Photo Upload URL
class PhotoUploadData {
  final String uploadUrl;
  final String photoKey;

  const PhotoUploadData({
    required this.uploadUrl,
    required this.photoKey,
  });

  factory PhotoUploadData.fromJson(Map<String, dynamic> json) {
    return PhotoUploadData(
      uploadUrl: (json['uploadUrl'] ?? json['upload_url'] ?? '').toString(),
      photoKey: (json['photoKey'] ?? json['photo_key'] ?? '').toString(),
    );
  }
}

class PhotoUploadUrlResponse {
  final bool success;
  final PhotoUploadData data;

  const PhotoUploadUrlResponse({
    required this.success,
    required this.data,
  });

  factory PhotoUploadUrlResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? true;
    Map<String, dynamic> dataMap = {};
    if (json['data'] is Map<String, dynamic>) {
      dataMap = json['data'] as Map<String, dynamic>;
    } else {
      dataMap = json;
    }

    return PhotoUploadUrlResponse(
      success: success,
      data: PhotoUploadData.fromJson(dataMap),
    );
  }
}

/// Response for Photo View temporary URL
class PhotoViewResponse {
  final bool success;
  final String photoUrl;

  const PhotoViewResponse({
    required this.success,
    required this.photoUrl,
  });

  factory PhotoViewResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? true;
    String url = '';
    if (json['data'] != null) {
      if (json['data'] is Map && json['data']['photoUrl'] != null) {
        url = json['data']['photoUrl'].toString();
      } else {
        url = json['data'].toString();
      }
    } else if (json['photoUrl'] != null) {
      url = json['photoUrl'].toString();
    } else if (json['url'] != null) {
      url = json['url'].toString();
    }

    return PhotoViewResponse(
      success: success,
      photoUrl: url,
    );
  }
}

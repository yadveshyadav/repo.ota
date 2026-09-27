import 'package:flutter/foundation.dart';
import 'api_client.dart';

class BreakdownCatalogItem {
  final int id;
  final String code;
  final String label;
  final String? severity;
  final bool isOther;

  const BreakdownCatalogItem({
    required this.id,
    required this.code,
    required this.label,
    this.severity,
    this.isOther = false,
  });

  factory BreakdownCatalogItem.fromJson(Map<String, dynamic> json) {
    return BreakdownCatalogItem(
      id: int.tryParse('${json['id']}') ?? 0,
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['code']?.toString() ?? '',
      severity: json['severity']?.toString(),
      isOther: json['is_other'] == true,
    );
  }
}

class BreakdownChoice {
  final String value;
  final String label;

  const BreakdownChoice({required this.value, required this.label});

  factory BreakdownChoice.fromJson(Map<String, dynamic> json) {
    return BreakdownChoice(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value']?.toString() ?? '',
    );
  }
}

class OemBreakdownOptions {
  final List<BreakdownCatalogItem> reasonKeys;
  final List<BreakdownCatalogItem> resolutionKeys;
  final List<BreakdownChoice> severities;
  final List<BreakdownChoice> statuses;
  final List<BreakdownChoice> solvedBy;

  const OemBreakdownOptions({
    this.reasonKeys = const [],
    this.resolutionKeys = const [],
    this.severities = const [],
    this.statuses = const [],
    this.solvedBy = const [],
  });

  factory OemBreakdownOptions.fromJson(Map<String, dynamic> json) {
    List<BreakdownCatalogItem> catalog(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => BreakdownCatalogItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id > 0)
          .toList();
    }

    List<BreakdownChoice> choices(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => BreakdownChoice.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.value.isNotEmpty)
          .toList();
    }

    return OemBreakdownOptions(
      reasonKeys: catalog(json['reason_keys']),
      resolutionKeys: catalog(json['resolution_keys']),
      severities: choices(json['severities']),
      statuses: choices(json['statuses']),
      solvedBy: choices(json['solved_by']),
    );
  }
}

class OpsStopOptions {
  final List<BreakdownCatalogItem> reasonKeys;
  final List<BreakdownChoice> statuses;

  const OpsStopOptions({
    this.reasonKeys = const [],
    this.statuses = const [],
  });

  factory OpsStopOptions.fromJson(Map<String, dynamic> json) {
    List<BreakdownCatalogItem> catalog(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => BreakdownCatalogItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id > 0)
          .toList();
    }

    List<BreakdownChoice> choices(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => BreakdownChoice.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.value.isNotEmpty)
          .toList();
    }

    return OpsStopOptions(
      reasonKeys: catalog(json['reason_keys']),
      statuses: choices(json['statuses']),
    );
  }
}

/// Calls Django Hero backend breakdown proxies (OEM + Internal Ops Stops).
/// Django keeps FiberForce API keys server-side.
class BreakdownApiService {
  final ApiClient apiClient;

  BreakdownApiService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  Map<String, dynamic> _unwrapData(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      return response;
    }
    return <String, dynamic>{};
  }

  Future<OemBreakdownOptions> fetchOemOptions() async {
    try {
      final response = await apiClient.get('/api/v1/breakdowns/oem/options/');
      return OemBreakdownOptions.fromJson(_unwrapData(response));
    } catch (e) {
      if (kDebugMode) {
        print('[BreakdownApiService] OEM options error: $e');
      }
      rethrow;
    }
  }

  Future<OpsStopOptions> fetchOpsOptions() async {
    try {
      final response = await apiClient.get('/api/v1/breakdowns/ops/options/');
      return OpsStopOptions.fromJson(_unwrapData(response));
    } catch (e) {
      if (kDebugMode) {
        print('[BreakdownApiService] Ops options error: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOemBreakdown({
    required String machineChassisNo,
    String? reason,
    List<int> reasonKeyIds = const [],
    String? severity,
    String? occurredAtIso,
    String? refId,
  }) async {
    final body = <String, dynamic>{
      'machine_chassis_no': machineChassisNo,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    if (reasonKeyIds.isNotEmpty) {
      body['reason_key_ids'] = reasonKeyIds;
    }
    if (severity != null && severity.trim().isNotEmpty) {
      body['severity'] = severity.trim().toUpperCase();
    }
    if (occurredAtIso != null && occurredAtIso.trim().isNotEmpty) {
      body['occurred_at'] = occurredAtIso.trim();
    }
    if (refId != null && refId.trim().isNotEmpty) {
      body['ref_id'] = refId.trim();
    }

    final response = await apiClient.post('/api/v1/breakdowns/oem/', body: body);
    return _unwrapData(response);
  }

  Future<Map<String, dynamic>> createOpsStop({
    required String machineChassisNo,
    String? note,
    List<int> reasonKeyIds = const [],
    String? startedAtIso,
    String? refId,
  }) async {
    final body = <String, dynamic>{
      'machine_chassis_no': machineChassisNo,
    };
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    if (reasonKeyIds.isNotEmpty) {
      body['reason_key_ids'] = reasonKeyIds;
    }
    if (startedAtIso != null && startedAtIso.trim().isNotEmpty) {
      body['started_at'] = startedAtIso.trim();
    }
    if (refId != null && refId.trim().isNotEmpty) {
      body['ref_id'] = refId.trim();
    }

    final response = await apiClient.post('/api/v1/breakdowns/ops/', body: body);
    return _unwrapData(response);
  }

  /// Open OEM + Ops issues aggregated by Django from FiberForce/HDD.
  Future<MachineOpenIssuesResult> fetchOpenIssues({
    String? machineChassisNo,
    List<String> chassisList = const [],
  }) async {
    final params = <String, String>{};
    if (machineChassisNo != null && machineChassisNo.trim().isNotEmpty) {
      params['machine_chassis_no'] = machineChassisNo.trim();
    } else if (chassisList.isNotEmpty) {
      params['chassis'] = chassisList.map((c) => c.trim()).where((c) => c.isNotEmpty).join(',');
    }

    final query = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final endpoint = query.isEmpty
        ? '/api/v1/breakdowns/open-issues/'
        : '/api/v1/breakdowns/open-issues/?$query';

    final response = await apiClient.get(endpoint);
    return MachineOpenIssuesResult.fromJson(_unwrapData(response));
  }

  Future<Map<String, dynamic>> closeOemBreakdown({
    required int breakdownId,
    required String resolutionNote,
    String? machineChassisNo,
    String solvedBy = 'INTERNAL',
    List<int> resolutionKeyIds = const [],
  }) async {
    final body = <String, dynamic>{
      'breakdown_id': breakdownId,
      'id': breakdownId,
      'resolution_note': resolutionNote.trim(),
      'solved_by': solvedBy,
    };
    if (machineChassisNo != null && machineChassisNo.trim().isNotEmpty) {
      body['machine_chassis_no'] = machineChassisNo.trim();
    }
    if (resolutionKeyIds.isNotEmpty) {
      body['resolution_key_ids'] = resolutionKeyIds;
    }
    final response = await apiClient.post('/api/v1/breakdowns/oem/close/', body: body);
    return _unwrapData(response);
  }

  Future<Map<String, dynamic>> closeOpsStop({
    required int opsStopId,
    required String closeNote,
    String? machineChassisNo,
  }) async {
    final body = <String, dynamic>{
      'ops_stop_id': opsStopId,
      'id': opsStopId,
      'close_note': closeNote.trim(),
    };
    if (machineChassisNo != null && machineChassisNo.trim().isNotEmpty) {
      body['machine_chassis_no'] = machineChassisNo.trim();
    }
    final response = await apiClient.post('/api/v1/breakdowns/ops/close/', body: body);
    return _unwrapData(response);
  }
}

class MachineOpenIssue {
  final String kind; // OEM | OPS
  final int id;
  final String? ttNumber;
  final String status;
  final String reason;
  final String? severity;
  final String? startedAt;
  final String machineChassisNo;

  const MachineOpenIssue({
    required this.kind,
    required this.id,
    this.ttNumber,
    this.status = 'OPEN',
    this.reason = '',
    this.severity,
    this.startedAt,
    this.machineChassisNo = '',
  });

  bool get isOem => kind.toUpperCase() == 'OEM';

  String get displayDuration {
    final timeStr = startedAt;
    if (timeStr == null || timeStr.trim().isEmpty) return 'Active';
    final dt = DateTime.tryParse(timeStr.trim());
    if (dt == null) return 'Active';

    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.isNegative) return 'Just started';

    if (diff.inDays >= 1) {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (diff.inHours >= 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m';
    }
    return 'Just started';
  }

  factory MachineOpenIssue.fromJson(Map<String, dynamic> json) {
    return MachineOpenIssue(
      kind: (json['kind']?.toString() ?? 'OEM').toUpperCase(),
      id: int.tryParse('${json['id']}') ?? 0,
      ttNumber: json['tt_number']?.toString(),
      status: (json['status']?.toString() ?? 'OPEN').toUpperCase(),
      reason: json['reason']?.toString() ?? '',
      severity: json['severity']?.toString(),
      startedAt: json['started_at']?.toString(),
      machineChassisNo: json['machine_chassis_no']?.toString() ?? '',
    );
  }
}

class MachineOpenIssuesBucket {
  final String machineChassisNo;
  final String? machineName;
  final List<MachineOpenIssue> oem;
  final List<MachineOpenIssue> ops;
  final List<MachineOpenIssue> issues;

  const MachineOpenIssuesBucket({
    required this.machineChassisNo,
    this.machineName,
    this.oem = const [],
    this.ops = const [],
    this.issues = const [],
  });

  bool get hasOpenIssue => issues.isNotEmpty;
  int get openCount => issues.length;

  factory MachineOpenIssuesBucket.fromJson(Map<String, dynamic> json) {
    List<MachineOpenIssue> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => MachineOpenIssue.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id > 0)
          .toList();
    }

    final oem = parseList(json['oem']);
    final ops = parseList(json['ops']);
    var issues = parseList(json['issues']);
    if (issues.isEmpty) {
      issues = [...oem, ...ops];
    }
    return MachineOpenIssuesBucket(
      machineChassisNo: json['machine_chassis_no']?.toString() ?? '',
      machineName: json['machine_name']?.toString(),
      oem: oem,
      ops: ops,
      issues: issues,
    );
  }
}

class MachineOpenIssuesResult {
  final List<MachineOpenIssuesBucket> results;
  final Map<String, MachineOpenIssuesBucket> byChassis;
  final int totalOpen;

  const MachineOpenIssuesResult({
    this.results = const [],
    this.byChassis = const {},
    this.totalOpen = 0,
  });

  MachineOpenIssuesBucket? forChassis(String chassis) {
    final key = chassis.trim();
    if (byChassis.containsKey(key)) return byChassis[key];
    final lower = key.toLowerCase();
    for (final entry in byChassis.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final row in results) {
      if (row.machineChassisNo.toLowerCase() == lower) return row;
    }
    return null;
  }

  factory MachineOpenIssuesResult.fromJson(Map<String, dynamic> json) {
    final results = <MachineOpenIssuesBucket>[];
    final rawResults = json['results'];
    if (rawResults is List) {
      for (final item in rawResults) {
        if (item is Map) {
          results.add(MachineOpenIssuesBucket.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final byChassis = <String, MachineOpenIssuesBucket>{};
    final rawBy = json['by_chassis'];
    if (rawBy is Map) {
      rawBy.forEach((key, value) {
        if (value is Map) {
          final bucket = MachineOpenIssuesBucket.fromJson({
            ...Map<String, dynamic>.from(value),
            'machine_chassis_no': value['machine_chassis_no'] ?? key,
          });
          byChassis[key.toString()] = bucket;
        }
      });
    }
    for (final row in results) {
      if (row.machineChassisNo.isNotEmpty) {
        byChassis.putIfAbsent(row.machineChassisNo, () => row);
      }
    }

    return MachineOpenIssuesResult(
      results: results,
      byChassis: byChassis,
      totalOpen: int.tryParse('${json['total_open']}') ??
          results.where((r) => r.hasOpenIssue).length,
    );
  }
}

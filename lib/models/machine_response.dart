import 'machine.dart';

/// Strongly typed response model for GET /api/v1/machines/ API
class MachineResponse {
  final bool success;
  final List<Machine> machines;
  final int total;
  final Map<String, int> statusCounts;

  const MachineResponse({
    required this.success,
    required this.machines,
    required this.total,
    this.statusCounts = const {},
  });

  int get runningCount =>
      statusCounts['RUNNING'] ?? machines.where((m) => m.isWorking).length;

  int get idleCount =>
      statusCounts['IDLE'] ?? machines.where((m) => m.isIdle).length;

  int get maintenanceCount =>
      statusCounts['MAINTENANCE'] ?? machines.where((m) => m.isMaintenance).length;

  int get offlineCount =>
      statusCounts['OFFLINE'] ?? machines.where((m) => m.isOffline).length;

  int get commissionedCount =>
      statusCounts['COMMISSIONED'] ?? machines.where((m) => m.isCommissioned == true).length;

  factory MachineResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? true;

    final rawList = json['data'] ??
        json['results'] ??
        json['content'] ??
        json['machines'] ??
        json['items'] ??
        json['records'] ??
        json['svgdata'];
    final List<dynamic> dataList = rawList is List ? rawList : [];
    final machines = dataList
        .whereType<Map<String, dynamic>>()
        .map((item) => Machine.fromJson(item))
        .toList();

    int parseNum(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) {
        return int.tryParse(val.trim()) ?? 0;
      }
      return 0;
    }

    final statusCountsMap = <String, int>{};
    if (json.containsKey('status_counts') && json['status_counts'] is Map<String, dynamic>) {
      final rawMap = json['status_counts'] as Map<String, dynamic>;
      rawMap.forEach((k, v) {
        statusCountsMap[k.toUpperCase()] = parseNum(v);
      });
    }

    int computedTotal = statusCountsMap['ALL'] ?? 0;
    if (computedTotal == 0) {
      if (json.containsKey('total') && json['total'] != null) {
        computedTotal = parseNum(json['total']);
      } else if (json.containsKey('svgtotal') && json['svgtotal'] != null) {
        computedTotal = parseNum(json['svgtotal']);
      } else if (json.containsKey('meta') && json['meta'] is Map<String, dynamic>) {
        final meta = json['meta'] as Map<String, dynamic>;
        computedTotal = parseNum(meta['count'] ?? meta['total']);
      } else if (json.containsKey('count') && json['count'] != null) {
        computedTotal = parseNum(json['count']);
      } else {
        computedTotal = machines.length;
      }
    }

    if (computedTotal == 0) {
      computedTotal = machines.length;
    }

    return MachineResponse(
      success: success,
      machines: machines,
      total: computedTotal,
      statusCounts: statusCountsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': machines.map((m) => m.toJson()).toList(),
        'total': total,
        'status_counts': statusCounts,
      };
}

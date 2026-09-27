/// Data model for top dashboard summary cards and backend dashboard response
class DashboardSummary {
  final int totalMachines;
  final int onlineMachines;
  final int offlineMachines;
  final int maintenanceMachines;

  // Real backend fields from /api/v1/dashboard/summary/
  final String? userName;
  final String? projectName;
  final String? currentDate;
  final Map<String, dynamic>? quickStats;
  final Map<String, dynamic>? machineStatusWidget;
  final Map<String, dynamic>? fuelStatusWidget;
  final Map<String, dynamic>? fiberTasks;
  final Map<String, dynamic>? performance;
  final Map<String, dynamic>? myShift;

  const DashboardSummary({
    required this.totalMachines,
    required this.onlineMachines,
    required this.offlineMachines,
    required this.maintenanceMachines,
    this.userName,
    this.projectName,
    this.currentDate,
    this.quickStats,
    this.machineStatusWidget,
    this.fuelStatusWidget,
    this.fiberTasks,
    this.performance,
    this.myShift,
  });

  double get onlinePercentage =>
      totalMachines > 0 ? (onlineMachines / totalMachines) * 100 : 0.0;

  double get offlinePercentage =>
      totalMachines > 0 ? (offlineMachines / totalMachines) * 100 : 0.0;

  double get maintenancePercentage =>
      totalMachines > 0 ? (maintenanceMachines / totalMachines) * 100 : 0.0;

  int get commissionedMachines {
    final val = quickStats?['commissioned_machines'] ??
        quickStats?['commissioned'] ??
        quickStats?['commissioned_count'];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 18;
    return 18;
  }

  int get idleMachines {
    final val = quickStats?['idle_machines'] ??
        quickStats?['idle'] ??
        quickStats?['idle_count'];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 16;
    return 16;
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final Map<String, dynamic> quick = {};
    if (source['quick_stats'] is Map<String, dynamic>) {
      quick.addAll(source['quick_stats'] as Map<String, dynamic>);
    } else if (source['quickStats'] is Map<String, dynamic>) {
      quick.addAll(source['quickStats'] as Map<String, dynamic>);
    }

    if (source['attendance'] is Map<String, dynamic>) {
      quick.addAll(source['attendance'] as Map<String, dynamic>);
    }
    if (source['attendance_stats'] is Map<String, dynamic>) {
      quick.addAll(source['attendance_stats'] as Map<String, dynamic>);
    }

    for (final key in [
      'member_marked', 'marked_members', 'members_marked',
      'member_present', 'present_members', 'team_present', 'team_marked',
      'total_members', 'member_total', 'team_total',
      'machine_marked', 'marked_machines', 'machines_marked',
      'machine_present', 'present_machines', 'machine_attendance',
      'total_machines', 'machine_total',
    ]) {
      if (source.containsKey(key) && !quick.containsKey(key)) {
        quick[key] = source[key];
      }
    }

    int parseIntVal(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val.trim()) ?? 0;
      return 0;
    }

    final total = parseIntVal(
      source['totalMachines'] ??
          source['total_machines'] ??
          quick['total_machines'] ??
          quick['totalMachines'] ??
          quick['machine_total'] ??
          0,
    );

    final online = parseIntVal(
      source['onlineMachines'] ??
          source['running_machines'] ??
          quick['running_machines'] ??
          quick['online_machines'] ??
          quick['onlineMachines'] ??
          0,
    );

    final maintenance = parseIntVal(
      source['maintenanceMachines'] ??
          source['maintenance_machines'] ??
          source['breakdown_count'] ??
          source['breakdowns'] ??
          source['under_breakdown_count'] ??
          quick['maintenance_machines'] ??
          quick['maintenanceMachines'] ??
          quick['breakdown_count'] ??
          quick['breakdowns'] ??
          quick['under_breakdown_count'] ??
          0,
    );

    final rawOffline = parseIntVal(
      source['offlineMachines'] ??
          quick['offline_machines'] ??
          (total - online - maintenance),
    );
    final offline = (rawOffline <= 0 && total > (online + maintenance))
        ? (total - online - maintenance)
        : (rawOffline < 0 ? 0 : rawOffline);

    return DashboardSummary(
      totalMachines: total,
      onlineMachines: online,
      offlineMachines: offline,
      maintenanceMachines: maintenance,
      userName: source['user_name']?.toString() ?? source['userName']?.toString(),
      projectName: source['project_name']?.toString() ?? source['projectName']?.toString(),
      currentDate: source['current_date']?.toString() ?? source['currentDate']?.toString(),
      quickStats: quick,
      machineStatusWidget:
          source['machine_status_widget'] as Map<String, dynamic>?,
      fuelStatusWidget:
          source['fuel_status_widget'] as Map<String, dynamic>?,
      fiberTasks: source['fiber_tasks'] as Map<String, dynamic>?,
      performance: source['performance'] as Map<String, dynamic>?,
      myShift: source['my_shift'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalMachines': totalMachines,
        'onlineMachines': onlineMachines,
        'offlineMachines': offlineMachines,
        'maintenanceMachines': maintenanceMachines,
        if (userName != null) 'user_name': userName,
        if (projectName != null) 'project_name': projectName,
        if (currentDate != null) 'current_date': currentDate,
        if (quickStats != null) 'quick_stats': quickStats,
        if (machineStatusWidget != null)
          'machine_status_widget': machineStatusWidget,
        if (fuelStatusWidget != null) 'fuel_status_widget': fuelStatusWidget,
        if (fiberTasks != null) 'fiber_tasks': fiberTasks,
        if (performance != null) 'performance': performance,
        if (myShift != null) 'my_shift': myShift,
      };
}

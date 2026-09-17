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

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    final quick = source['quick_stats'] as Map<String, dynamic>? ??
        source['quickStats'] as Map<String, dynamic>?;

    final total = (source['totalMachines'] ??
            source['total_machines'] ??
            quick?['total_machines'] ??
            quick?['totalMachines'] ??
            0) as int? ??
        int.tryParse('${source['totalMachines'] ?? source['total_machines'] ?? quick?['total_machines'] ?? 0}') ??
        0;

    final online = (source['onlineMachines'] ??
            source['running_machines'] ??
            quick?['running_machines'] ??
            quick?['online_machines'] ??
            quick?['onlineMachines'] ??
            0) as int? ??
        int.tryParse('${source['onlineMachines'] ?? quick?['running_machines'] ?? 0}') ??
        0;

    final maintenance = (source['maintenanceMachines'] ??
            quick?['maintenance_machines'] ??
            quick?['maintenanceMachines'] ??
            0) as int? ??
        0;

    final offline = (source['offlineMachines'] ??
            quick?['offline_machines'] ??
            (total - online - maintenance)) as int? ??
        (total - online - maintenance);

    return DashboardSummary(
      totalMachines: total,
      onlineMachines: online,
      offlineMachines: offline < 0 ? 0 : offline,
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

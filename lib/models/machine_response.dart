import '../features/auth/models/user_model.dart';
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

  /// Returns a new MachineResponse filtered strictly to the assigned user scope.
  MachineResponse filteredForUser(UserModel? user, {List<Machine>? assignedList}) {
    if (user == null || user.isAdmin) {
      return this;
    }

    final assignedChassisSet = <String>{};
    if (user.machineChassis != null &&
        user.machineChassis!.isNotEmpty &&
        user.machineChassis != 'null') {
      assignedChassisSet.add(user.machineChassis!.trim().toLowerCase());
    }
    if (assignedList != null && assignedList.isNotEmpty) {
      for (final m in assignedList) {
        if (m.machineChassisNo.isNotEmpty) {
          assignedChassisSet.add(m.machineChassisNo.trim().toLowerCase());
        }
      }
    }

    final userVendorName = user.displayVendor.trim().toLowerCase();
    final userName = user.displayName.trim().toLowerCase();
    final username = user.username.trim().toLowerCase();

    // Collect all vendor names associated with the user across vendor, vendorName, vendorDetails, and vendors list
    final userVendorNames = <String>{};
    if (userVendorName.isNotEmpty && userVendorName != 'unassigned vendor') {
      userVendorNames.add(userVendorName);
    }
    if (user.vendorName != null && user.vendorName!.trim().isNotEmpty) {
      userVendorNames.add(user.vendorName!.trim().toLowerCase());
    }
    for (final v in user.vendors) {
      final name = v['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) {
        userVendorNames.add(name);
      }
    }

    final filteredMachines = machines.where((m) {
      final mChassis = m.machineChassisNo.trim().toLowerCase();
      final mVendor = m.vendorName?.trim().toLowerCase() ?? '';
      final mOp = m.operatorName.trim().toLowerCase();

      // 1. Explicit chassis match from user's assigned machines / chassis
      if (assignedChassisSet.contains(mChassis)) {
        return true;
      }

      // 2. Vendor match for any user associated with vendor(s)
      if (userVendorNames.isNotEmpty) {
        for (final uv in userVendorNames) {
          if (mVendor.isNotEmpty && (mVendor == uv || mVendor.contains(uv) || uv.contains(mVendor))) {
            return true;
          }
        }
      }

      // 3. Operator/driver name match
      if (mOp.isNotEmpty && mOp != 'not assigned' && mOp != 'unassigned') {
        if ((userName.isNotEmpty && mOp.contains(userName)) ||
            (userName.isNotEmpty && userName.contains(mOp)) ||
            (username.isNotEmpty && mOp.contains(username)) ||
            (username.isNotEmpty && username.contains(mOp))) {
          return true;
        }
      }

      return false;
    }).toList();

    // Include any assigned machines from API that were not present in full platform list
    if (assignedList != null && assignedList.isNotEmpty) {
      for (final assigned in assignedList) {
        final exists = filteredMachines.any(
          (m) =>
              m.machineChassisNo.trim().toLowerCase() ==
              assigned.machineChassisNo.trim().toLowerCase(),
        );
        if (!exists) {
          filteredMachines.add(assigned);
        }
      }
    }

    return MachineResponse(
      success: success,
      machines: filteredMachines,
      total: filteredMachines.length,
      statusCounts: {
        'ALL': filteredMachines.length,
        'RUNNING': filteredMachines.where((m) => m.isWorking).length,
        'IDLE': filteredMachines.where((m) => m.isIdle).length,
        'OFFLINE': filteredMachines.where((m) => m.isOffline).length,
        'MAINTENANCE': filteredMachines.where((m) => m.isMaintenance || m.isUnderBreakdown).length,
        'COMMISSIONED': filteredMachines.where((m) => m.isCommissioned == true).length,
      },
    );
  }

  int get runningCount =>
      statusCounts['RUNNING'] ?? machines.where((m) => m.isWorking).length;

  int get idleCount =>
      statusCounts['IDLE'] ?? machines.where((m) => m.isIdle).length;

  int get maintenanceCount {
    final bdCount = statusCounts['BREAKDOWN'] ??
        statusCounts['UNDER_BREAKDOWN'] ??
        statusCounts['UNDER BREAKDOWN'] ??
        statusCounts['MAINTENANCE'] ??
        0;
    final codeCount = machines.where((m) => m.isMaintenance || m.isUnderBreakdown).length;
    return bdCount > codeCount ? bdCount : codeCount;
  }

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

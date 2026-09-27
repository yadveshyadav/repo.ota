import '../models/alert.dart';
import '../models/dashboard_summary.dart';
import '../models/engine_hours.dart';
import '../models/fuel_analytics.dart';
import '../models/machine_location.dart';
import '../models/utilization.dart';
import '../services/api/api_client.dart';
import '../services/api/dashboard_api_service.dart';

/// Abstract repository interface for Dashboard
abstract class DashboardRepository {
  Future<DashboardSummary> getSummary();
  Future<FuelAnalytics> getFuelAnalytics();
  Future<Utilization> getUtilization();
  Future<List<Alert>> getActiveAlerts();
  Future<List<MachineLocation>> getLiveLocations();
  Future<EngineHours> getEngineHours({DateTime? date});
  Future<Map<String, dynamic>> getRpmFuelData({String filter = 'Day'});
}

/// Production Dashboard Repository backed by API Service
class ApiDashboardRepository implements DashboardRepository {
  final DashboardApiService apiService;

  ApiDashboardRepository({DashboardApiService? apiService, ApiClient? apiClient})
      : apiService = apiService ??
            DashboardApiService(
              apiClient: apiClient ?? ApiClient(),
            );

  @override
  Future<DashboardSummary> getSummary() async {
    return await apiService.fetchSummary();
  }

  @override
  Future<FuelAnalytics> getFuelAnalytics() async {
    try {
      return await apiService.fetchFuelAnalytics();
    } catch (_) {
      return const FuelAnalytics(fuelConsumed: 0, fuelRefilled: 0, refillCount: 0);
    }
  }

  @override
  Future<Utilization> getUtilization() async {
    try {
      return await apiService.fetchUtilization();
    } catch (_) {
      return const Utilization(working: 0, moving: 0, idle: 0);
    }
  }

  @override
  Future<List<Alert>> getActiveAlerts() async {
    try {
      return await apiService.fetchActiveAlerts();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<MachineLocation>> getLiveLocations() async {
    try {
      return await apiService.fetchLiveLocations();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<EngineHours> getEngineHours({DateTime? date}) async {
    try {
      return await apiService.fetchEngineHours(date: date);
    } catch (_) {
      return EngineHours(
        total: Duration.zero,
        working: Duration.zero,
        moving: Duration.zero,
        idle: Duration.zero,
        averagePerMachine: Duration.zero,
        workingPercentage: 0,
        idlePercentage: 0,
        date: date ?? DateTime.now(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getRpmFuelData({String filter = 'Day'}) async {
    return <String, dynamic>{
      'labels': ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
      'rpm': [0, 800, 1900, 2100, 1850, 0],
      'fuel': [100, 95, 82, 65, 48, 48],
    };
  }
}

/// Mock Dashboard Repository providing realistic industrial fleet monitoring data
class MockDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const DashboardSummary(
      totalMachines: 33,
      onlineMachines: 8,
      offlineMachines: 22,
      maintenanceMachines: 3,
      quickStats: {
        'total_machines': 33,
        'commissioned_machines': 18,
        'running_machines': 8,
        'idle_machines': 16,
        'maintenance_machines': 3,
        'offline_machines': 6,
      },
    );
  }

  @override
  Future<FuelAnalytics> getFuelAnalytics() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const FuelAnalytics(
      fuelConsumed: 2321.6,
      fuelRefilled: 2508.8,
      refillCount: 76,
      periodLabel: '30 Days',
      consumptionDataPoints: [14, 22, 18, 28, 35, 30, 42, 38, 45, 50],
      refillDataPoints: [10, 25, 20, 32, 40, 28, 48, 40, 52, 60],
    );
  }

  @override
  Future<Utilization> getUtilization() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Utilization(
      working: 73.0,
      moving: 3.0,
      idle: 23.0,
      periodLabel: 'Today',
    );
  }

  @override
  Future<List<Alert>> getActiveAlerts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Alert(
        id: '1',
        machineId: 'A600',
        machineName: 'HDD Drill Rig A600',
        chassisNumber: '600202608396',
        title: 'Sudden Fuel Drop (Suspected Theft)',
        severity: 'critical',
        createdAt: DateTime.now().subtract(const Duration(minutes: 29)),
      ),
      Alert(
        id: '2',
        machineId: 'A800',
        machineName: 'Heavy Excavator A800',
        chassisNumber: '800202608593',
        title: 'Coolant Temperature Out Of Range',
        severity: 'warning',
        createdAt: DateTime.now().subtract(const Duration(minutes: 34)),
      ),
      Alert(
        id: '3',
        machineId: 'A450',
        machineName: 'Horizontal Drill A450',
        chassisNumber: '450202608112',
        title: 'High Hydraulic Oil Pressure',
        severity: 'warning',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Alert(
        id: '4',
        machineId: 'A720',
        machineName: 'Crawler Drill A720',
        chassisNumber: '720202608901',
        title: 'Geofence Exit Detected',
        severity: 'info',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  @override
  Future<List<MachineLocation>> getLiveLocations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      MachineLocation(
        id: '1',
        machineName: 'HDD Drill Rig A600',
        chassisNumber: '600202608396',
        status: 'Working',
        latitude: 28.6139,
        longitude: 77.2090, // New Delhi
        speed: 4.2,
        course: 120,
        address: 'Delhi Sector 12 Drilling Site',
      ),
      MachineLocation(
        id: '2',
        machineName: 'Heavy Excavator A800',
        chassisNumber: '800202608593',
        status: 'Idle',
        latitude: 19.0760,
        longitude: 72.8777, // Mumbai
        speed: 0.0,
        course: 0,
        address: 'Mumbai Port Infrastructure Hub',
      ),
      MachineLocation(
        id: '3',
        machineName: 'Horizontal Drill A450',
        chassisNumber: '450202608112',
        status: 'Offline',
        latitude: 12.9716,
        longitude: 77.5946, // Bengaluru
        speed: 0.0,
        course: 0,
        address: 'Bengaluru Metro Line Extension',
      ),
      MachineLocation(
        id: '4',
        machineName: 'Crawler Drill A720',
        chassisNumber: '720202608901',
        status: 'Working',
        latitude: 22.5726,
        longitude: 88.3639, // Kolkata
        speed: 8.5,
        course: 240,
        address: 'Kolkata East Trenching Yard',
      ),
      MachineLocation(
        id: '5',
        machineName: 'Heavy Excavator A900',
        chassisNumber: '900202608404',
        status: 'Working',
        latitude: 17.3850,
        longitude: 78.4867, // Hyderabad
        speed: 2.1,
        course: 45,
        address: 'Hyderabad Fiber Optic Cable Work',
      ),
    ];
  }

  @override
  Future<EngineHours> getEngineHours({DateTime? date}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return EngineHours(
      total: const Duration(hours: 20, minutes: 36),
      working: const Duration(hours: 15, minutes: 0),
      moving: const Duration(hours: 0, minutes: 42),
      idle: const Duration(hours: 4, minutes: 48),
      averagePerMachine: const Duration(hours: 0, minutes: 56),
      workingPercentage: 73.0,
      idlePercentage: 23.5,
      date: date ?? DateTime(2026, 9, 4),
    );
  }

  @override
  Future<Map<String, dynamic>> getRpmFuelData({String filter = 'Day'}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (filter == 'Week') {
      return {
        'fuelUsed': 980.2,
        'fuelRefilled': 1150.0,
        'avgRpm': 1820,
        'maxRpm': 2550,
        'filter': 'Week',
        'points': [
          {'time': 'Mon', 'rpm': 1750, 'fuel': 140},
          {'time': 'Tue', 'rpm': 1810, 'fuel': 155},
          {'time': 'Wed', 'rpm': 1790, 'fuel': 148},
          {'time': 'Thu', 'rpm': 1850, 'fuel': 162},
          {'time': 'Fri', 'rpm': 1820, 'fuel': 158},
          {'time': 'Sat', 'rpm': 1700, 'fuel': 110},
          {'time': 'Sun', 'rpm': 1650, 'fuel': 107},
        ],
      };
    } else if (filter == 'Month') {
      return {
        'fuelUsed': 4120.5,
        'fuelRefilled': 4800.0,
        'avgRpm': 1765,
        'maxRpm': 2600,
        'filter': 'Month',
        'points': [
          {'time': 'W1', 'rpm': 1740, 'fuel': 980},
          {'time': 'W2', 'rpm': 1780, 'fuel': 1050},
          {'time': 'W3', 'rpm': 1800, 'fuel': 1100},
          {'time': 'W4', 'rpm': 1745, 'fuel': 990},
        ],
      };
    }
    // Default Day filter
    return {
      'fuelUsed': 141.5,
      'fuelRefilled': 259.5,
      'avgRpm': 1777,
      'maxRpm': 2499,
      'filter': 'Day',
      'points': [
        {'time': '06:00', 'rpm': 1200, 'fuel': 10},
        {'time': '08:00', 'rpm': 1650, 'fuel': 22},
        {'time': '10:00', 'rpm': 1890, 'fuel': 35},
        {'time': '12:00', 'rpm': 1750, 'fuel': 28},
        {'time': '14:00', 'rpm': 1980, 'fuel': 42},
        {'time': '16:00', 'rpm': 1820, 'fuel': 31},
        {'time': '18:00', 'rpm': 1600, 'fuel': 18},
        {'time': '20:00', 'rpm': 1100, 'fuel': 8},
      ],
    };
  }
}

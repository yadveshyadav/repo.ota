import 'package:flutter/foundation.dart';
import '../models/machine.dart';
import '../models/machine_response.dart';
import '../services/api/api_client.dart';
import '../services/api/machine_api_service.dart';

/// Abstract Machine Repository interface
abstract class MachineRepository {
  Future<MachineResponse> getMachines();
  Future<List<Machine>> getAllMachines();
  Future<List<Machine>> getFilteredMachines({
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? locationFilter,
  });
}

/// Production ApiMachineRepository fetching from Hero / Fiberforce API
class ApiMachineRepository implements MachineRepository {
  final MachineApiService apiService;

  ApiMachineRepository({ApiClient? apiClient, MachineApiService? apiService})
      : apiService = apiService ??
            MachineApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<MachineResponse> getMachines() async {
    try {
      final response = await apiService.fetchMachines();
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('[ApiMachineRepository] Error fetching machines from API ($e), falling back to mock dataset.');
      }
      return MockMachineRepository().getMachines();
    }
  }

  @override
  Future<List<Machine>> getAllMachines() async {
    final response = await getMachines();
    return response.machines;
  }

  @override
  Future<List<Machine>> getFilteredMachines({
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? locationFilter,
  }) async {
    final all = await getAllMachines();
    return all.where((machine) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesId = machine.chassisNumber.toLowerCase().contains(query);
        final matchesName = machine.machineName.toLowerCase().contains(query);
        final matchesType = machine.machineType.toLowerCase().contains(query);
        final matchesLoc = machine.location.toLowerCase().contains(query);
        final matchesModel = machine.model.toLowerCase().contains(query);
        if (!matchesId && !matchesName && !matchesType && !matchesLoc && !matchesModel) {
          return false;
        }
      }

      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter != 'All') {
        final filter = statusFilter.toLowerCase();
        if (filter == 'online' && !machine.isOnline) return false;
        if (filter == 'offline' && !machine.isOffline) return false;
        if (filter == 'moving' && !machine.isMoving) return false;
        if (filter == 'working' && !machine.isWorking) return false;
        if (filter == 'idle' && !machine.isIdle) return false;
        if (filter == 'key on' && !machine.isKeyOnEngineOff) return false;
        if (filter == 'battery' && !machine.isOnBattery) return false;
      }

      return true;
    }).toList();
  }
}

/// Mock implementation containing the exact 25 fleet machines matching the live backend API
class MockMachineRepository implements MachineRepository {
  static const List<Machine> _allMachines = [
    Machine(
      machineChassisNo: '600202608396',
      engineNo: 'TPHM106451',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      fuelCard: {'id': 6, 'name': 'Indian Oil', 'card_number': '7125021301570140'},
      operatorInfo: {'name': 'Mahaveer Gurjar'},
      vendorName: 'Gurukripa Enterprises',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 34.0,
      runtimeStr: '03h 30m',
      engineHours: 122,
      latitude: 27.73793,
      longitude: 74.646078,
    ),
    Machine(
      machineChassisNo: '600202608398',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 7, 'name': 'Indian Oil', 'card_number': '7125021301570157'},
      operatorInfo: {'name': 'Jagjit'},
      vendorName: 'HARPAL INFRA DEVELOPMENT',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 0.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 23.421056,
      longitude: 72.397479,
    ),
    Machine(
      machineChassisNo: '600202608399',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 8, 'name': 'Indian Oil', 'card_number': '7127021301570132'},
      operatorInfo: {'name': 'Rahul'},
      vendorName: 'KHALSA TELECOM',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 18.0,
      runtimeStr: '00h 06m',
      engineHours: 0,
      latitude: 23.420734,
      longitude: 72.397611,
    ),
    Machine(
      machineChassisNo: '600202608400',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 2, 'name': 'Indian Oil', 'card_number': '7125021301570090'},
      operatorInfo: {'name': 'Ranjeet Choudhary'},
      vendorName: 'Naveen Telecom',
      status: 'MAINTENANCE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 72.0,
      runtimeStr: '02h 48m',
      engineHours: 71,
      latitude: 26.615146,
      longitude: 74.374909,
    ),
    Machine(
      machineChassisNo: '600202608401',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 1, 'name': 'Indian Oil', 'card_number': '7125021301570124'},
      operatorInfo: {'name': 'Mahendra Gujjar'},
      vendorName: 'Naveen Telecom Network',
      status: 'RUNNING',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.working,
      fuelLevelPercent: 20.0,
      runtimeStr: '02h 30m',
      engineHours: 56,
      latitude: 26.619534,
      longitude: 74.403026,
    ),
    Machine(
      machineChassisNo: '600202608402',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      operatorInfo: null,
      vendorName: 'Naveen Chouhan',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 25.0,
      runtimeStr: '08h 32m',
      engineHours: 0,
      latitude: 28.199033,
      longitude: 76.227738,
    ),
    Machine(
      machineChassisNo: '800202607590',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 9, 'name': 'Indian Oil', 'card_number': '7125021301570082'},
      operatorInfo: {'name': 'Chandan Kumar Verma'},
      vendorName: 'Raj Enterprises',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 58.0,
      runtimeStr: '00h 30m',
      engineHours: 9,
      latitude: 26.357676,
      longitude: 74.38331,
    ),
    Machine(
      machineChassisNo: '800202608591',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      operatorInfo: {'name': 'Sandeep Kumar'},
      vendorName: 'Pranjal Enterprises',
      status: 'RUNNING',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.working,
      fuelLevelPercent: 31.0,
      runtimeStr: '03h 48m',
      engineHours: 79,
      latitude: 29.713927,
      longitude: 73.564079,
    ),
    Machine(
      machineChassisNo: '800202608593',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 4, 'name': 'Indian Oil', 'card_number': '7127021301570108'},
      operatorInfo: null,
      vendorName: 'Naveen Telecom Network 2',
      status: 'RUNNING',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.working,
      fuelLevelPercent: 26.0,
      runtimeStr: '02h 18m',
      engineHours: 28,
      latitude: 27.10137,
      longitude: 73.712728,
    ),
    Machine(
      machineChassisNo: '800202608594',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 3, 'name': 'Indian Oil', 'card_number': '7126021301570173'},
      operatorInfo: {'name': 'Devaram Choudhary'},
      vendorName: 'Naveen Telecom Network 1',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 39.0,
      runtimeStr: '03h 06m',
      engineHours: 43,
      latitude: 27.029066,
      longitude: 73.788506,
    ),
    Machine(
      machineChassisNo: '600202608397',
      engineNo: 'TPHM109278',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      fuelCard: {'id': 5, 'name': 'Indian Oil', 'card_number': '7125021301570215'},
      operatorInfo: null,
      vendorName: 'Shri Balaji Infra Project',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 1.0,
      runtimeStr: '01h 00m',
      engineHours: 47,
      latitude: 27.691281,
      longitude: 74.640227,
    ),
    Machine(
      machineChassisNo: '600202608403',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'RUNNING',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.working,
      fuelLevelPercent: 23.0,
      runtimeStr: '03h 00m',
      engineHours: 26,
      latitude: 28.157295,
      longitude: 76.175646,
    ),
    Machine(
      machineChassisNo: '600202608404',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'MAINTENANCE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 11.0,
      runtimeStr: '00h 00m',
      engineHours: 5,
      latitude: 28.052881,
      longitude: 74.63988,
    ),
    Machine(
      machineChassisNo: '600202608405',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 21.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 27.296615,
      longitude: 74.738053,
    ),
    Machine(
      machineChassisNo: '600202608406',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'OFFLINE',
      connectivity: ConnectivityState.offline,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 13.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 29.182309,
      longitude: 73.215474,
    ),
    Machine(
      machineChassisNo: '600202608407',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'OFFLINE',
      connectivity: ConnectivityState.offline,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 18.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 29.230016,
      longitude: 73.493481,
    ),
    Machine(
      machineChassisNo: '600202608408',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'MAINTENANCE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 17.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 29.689543,
      longitude: 73.620977,
    ),
    Machine(
      machineChassisNo: '600202608409',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 11.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 25.444867,
      longitude: 71.695914,
    ),
    Machine(
      machineChassisNo: '600202608410',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 22.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 23.42116,
      longitude: 72.398972,
    ),
    Machine(
      machineChassisNo: '600202608411',
      engineNo: '',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 15.0,
      runtimeStr: '00h 18m',
      engineHours: 0,
      latitude: 23.420847,
      longitude: 72.39798,
    ),
    Machine(
      machineChassisNo: '800202607588',
      engineNo: 'STHM129220',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 19.0,
      runtimeStr: '04h 36m',
      engineHours: 58,
      latitude: 22.571441,
      longitude: 75.592673,
    ),
    Machine(
      machineChassisNo: '800202607589',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      fuelCard: {'id': 10, 'name': 'Indian Oil', 'card_number': '7125021301570165'},
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 8.0,
      runtimeStr: '00h 00m',
      engineHours: 0,
      latitude: 26.38051,
      longitude: 74.380015,
    ),
    Machine(
      machineChassisNo: '800202608592',
      engineNo: 'TPHM107665',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: true,
      fuelCard: {'id': 12, 'name': 'Indian Oil', 'card_number': '7127021301570066'},
      operatorInfo: null,
      vendorName: 'Vikas kumar',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 31.0,
      runtimeStr: '03h 00m',
      engineHours: 43,
      latitude: 29.020261,
      longitude: 73.144548,
    ),
    Machine(
      machineChassisNo: '800202608595',
      engineNo: '',
      modelCode: 'A800',
      modelName: 'APOLLO A800 V2',
      siteId: 16,
      siteName: 'Sujangarh-SITE',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'HERO INFRASTRUCTURE',
      status: 'IDLE',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.idle,
      fuelLevelPercent: 21.0,
      runtimeStr: '00h 06m',
      engineHours: 0,
      latitude: 23.421271,
      longitude: 72.398683,
    ),
    Machine(
      machineChassisNo: '821024911',
      engineNo: '93323999',
      modelCode: 'A600',
      modelName: 'APOLLO A600 V2',
      siteId: 16,
      siteName: 'SIHMA-BOQ HDD Site',
      isCommissioned: false,
      operatorInfo: null,
      vendorName: 'Shree Shyam Enterprise',
      status: 'RUNNING',
      connectivity: ConnectivityState.live,
      operationalState: OperationalState.working,
      fuelLevelPercent: 58.0,
      runtimeStr: '08h 32m',
      engineHours: 1250,
      latitude: 28.4595,
      longitude: 77.0266,
    ),
  ];

  @override
  Future<MachineResponse> getMachines() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MachineResponse(
      success: true,
      machines: _allMachines,
      total: _allMachines.length,
      statusCounts: const {
        'ALL': 25,
        'RUNNING': 5,
        'IDLE': 15,
        'MAINTENANCE': 3,
        'BREAKDOWN': 0,
        'OFFLINE': 2,
        'COMMISSIONED': 7,
      },
    );
  }

  @override
  Future<List<Machine>> getAllMachines() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _allMachines;
  }

  @override
  Future<List<Machine>> getFilteredMachines({
    String? searchQuery,
    String? statusFilter,
    String? typeFilter,
    String? locationFilter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _allMachines.where((machine) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesId = machine.chassisNumber.toLowerCase().contains(query);
        final matchesName = machine.machineName.toLowerCase().contains(query);
        final matchesType = machine.machineType.toLowerCase().contains(query);
        final matchesLoc = machine.location.toLowerCase().contains(query);
        final matchesModel = machine.model.toLowerCase().contains(query);
        if (!matchesId && !matchesName && !matchesType && !matchesLoc && !matchesModel) {
          return false;
        }
      }

      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter != 'All') {
        final filter = statusFilter.toLowerCase();
        if (filter == 'online' && !machine.isOnline) return false;
        if (filter == 'offline' && !machine.isOffline) return false;
        if (filter == 'moving' && !machine.isMoving) return false;
        if (filter == 'working' && !machine.isWorking) return false;
        if (filter == 'idle' && !machine.isIdle) return false;
        if (filter == 'key on' && !machine.isKeyOnEngineOff) return false;
        if (filter == 'battery' && !machine.isOnBattery) return false;
      }

      return true;
    }).toList();
  }
}

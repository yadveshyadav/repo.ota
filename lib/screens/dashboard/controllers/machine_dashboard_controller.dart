import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../models/machine.dart';
import '../../../models/machine_response.dart';
import '../../../repositories/machine_repository.dart';

/// State snapshot for Machine Dashboard
class MachineDashboardState {
  final List<Machine> machines;
  final int totalMachines;
  final int runningMachines;
  final int idleMachines;
  final int offlineMachines;
  final int maintenanceMachines;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final DateTime? lastSuccessfulFetch;

  const MachineDashboardState({
    this.machines = const [],
    this.totalMachines = 0,
    this.runningMachines = 0,
    this.idleMachines = 0,
    this.offlineMachines = 0,
    this.maintenanceMachines = 0,
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    this.lastSuccessfulFetch,
  });

  MachineDashboardState copyWith({
    List<Machine>? machines,
    int? totalMachines,
    int? runningMachines,
    int? idleMachines,
    int? offlineMachines,
    int? maintenanceMachines,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    DateTime? lastSuccessfulFetch,
    bool clearError = false,
  }) {
    return MachineDashboardState(
      machines: machines ?? this.machines,
      totalMachines: totalMachines ?? this.totalMachines,
      runningMachines: runningMachines ?? this.runningMachines,
      idleMachines: idleMachines ?? this.idleMachines,
      offlineMachines: offlineMachines ?? this.offlineMachines,
      maintenanceMachines: maintenanceMachines ?? this.maintenanceMachines,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSuccessfulFetch: lastSuccessfulFetch ?? this.lastSuccessfulFetch,
    );
  }
}

/// Controller managing Total Machines API requests, 30s controlled polling, and App Lifecycle
class MachineDashboardController extends ChangeNotifier
    with WidgetsBindingObserver {
  final MachineRepository repository;
  final Duration pollingInterval;

  MachineDashboardState _state = const MachineDashboardState();
  MachineDashboardState get state => _state;

  Timer? _pollingTimer;
  bool _isFetching = false;
  bool _isDisposed = false;

  MachineDashboardController({
    required this.repository,
    this.pollingInterval = const Duration(seconds: 30),
  }) {
    WidgetsBinding.instance.addObserver(this);
    fetchMachines(isInitial: true);
    _startPolling();
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(pollingInterval, (_) {
      fetchMachines(isPolling: true);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      fetchMachines(isPolling: true);
      _startPolling();
    }
  }

  Future<void> fetchMachines({
    bool isInitial = false,
    bool isPolling = false,
    bool isManualRefresh = false,
  }) async {
    if (_isFetching || _isDisposed) return;
    _isFetching = true;

    if (isInitial && _state.totalMachines == 0) {
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();
    } else if (isManualRefresh) {
      _state = _state.copyWith(isRefreshing: true, clearError: true);
      notifyListeners();
    }

    try {
      final MachineResponse response = await repository.getMachines();
      if (_isDisposed) return;

      final machinesList = response.machines;
      final total = response.total > 0 ? response.total : machinesList.length;

      _state = _state.copyWith(
        machines: machinesList,
        totalMachines: total,
        runningMachines: response.runningCount,
        idleMachines: response.idleCount,
        maintenanceMachines: response.maintenanceCount,
        offlineMachines: response.offlineCount,
        isLoading: false,
        isRefreshing: false,
        lastSuccessfulFetch: DateTime.now(),
        clearError: true,
      );
      notifyListeners();

      if (isManualRefresh) {
        _startPolling();
      }
    } catch (e) {
      if (_isDisposed) return;

      _state = _state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Unable to refresh',
      );
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    await fetchMachines(isManualRefresh: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

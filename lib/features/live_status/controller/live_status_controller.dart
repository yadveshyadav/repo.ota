import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/machine.dart';
import '../../../repositories/machine_repository.dart';

/// State Controller managing state, debounced search, filtering,
/// dynamic statistics, and periodic polling for Live Status screen.
class LiveStatusController extends ChangeNotifier {
  final MachineRepository repository;
  Timer? _debounceTimer;
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  List<Machine> _allMachines = [];
  List<Machine> _filteredMachines = [];

  String _searchQuery = '';
  String _selectedFilter = 'All';

  Duration refreshInterval;

  LiveStatusController({
    required this.repository,
    this.refreshInterval = const Duration(seconds: 15),
  });

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  List<Machine> get machines => _filteredMachines;
  List<Machine> get allMachines => _allMachines;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;

  // Fleet Statistics (Dynamically calculated from machine collection)
  int get totalCount => _allMachines.length;
  int get liveCount => _allMachines.where((m) => m.isLive).length;
  int get offlineCount => _allMachines.where((m) => m.isOffline).length;

  /// Load or refresh machine collection
  Future<void> fetchMachines({bool isSilent = false}) async {
    if (!isSilent) {
      if (_allMachines.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await repository.getAllMachines();
      _allMachines = List<Machine>.from(fetched);
      _applyFiltersAndSearch();
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRefreshing = false;
      if (_allMachines.isEmpty) {
        _errorMessage = 'Unable to load machine data';
      }
      notifyListeners();
    }
  }

  /// Start periodic background polling for live updates
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      fetchMachines(isSilent: true);
    });
  }

  /// Stop background polling
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Set and apply status filter chip
  void setFilter(String filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _applyFiltersAndSearch();
    notifyListeners();
  }

  /// Update search query with debouncing
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      _applyFiltersAndSearch();
      notifyListeners();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        _applyFiltersAndSearch();
        notifyListeners();
      });
    }
  }

  /// Update single machine real-time telemetry without reloading entire list
  void updateSingleMachine(Machine updated) {
    final index = _allMachines.indexWhere(
      (m) => m.machineChassisNo == updated.machineChassisNo,
    );
    if (index != -1) {
      _allMachines[index] = updated;
      _applyFiltersAndSearch();
      notifyListeners();
    }
  }

  /// Apply active search query and status chip filter
  void _applyFiltersAndSearch() {
    _filteredMachines = _allMachines.where((machine) {
      // 1. Search Query Filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchChassis = machine.chassisNumber.toLowerCase().contains(q);
        final matchName = machine.machineName.toLowerCase().contains(q);
        final matchModel = machine.model.toLowerCase().contains(q);
        final matchSite = machine.site.toLowerCase().contains(q);
        final matchLoc = machine.location.toLowerCase().contains(q);

        if (!matchChassis &&
            !matchName &&
            !matchModel &&
            !matchSite &&
            !matchLoc) {
          return false;
        }
      }

      // 2. Status Filter Chip
      if (_selectedFilter != 'All') {
        final filter = _selectedFilter.toLowerCase();
        if (filter == 'online' || filter == 'live') {
          if (!machine.isOnline && !machine.isLive) return false;
        } else if (filter == 'offline') {
          if (!machine.isOffline) return false;
        } else if (filter == 'moving') {
          if (!machine.isMoving) return false;
        } else if (filter == 'working' || filter == 'running') {
          if (!machine.isWorking) return false;
        } else if (filter == 'idle') {
          if (!machine.isIdle) return false;
        } else if (filter == 'key on') {
          if (!machine.isKeyOnEngineOff) return false;
        } else if (filter == 'battery') {
          if (!machine.isOnBattery) return false;
        } else if (filter == 'maintenance') {
          if (!machine.isMaintenance) return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

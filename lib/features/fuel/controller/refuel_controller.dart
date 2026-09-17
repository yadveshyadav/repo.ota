import 'package:flutter/foundation.dart';
import '../../../models/refuel_model.dart';
import '../../../repositories/refuel_repository.dart';

/// State Controller managing Refuel History timeline, summary metrics, and API sync
class RefuelController extends ChangeNotifier {
  final RefuelRepository repository;
  final String? machineId;

  List<RefuelModel> _refuelLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  RefuelController({
    RefuelRepository? repository,
    this.machineId,
  }) : repository = repository ?? ApiRefuelRepository();

  // Getters
  List<RefuelModel> get refuelLogs => _refuelLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalRefuels => _refuelLogs.length;

  double get totalFuelAdded =>
      _refuelLogs.fold(0.0, (sum, item) => sum + item.quantityLiters);

  double get avgFuelPerRefuel =>
      totalRefuels > 0 ? (totalFuelAdded / totalRefuels) : 0.0;

  double get totalCost =>
      _refuelLogs.fold(0.0, (sum, item) => sum + item.totalCost);

  /// Load live refuel entries from API
  Future<void> fetchRefuelLogs({String? searchQuery}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _refuelLogs = await repository.getRefuelLogs(
        machineId: machineId,
        searchQuery: searchQuery,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load refuel history: $e';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await fetchRefuelLogs();
  }
}

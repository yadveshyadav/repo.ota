import 'package:flutter/foundation.dart';
import '../../../features/auth/services/auth_storage_service.dart';
import '../../../models/machine.dart';
import '../../../models/machine_movement.dart';
import '../../../models/vendor.dart';
import '../../../repositories/machine_movement_repository.dart';
import '../../../repositories/machine_repository.dart';
import '../../../repositories/vendor_repository.dart';

/// Centralized Controller managing Machine Shifting One-Pager form, state machine, and field actions
class MachineTransferController extends ChangeNotifier {
  final MachineMovementRepository movementRepository;
  final MachineRepository machineRepository;
  final VendorRepository vendorRepository;

  MachineTransferController({
    MachineMovementRepository? movementRepository,
    MachineRepository? machineRepository,
    VendorRepository? vendorRepository,
  }) : movementRepository =
           movementRepository ?? ApiMachineMovementRepository(),
       machineRepository = machineRepository ?? ApiMachineRepository(),
       vendorRepository = vendorRepository ?? ApiVendorRepository();

  // One-Pager Form State
  Machine? _selectedMachine;
  Vendor? _selectedVendor;
  MachineShiftReason? _selectedReason;

  String _aPointName = '';
  double? _aPointLatitude;
  double? _aPointLongitude;

  String _bPointName = '';
  double? _bPointLatitude;
  double? _bPointLongitude;

  String _requiredDate = '';
  String _modeOfShifting = 'OWN_HDD'; // OWN_HDD or BY_TRUCK

  // Dynamic Lists
  List<Machine> _allMachines = [];
  List<Machine> _availableMachines = [];
  List<Vendor> _availableVendors = [];
  List<MachineShiftReason> _availableReasons = [];
  List<MachineMovement> _transfersList = [];

  // Active Detail State
  MachineMovement? _activeTransfer;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  int _unmatchedAssignmentCount = 0;
  bool _catalogLoadFailed = false;

  // Getters
  Machine? get selectedMachine => _selectedMachine;
  Vendor? get selectedVendor => _selectedVendor;
  MachineShiftReason? get selectedReason => _selectedReason;

  String get aPointName => _aPointName;
  double? get aPointLatitude => _aPointLatitude;
  double? get aPointLongitude => _aPointLongitude;

  String get bPointName => _bPointName;
  double? get bPointLatitude => _bPointLatitude;
  double? get bPointLongitude => _bPointLongitude;

  String get requiredDate => _requiredDate;
  String get modeOfShifting => _modeOfShifting;

  List<Machine> get availableMachines => List.unmodifiable(_availableMachines);
  List<Vendor> get availableVendors => List.unmodifiable(_availableVendors);
  List<MachineShiftReason> get availableReasons =>
      List.unmodifiable(_availableReasons);
  List<MachineMovement> get transfersList => List.unmodifiable(_transfersList);

  MachineMovement? get activeTransfer => _activeTransfer;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  int get unmatchedAssignmentCount => _unmatchedAssignmentCount;
  bool get catalogLoadFailed => _catalogLoadFailed;

  /// Initialize One-Pager Form dependencies
  Future<void> initOnePagerForm({Machine? preSelectedMachine}) async {
    _isLoading = true;
    _catalogLoadFailed = false;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load independent catalogs together so the form does not wait for each
      // API request to finish in sequence.
      final catalogs = await Future.wait<dynamic>([
        machineRepository.getMachines(),
        vendorRepository.getVendors(size: 50, allowMockFallback: false),
        movementRepository.getReasons(),
      ]);
      final machineResponse = catalogs[0] as dynamic;
      if (machineResponse.success != true) {
        throw Exception(
          'Could not load the live machine inventory. Please retry.',
        );
      }
      _allMachines = List<Machine>.from(machineResponse.machines as List);
      final vendorResp = catalogs[1] as dynamic;
      final vendors = List<Vendor>.from(vendorResp.vendors as List);
      final user = AuthStorageService().currentUser;
      if (user != null && user.isVendorUser) {
        final vendorIds = <String>{
          if (user.vendorId != null) user.vendorId!,
          ...user.vendors.map((item) => item['id']?.toString()).whereType<String>(),
        };
        final vendorNames = <String>{
          if (user.vendorName != null) _normalizeMachineKey(user.vendorName!),
          if (user.vendorDetails?['name'] != null)
            _normalizeMachineKey(user.vendorDetails!['name'].toString()),
          ...user.vendors
              .map((item) => item['name']?.toString())
              .whereType<String>()
              .map(_normalizeMachineKey),
        };
        _availableVendors = vendors.where((vendor) {
          return vendorIds.contains(vendor.id) ||
              vendorNames.contains(_normalizeMachineKey(vendor.vendorName));
        }).toList();
      } else {
        _availableVendors = vendors;
      }
      _availableReasons = List<MachineShiftReason>.from(catalogs[2] as List);
      _catalogLoadFailed = false;
      _availableMachines = [];
      _selectedMachine = null;
      _selectedVendor = null;
      _selectedReason = null;
      _unmatchedAssignmentCount = 0;

      if (preSelectedMachine != null) {
        final machineKey = _normalizeMachineKey(
          preSelectedMachine.chassisNumber,
        );
        for (final vendor in _availableVendors) {
          final matches = _machinesForVendor(vendor);
          final match = matches.where(
            (m) => _normalizeMachineKey(m.chassisNumber) == machineKey,
          );
          if (match.isNotEmpty) {
            _selectedVendor = vendor;
            _availableMachines = matches;
            _selectedMachine = match.first;
            _aPointName = match.first.location.isNotEmpty
                ? match.first.location
                : 'Origin Site';
            break;
          }
        }
      }

      final now = DateTime.now().add(const Duration(days: 1));
      _requiredDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _catalogLoadFailed = true;
      _errorMessage = 'Failed to initialize form dependencies: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectMachine(Machine machine) {
    if (_selectedVendor == null || !_availableMachines.contains(machine)) {
      return;
    }
    _selectedMachine = machine;
    _aPointName = machine.location.isNotEmpty
        ? machine.location
        : 'Origin Site';
    _aPointLatitude = null;
    _aPointLongitude = null;
    notifyListeners();
  }

  void setSelectedVendor(Vendor vendor) {
    _selectedVendor = vendor;
    _selectedMachine = null;
    _aPointName = '';
    _aPointLatitude = null;
    _aPointLongitude = null;
    _availableMachines = _machinesForVendor(vendor);
    notifyListeners();
  }

  List<Machine> _machinesForVendor(Vendor vendor) {
    final inventoryByKey = <String, Machine>{};
    for (final machine in _allMachines) {
      final key = _normalizeMachineKey(machine.chassisNumber);
      if (key.isNotEmpty && int.tryParse(machine.id) != null) {
        inventoryByKey[key] = machine;
      }
    }
    final assignedKeys = vendor.assignedMachines
        .map(_assignmentMachineKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    final matches = assignedKeys
        .map((key) => inventoryByKey[key])
        .whereType<Machine>()
        .toList();
    _unmatchedAssignmentCount = assignedKeys.length - matches.length;
    return matches;
  }

  String _assignmentMachineKey(Map<String, dynamic> assignment) {
    for (final field in [
      'machineNo',
      'machine_no',
      'machine_chassis_no',
      'chassis_no',
      'chassisNumber',
      'serial_number',
      'serialNumber',
      'code',
    ]) {
      final value = assignment[field]?.toString();
      final key = _normalizeMachineKey(value ?? '');
      if (key.isNotEmpty) return key;
    }
    return '';
  }

  String _normalizeMachineKey(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  void setSelectedReason(MachineShiftReason reason) {
    _selectedReason = reason;
    notifyListeners();
  }

  void setAPoint(String name, {double? lat, double? lng}) {
    _aPointName = name;
    _aPointLatitude = lat;
    _aPointLongitude = lng;
    notifyListeners();
  }

  void setBPoint(String name, {double? lat, double? lng}) {
    _bPointName = name;
    _bPointLatitude = lat;
    _bPointLongitude = lng;
    notifyListeners();
  }

  void setRequiredDate(String date) {
    _requiredDate = date;
    notifyListeners();
  }

  void setModeOfShifting(String mode) {
    _modeOfShifting = mode;
    notifyListeners();
  }

  /// Validate One-Pager Form
  String? validateOnePagerForm() {
    if (_selectedMachine == null) {
      return 'Please select a machine.';
    }
    if (_selectedVendor == null) {
      return 'Please select a vendor.';
    }
    if (!_availableMachines.contains(_selectedMachine)) {
      return 'Select a machine assigned to the selected vendor.';
    }
    if (_selectedReason == null) {
      return 'Please select shifting reason.';
    }
    if (_aPointName.trim().isEmpty) {
      return 'Please specify origin Point A.';
    }
    if (_bPointName.trim().isEmpty) {
      return 'Please specify destination Point B.';
    }
    if (_aPointName.trim().toLowerCase() == _bPointName.trim().toLowerCase()) {
      return 'Destination Point B must be different from Origin Point A.';
    }
    if (_requiredDate.trim().isEmpty) {
      return 'Please select required date.';
    }
    return null;
  }

  /// Submit One-Pager Shift Request
  Future<MachineMovement?> submitOnePagerShiftRequest() async {
    final validationErr = validateOnePagerForm();
    if (validationErr != null) {
      _errorMessage = validationErr;
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await movementRepository.createRequest(
        vendorId: _selectedVendor!.id,
        machineId: _selectedMachine!.id.isNotEmpty
            ? _selectedMachine!.id
            : _selectedMachine!.chassisNumber,
        reasonId: _selectedReason!.id,
        aPointName: _aPointName.trim(),
        aPointLatitude: _aPointLatitude,
        aPointLongitude: _aPointLongitude,
        bPointName: _bPointName.trim(),
        bPointLatitude: _bPointLatitude,
        bPointLongitude: _bPointLongitude,
        requiredDate: _requiredDate,
        modeOfShifting: _modeOfShifting,
        machineName: _selectedMachine!.machineName,
        machineChassisNo: _selectedMachine!.chassisNumber,
        vendorName: _selectedVendor!.vendorName,
        reasonName: _selectedReason!.name,
      );

      _activeTransfer = result;
      _isSubmitting = false;
      _successMessage =
          'Shift request ${result.requestId} created successfully.';
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSubmitting = false;
      notifyListeners();
      return null;
    }
  }

  /// Field Shifter Action: Start Shifting
  Future<bool> startShifting(dynamic requestId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await movementRepository.startShifting(requestId);
      _activeTransfer = result;
      _isSubmitting = false;
      _successMessage = 'Shifting marked as In Progress.';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Field Shifter Action: Mark as Shifted with Camera Photo
  Future<bool> markShifted({
    required dynamic requestId,
    required String shiftingDate,
    required String shiftingMode,
    required String shiftingContactPerson,
    required String shiftingExpenseAmount,
    List<int>? photoBytes,
    String photoFilename = 'rig_photo.jpg',
    String? remarks,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await movementRepository.markShifted(
        id: requestId,
        shiftingDate: shiftingDate,
        shiftingMode: shiftingMode,
        shiftingContactPerson: shiftingContactPerson,
        shiftingExpenseAmount: shiftingExpenseAmount,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
        remarks: remarks,
      );

      _activeTransfer = result;
      _isSubmitting = false;
      _successMessage = 'Machine marked as SHIFTED successfully!';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch Shift Requests List
  Future<void> fetchTransfersList({String? statusFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transfersList = await movementRepository.getRequests(
        statusFilter: statusFilter,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load shift requests: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch Single Shift Request Detail
  Future<void> fetchTransferDetail(dynamic id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeTransfer = await movementRepository.getRequestById(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load request detail: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}

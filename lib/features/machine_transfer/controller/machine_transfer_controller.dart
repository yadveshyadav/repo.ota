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
  })  : movementRepository = movementRepository ?? ApiMachineMovementRepository(),
        machineRepository = machineRepository ?? ApiMachineRepository(),
        vendorRepository = vendorRepository ?? ApiVendorRepository();

  // One-Pager Form State
  Machine? _selectedMachine;
  Vendor? _selectedVendor;
  MachineShiftReason? _selectedReason;

  String _aPointName = '';
  double _aPointLatitude = 27.8129;
  double _aPointLongitude = 74.5036;

  String _bPointName = '';
  double _bPointLatitude = 28.0825;
  double _bPointLongitude = 74.6189;

  String _requiredDate = '2026-09-27';
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

  // Getters
  Machine? get selectedMachine => _selectedMachine;
  Vendor? get selectedVendor => _selectedVendor;
  MachineShiftReason? get selectedReason => _selectedReason;

  String get aPointName => _aPointName;
  double get aPointLatitude => _aPointLatitude;
  double get aPointLongitude => _aPointLongitude;

  String get bPointName => _bPointName;
  double get bPointLatitude => _bPointLatitude;
  double get bPointLongitude => _bPointLongitude;

  String get requiredDate => _requiredDate;
  String get modeOfShifting => _modeOfShifting;

  List<Machine> get availableMachines => List.unmodifiable(_availableMachines);
  List<Vendor> get availableVendors => List.unmodifiable(_availableVendors);
  List<MachineShiftReason> get availableReasons => List.unmodifiable(_availableReasons);
  List<MachineMovement> get transfersList => List.unmodifiable(_transfersList);

  MachineMovement? get activeTransfer => _activeTransfer;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  /// Initialize One-Pager Form dependencies
  Future<void> initOnePagerForm({Machine? preSelectedMachine}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allMachines = await machineRepository.getAllMachines();
      final user = AuthStorageService().currentUser;

      if (user != null && user.isVendorUser && user.vendors.isNotEmpty) {
        final vendorNames = user.vendors
            .map((v) => v['name']?.toString().toLowerCase())
            .whereType<String>()
            .toSet();

        final filtered = _allMachines.where((m) {
          final mVendor = m.vendorName?.toLowerCase();
          if (mVendor == null) return false;
          return vendorNames.contains(mVendor) || vendorNames.any((v) => mVendor.contains(v));
        }).toList();

        _availableMachines = filtered.isNotEmpty ? filtered : _allMachines;
      } else {
        _availableMachines = _allMachines;
      }

      final vendorResp = await vendorRepository.getVendors(size: 50);
      _availableVendors = vendorResp.vendors;

      _availableReasons = await movementRepository.getReasons();
      if (_availableReasons.isNotEmpty) {
        _selectedReason = _availableReasons.first;
      }

      if (preSelectedMachine != null) {
        selectMachine(preSelectedMachine);
      } else if (_selectedMachine != null && !_availableMachines.contains(_selectedMachine)) {
        _selectedMachine = _availableMachines.isNotEmpty ? _availableMachines.first : null;
      }

      final now = DateTime.now().add(const Duration(days: 1));
      _requiredDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize form dependencies: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectMachine(Machine machine) {
    _selectedMachine = machine;
    _aPointName = machine.location.isNotEmpty ? machine.location : 'Origin Site';

    if (_availableVendors.isNotEmpty) {
      final mVendorName = machine.vendorName?.toLowerCase() ?? '';
      try {
        _selectedVendor = _availableVendors.firstWhere(
          (v) => v.vendorName.toLowerCase() == mVendorName ||
                 mVendorName.contains(v.vendorName.toLowerCase()) ||
                 v.vendorName.toLowerCase().contains(mVendorName),
        );
      } catch (_) {
        if (_selectedVendor == null && _availableVendors.isNotEmpty) {
          _selectedVendor = _availableVendors.first;
        }
      }
    }
    notifyListeners();
  }

  void setSelectedVendor(Vendor vendor) {
    _selectedVendor = vendor;
    if (_allMachines.isNotEmpty) {
      final vName = vendor.vendorName.toLowerCase();
      final filtered = _allMachines.where((m) {
        final mVendor = m.vendorName?.toLowerCase() ?? '';
        return mVendor == vName || mVendor.contains(vName) || vName.contains(mVendor);
      }).toList();

      if (filtered.isNotEmpty) {
        _availableMachines = filtered;
      } else {
        _availableMachines = _allMachines;
      }
    }
    notifyListeners();
  }

  void setSelectedReason(MachineShiftReason reason) {
    _selectedReason = reason;
    notifyListeners();
  }

  void setAPoint(String name, {double? lat, double? lng}) {
    _aPointName = name;
    if (lat != null) _aPointLatitude = lat;
    if (lng != null) _aPointLongitude = lng;
    notifyListeners();
  }

  void setBPoint(String name, {double? lat, double? lng}) {
    _bPointName = name;
    if (lat != null) _bPointLatitude = lat;
    if (lng != null) _bPointLongitude = lng;
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
        machineId: _selectedMachine!.id.isNotEmpty ? _selectedMachine!.id : _selectedMachine!.chassisNumber,
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
      _successMessage = 'Shift request ${result.requestId} created successfully.';
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
      _transfersList = await movementRepository.getRequests(statusFilter: statusFilter);
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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/attendance_location.dart';
import '../../../models/attendance_model.dart';
import '../../../models/machine.dart';
import '../../../models/muster_model.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_storage_service.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../services/attendance_storage_service.dart';
import '../../../services/attendance_photo_stamp_service.dart';
import '../../../services/camera_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/location_service.dart';

/// State Controller managing Attendance Check-In/Out workflow, Machine Attendance, Team Attendance,
/// Netinfra DailyMuster submission, Location/GPS Validation, Camera Capture with face verification, History timeline, and Persistence.
class AttendanceController extends ChangeNotifier {
  final AttendanceRepository repository;
  final LocationService locationService;
  final AttendanceCameraService cameraService;
  final AttendanceFaceDetectionService faceDetectionService;
  final AttendancePhotoStampService photoStampService;

  static const double maxLocationAccuracyMeters = 50.0;

  bool _isLoadingToday = true;
  bool _isSubmitting = false;
  bool _isVerifyingFace = false;
  bool _isLoadingHistory = false;
  bool _isLoadingApprovals = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _faceVerified = false;
  String? _faceRejectionMessage;

  AttendanceModel? _todayAttendance;

  // Selected Task Context for Muster Integration
  String? _selectedTaskId;

  // Machine Attendance & Team Attendance Lists
  List<Machine> _assignedMachines = [];
  List<UserModel> _teamMembers = [];

  // In-memory cache for today's marked team attendance records
  final Map<String, AttendanceModel> _markedTeamAttendanceMap = {};
  // In-memory cache for today's marked machine attendance records
  final Map<String, AttendanceModel> _markedMachineAttendanceMap = {};

  // Location Capture State
  AttendanceLocation? _capturedLocation;
  bool _useTestLocation = false;
  String _locationSource = 'GPS';

  // Photo Capture State
  XFile? _capturedPhoto;
  Uint8List? _capturedPhotoBytes;
  String? _capturedPhotoPath;

  List<AttendanceModel> _history = [];
  List<AttendanceModel> _pendingApprovals = [];
  List<DailyMuster> _pendingMusterApprovals = [];
  bool _isDisposed = false;
  Timer? _autoSyncTimer;

  AttendanceController({
    AttendanceRepository? repository,
    LocationService? locationService,
    AttendanceCameraService? cameraService,
    AttendanceFaceDetectionService? faceDetectionService,
    AttendancePhotoStampService? photoStampService,
  }) : repository = repository ?? ApiAttendanceRepository(),
       locationService = locationService ?? AppLocationService(),
       cameraService = cameraService ?? AttendanceCameraService(),
       faceDetectionService =
           faceDetectionService ?? AttendanceFaceDetectionService(),
       photoStampService = photoStampService ?? AttendancePhotoStampService() {
    _startAutoSyncTimer();
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (_isDisposed) return;
      try {
        final unsynced = await AttendanceStorageService().getUnsyncedRecords();
        if (unsynced.isNotEmpty) {
          if (kDebugMode) {
            print(
              '[AttendanceController] 2-min auto-sync triggered for ${unsynced.length} pending record(s)...',
            );
          }
          await syncPendingAttendance();
        }
      } catch (_) {}
    });
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) super.notifyListeners();
      });
      return;
    }

    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSyncTimer?.cancel();
    faceDetectionService.dispose();
    super.dispose();
  }

  /// Helper for unit testing photo capture state
  void setTestCapturedPhoto(XFile photo, List<int> photoBytes) {
    _capturedPhoto = photo;
    _capturedPhotoBytes = Uint8List.fromList(photoBytes);
    _faceVerified = true;
  }

  // Getters
  bool get isLoadingToday => _isLoadingToday;
  bool get isSubmitting => _isSubmitting;
  bool get isVerifyingFace => _isVerifyingFace;
  bool get isFaceVerified => _faceVerified;
  String? get faceRejectionMessage => _faceRejectionMessage;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingApprovals => _isLoadingApprovals;
  bool get isSyncing => _isSyncing;
  int get unsyncedCount => _history.where((r) => !r.isSynced).length;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  String? get selectedTaskId => _selectedTaskId;
  void setSelectedTaskId(String? taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }

  AttendanceModel? get todayAttendance => _todayAttendance;
  List<Machine> get assignedMachines => _assignedMachines;
  List<UserModel> get teamMembers => _teamMembers;

  AttendanceLocation? get capturedLocation => _capturedLocation;
  bool get useTestLocation => _useTestLocation;
  String get locationSource => _locationSource;

  XFile? get capturedPhoto => _capturedPhoto;
  Uint8List? get capturedPhotoBytes => _capturedPhotoBytes;
  String? get capturedPhotoPath => _capturedPhotoPath;

  List<AttendanceModel> get history => _history;
  List<AttendanceModel> get pendingApprovals => _pendingApprovals;
  List<DailyMuster> get pendingMusterApprovals => _pendingMusterApprovals;

  /// Returns count of unique machines marked today
  int get markedMachineCount {
    if (_assignedMachines.isNotEmpty) {
      int count = 0;
      for (final m in _assignedMachines) {
        if (getTodayAttendanceForMachine(m.chassisNumber) != null) {
          count++;
        }
      }
      return count;
    }

    final now = DateTime.now();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }

    final records = _markedMachineAttendanceMap.values
        .where((r) => isSameDay(r.checkInTime ?? r.createdAt))
        .map((r) => r.id)
        .toSet();
    return records.length;
  }

  /// Returns count of unique members marked today
  int get markedMemberCount {
    final now = DateTime.now();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }

    final records = _markedTeamAttendanceMap.values
        .where((r) => isSameDay(r.checkInTime ?? r.createdAt))
        .map((r) => r.id)
        .toSet();
    return records.length;
  }

  void _registerTeamAttendanceRecord(AttendanceModel record) {
    final checkInTime = record.checkInTime;
    if (checkInTime == null) return;

    final statusUpper = record.status.toUpperCase();
    if (statusUpper == 'NOT_MARKED' ||
        statusUpper == 'NOT_CHECKED_IN' ||
        statusUpper == 'REJECTED' ||
        record.approvalStatus == 'REJECTED') {
      return;
    }

    final now = DateTime.now();
    bool isSameDay(DateTime dt) {
      final local = dt.toLocal();
      final nowLocal = now.toLocal();
      return local.year == nowLocal.year &&
          local.month == nowLocal.month &&
          local.day == nowLocal.day;
    }

    if (!isSameDay(checkInTime)) return;

    if (record.isMachineAttendance) {
      void addChassisKey(String? chassis) {
        if (chassis == null) return;
        final clean = chassis.trim().toLowerCase();
        if (clean.isEmpty || clean == 'n/a' || clean.length < 4) return;
        _markedMachineAttendanceMap[clean] = record;
      }

      addChassisKey(record.machineChassisNo);
      addChassisKey(record.machineId);
      addChassisKey(record.machineAssignmentId);
    } else {
      if (record.userId.trim().isNotEmpty) {
        _markedTeamAttendanceMap[record.userId.trim().toLowerCase()] = record;
      }
      if (record.markedForUserId != null &&
          record.markedForUserId!.trim().isNotEmpty) {
        _markedTeamAttendanceMap[record.markedForUserId!.trim().toLowerCase()] =
            record;
      }
      if (record.employeeId != null && record.employeeId!.trim().isNotEmpty) {
        _markedTeamAttendanceMap[record.employeeId!.trim().toLowerCase()] =
            record;
      }
    }

    _history.removeWhere((item) => item.id == record.id);
    _history.insert(0, record);
  }

  Future<void> _syncLocalTeamRecords() async {
    try {
      final localRecords = await AttendanceStorageService().getAllRecords();
      final now = DateTime.now().toLocal();
      for (final rec in localRecords) {
        final dt = rec.checkInTime?.toLocal();
        if (dt != null &&
            dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day) {
          _registerTeamAttendanceRecord(rec);
        }
      }
    } catch (_) {}
  }

  /// Returns today's active attendance record for a specific team member or user ID, if any.
  AttendanceModel? getTodayAttendanceForUser(
    String targetUserId, {
    String? employeeId,
    String? userName,
  }) {
    final nowLocal = DateTime.now().toLocal();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == nowLocal.year &&
          local.month == nowLocal.month &&
          local.day == nowLocal.day;
    }

    final idClean = targetUserId.trim().toLowerCase();
    final empClean = employeeId?.trim().toLowerCase() ?? '';

    if (idClean.isNotEmpty && _markedTeamAttendanceMap.containsKey(idClean)) {
      final rec = _markedTeamAttendanceMap[idClean]!;
      if (rec.checkInTime != null && isSameDay(rec.checkInTime)) return rec;
    }
    if (empClean.isNotEmpty && _markedTeamAttendanceMap.containsKey(empClean)) {
      final rec = _markedTeamAttendanceMap[empClean]!;
      if (rec.checkInTime != null && isSameDay(rec.checkInTime)) return rec;
    }

    if (_todayAttendance != null && !_todayAttendance!.isMachineAttendance) {
      final t = _todayAttendance!;
      final matchesUser =
          (t.userId.toLowerCase().trim() == idClean) ||
          (t.markedForUserId != null &&
              t.markedForUserId!.toLowerCase().trim() == idClean) ||
          (empClean.isNotEmpty &&
              t.employeeId != null &&
              t.employeeId!.toLowerCase().trim() == empClean);

      final statusUpper = t.status.toUpperCase();
      final isMarkedStatus =
          t.checkInTime != null &&
          statusUpper != 'NOT_MARKED' &&
          statusUpper != 'NOT_CHECKED_IN' &&
          statusUpper != 'REJECTED' &&
          t.approvalStatus != 'REJECTED';

      if (matchesUser && isSameDay(t.checkInTime) && isMarkedStatus) {
        return t;
      }
    }

    for (final record in _history) {
      if (record.isMachineAttendance) continue;
      final matchesUser =
          (record.userId.toLowerCase().trim() == idClean) ||
          (record.markedForUserId != null &&
              record.markedForUserId!.toLowerCase().trim() == idClean) ||
          (empClean.isNotEmpty &&
              record.employeeId != null &&
              record.employeeId!.toLowerCase().trim() == empClean);

      final checkInTime = record.checkInTime;
      final statusUpper = record.status.toUpperCase();
      final isMarkedStatus =
          checkInTime != null &&
          statusUpper != 'NOT_MARKED' &&
          statusUpper != 'NOT_CHECKED_IN' &&
          statusUpper != 'REJECTED' &&
          record.approvalStatus != 'REJECTED';

      if (matchesUser &&
          checkInTime != null &&
          isSameDay(checkInTime) &&
          isMarkedStatus) {
        return record;
      }
    }

    return null;
  }

  /// Returns today's active attendance record for a specific machine chassis number, if any.
  AttendanceModel? getTodayAttendanceForMachine(String chassisNo) {
    final nowLocal = DateTime.now().toLocal();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == nowLocal.year &&
          local.month == nowLocal.month &&
          local.day == nowLocal.day;
    }

    final chassisLower = chassisNo.toLowerCase().trim();
    if (chassisLower.isEmpty || chassisLower == 'n/a') return null;

    bool isMachineMatch(String? candidateNo, String? candidateId) {
      final cNo = candidateNo?.toLowerCase().trim() ?? '';
      final mId = candidateId?.toLowerCase().trim() ?? '';

      if (cNo.isNotEmpty && cNo != 'n/a') {
        if (cNo == chassisLower) return true;
        if (cNo.length >= 6 &&
            chassisLower.length >= 6 &&
            (cNo.endsWith(chassisLower) || chassisLower.endsWith(cNo))) {
          return true;
        }
      }
      if (mId.isNotEmpty && mId != 'n/a') {
        if (mId == chassisLower) return true;
        if (mId.length >= 6 &&
            chassisLower.length >= 6 &&
            (mId.endsWith(chassisLower) || chassisLower.endsWith(mId))) {
          return true;
        }
      }
      return false;
    }

    // 1. Direct exact map lookup
    if (_markedMachineAttendanceMap.containsKey(chassisLower)) {
      final rec = _markedMachineAttendanceMap[chassisLower]!;
      final statusUpper = rec.status.toUpperCase();
      final isMarkedStatus =
          rec.checkInTime != null &&
          statusUpper != 'NOT_MARKED' &&
          statusUpper != 'NOT_CHECKED_IN' &&
          statusUpper != 'REJECTED' &&
          rec.approvalStatus != 'REJECTED';
      if (rec.checkInTime != null &&
          isSameDay(rec.checkInTime) &&
          isMarkedStatus)
        return rec;
    }

    // 2. Strict key match in map
    for (final entry in _markedMachineAttendanceMap.entries) {
      final key = entry.key;
      if (key.length < 4 || key == 'n/a') continue;

      if (isMachineMatch(key, null)) {
        final rec = entry.value;
        final statusUpper = rec.status.toUpperCase();
        final isMarkedStatus =
            rec.checkInTime != null &&
            statusUpper != 'NOT_MARKED' &&
            statusUpper != 'NOT_CHECKED_IN' &&
            statusUpper != 'REJECTED' &&
            rec.approvalStatus != 'REJECTED';
        if (rec.checkInTime != null &&
            isSameDay(rec.checkInTime) &&
            isMarkedStatus)
          return rec;
      }
    }

    // 3. Active today record check
    if (_todayAttendance != null && _todayAttendance!.isMachineAttendance) {
      final t = _todayAttendance!;
      final matchesMachine = isMachineMatch(t.machineChassisNo, t.machineId);

      final statusUpper = t.status.toUpperCase();
      final isMarkedStatus =
          t.checkInTime != null &&
          statusUpper != 'NOT_MARKED' &&
          statusUpper != 'NOT_CHECKED_IN' &&
          statusUpper != 'REJECTED' &&
          t.approvalStatus != 'REJECTED';

      if (matchesMachine &&
          t.checkInTime != null &&
          isSameDay(t.checkInTime) &&
          isMarkedStatus) {
        return t;
      }
    }

    // 4. Strict history check
    for (final record in _history) {
      if (!record.isMachineAttendance) continue;

      final matchesMachine = isMachineMatch(
        record.machineChassisNo,
        record.machineId,
      );
      final checkInTime = record.checkInTime;
      final statusUpper = record.status.toUpperCase();
      final isMarkedStatus =
          checkInTime != null &&
          statusUpper != 'NOT_MARKED' &&
          statusUpper != 'NOT_CHECKED_IN' &&
          statusUpper != 'REJECTED' &&
          record.approvalStatus != 'REJECTED';

      if (matchesMachine &&
          checkInTime != null &&
          isSameDay(checkInTime) &&
          isMarkedStatus) {
        return record;
      }
    }

    return null;
  }

  /// Sync any pending offline attendance records with server
  Future<int> syncPendingAttendance() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    try {
      final count = await repository.syncPendingRecords();
      if (count > 0) {
        _infoMessage =
            'Successfully synced $count offline attendance record(s) with server.';
        await fetchHistory();
        await fetchTodayAttendance();
      }
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceController] Sync error: $e');
      }
      return 0;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Load today's attendance record
  Future<void> fetchTodayAttendance() async {
    _isLoadingToday = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todayAttendance = await repository.getTodayAttendance();
      if (_todayAttendance != null) {
        _registerTeamAttendanceRecord(_todayAttendance!);
      }
      await _syncLocalTeamRecords();
      _isLoadingToday = false;
      notifyListeners();
      syncPendingAttendance();
    } catch (e) {
      _isLoadingToday = false;
      if (kDebugMode) {
        print('[AttendanceController] Fetch today error: $e');
      }
      notifyListeners();
    }
  }

  /// Fetch machines assigned to current user
  Future<void> fetchAssignedMachines() async {
    _isLoadingToday = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = AuthStorageService().currentUser;
      _assignedMachines = await repository.getAssignedMachines(user?.id ?? '1');
      await _syncLocalTeamRecords();
      _isLoadingToday = false;
      notifyListeners();
    } catch (e) {
      _isLoadingToday = false;
      _errorMessage = 'Unable to load assigned machines.';
      notifyListeners();
    }
  }

  /// Load only the machines the HERO web attendance roster associates with
  /// the selected team attendance date.
  Future<void> fetchTeamAttendanceMachines() async {
    _isLoadingToday = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = AuthStorageService().currentUser;
      _assignedMachines = await repository.getTeamAttendanceMachines(
        user?.id ?? '1',
      );
      await _syncLocalTeamRecords();
      _isLoadingToday = false;
      notifyListeners();
    } catch (e) {
      _isLoadingToday = false;
      _errorMessage = 'Unable to load attendance machines.';
      notifyListeners();
    }
  }

  /// Fetch authorized team members for supervisor
  Future<void> fetchAuthorizedTeamMembers() async {
    _isLoadingHistory = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = AuthStorageService().currentUser;
      _teamMembers = await repository.getAuthorizedTeamMembers(user?.id ?? '1');
      await _syncLocalTeamRecords();
      _isLoadingHistory = false;
      notifyListeners();
    } catch (e) {
      _isLoadingHistory = false;
      _errorMessage = 'Unable to load authorized team members.';
      notifyListeners();
    }
  }

  /// Toggle Test Location mode
  void setUseTestLocation(bool val) {
    _useTestLocation = val;
    _locationSource = val ? 'TEST_LOCATION' : 'GPS';
    notifyListeners();
    captureFreshLocation();
  }

  /// Get Fresh GPS Position or Test Location
  Future<bool> captureFreshLocation() async {
    _errorMessage = null;
    _infoMessage = _useTestLocation
        ? 'Using Test Location (28.6139, 77.2090)...'
        : 'Obtaining high-accuracy GPS position...';
    notifyListeners();

    try {
      final locResult = await locationService.getAccurateLocationForAttendance(
        useTestLocation: _useTestLocation,
      );

      _capturedLocation = AttendanceLocation(
        latitude: locResult.latitude,
        longitude: locResult.longitude,
        accuracy: locResult.accuracy,
        timestamp: DateTime.now(),
        isMocked: locResult.isMocked,
      );

      _locationSource = locResult.source;
      _infoMessage = null;

      if (!_useTestLocation && locResult.accuracy > maxLocationAccuracyMeters) {
        _infoMessage =
            'GPS accuracy is ±${locResult.accuracy.toStringAsFixed(1)}m.';
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage =
          'Unable to capture your current location. Please enable location services and try again.';
      _infoMessage = null;
      notifyListeners();
      return false;
    }
  }

  /// Open camera and capture attendance photo.
  Future<bool> captureAttendancePhoto({bool requireFace = false}) async {
    _errorMessage = null;
    _infoMessage = null;
    _faceVerified = false;
    _faceRejectionMessage = null;
    notifyListeners();

    try {
      final XFile? photo = await cameraService.capturePhoto();

      if (photo == null) {
        _errorMessage = 'Photo capture was cancelled.';
        notifyListeners();
        return false;
      }

      if (!requireFace) {
        _capturedPhoto = photo;
        _capturedPhotoPath = photo.path;
        _capturedPhotoBytes = await photo.readAsBytes();
        _faceVerified = false;
        _faceRejectionMessage = null;
        _errorMessage = null;
        _infoMessage = 'Photo captured successfully.';
        notifyListeners();
        return true;
      }

      _isVerifyingFace = true;
      notifyListeners();

      final validation = await faceDetectionService.validateAttendanceSelfie(
        photo.path,
      );

      _isVerifyingFace = false;

      if (!validation.isValid) {
        _capturedPhoto = null;
        _capturedPhotoPath = null;
        _capturedPhotoBytes = null;
        _faceVerified = false;
        _faceRejectionMessage =
            validation.message ??
            'No face detected. Please look at the camera and retake a clear selfie.';
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      _capturedPhoto = photo;
      _capturedPhotoPath = photo.path;
      _capturedPhotoBytes = await photo.readAsBytes();
      _faceVerified = true;
      _faceRejectionMessage = null;
      _errorMessage = null;
      _infoMessage = 'Face verified successfully.';
      notifyListeners();
      return true;
    } catch (e) {
      _isVerifyingFace = false;
      _faceVerified = false;
      _capturedPhoto = null;
      _capturedPhotoPath = null;
      _capturedPhotoBytes = null;
      _faceRejectionMessage = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Burns lat/lng + phone onto the captured photo for proof
  Future<bool> stampCapturedPhotoProof({required String phoneNumber}) async {
    if (_capturedPhotoBytes == null || _capturedPhotoBytes!.isEmpty) {
      return false;
    }

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      return false;
    }

    try {
      final stamped = await photoStampService.stampProof(
        imageBytes: _capturedPhotoBytes!,
        latitude: _capturedLocation!.latitude,
        longitude: _capturedLocation!.longitude,
        phoneNumber: phoneNumber,
      );
      _capturedPhotoBytes = stamped;
      _capturedPhotoPath = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceController] Photo stamp error: $e');
      }
      return false;
    }
  }

  Future<bool> _ensurePhotoCapturedForSubmit() async {
    if (_capturedPhotoBytes == null || _capturedPhotoBytes!.isEmpty) {
      _errorMessage = 'Please capture an attendance photo before submitting.';
      _faceRejectionMessage = null;
      notifyListeners();
      return false;
    }
    return true;
  }

  void resetCaptureState() {
    _capturedPhoto = null;
    _capturedPhotoBytes = null;
    _capturedPhotoPath = null;
    _capturedLocation = null;
    _faceVerified = false;
    _faceRejectionMessage = null;
    _isVerifyingFace = false;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  // ============================================================================
  // NETINFRA TASK MUSTER API FLOW
  // ============================================================================

  /// Task Attendance Submission Flow routing directly to Pramaanu REST API
  Future<bool> markTaskMusterAttendance({
    required String taskId,
    String? teamSource,
    String? vendorId,
    String? vendorName,
    String? targetUserId,
    Machine? machine,
    String? stepUpToken,
  }) async {
    if (machine != null) {
      return submitMachineCheckIn(machine);
    }
    if (targetUserId != null && targetUserId.isNotEmpty) {
      final user = UserModel(
        id: targetUserId,
        username: targetUserId,
        email: '',
      );
      return submitTeamCheckIn(user);
    }
    return submitCheckIn();
  }

  /// Submit Machine Attendance Transaction
  Future<bool> submitMachineCheckIn(Machine machine) async {
    if (_selectedTaskId != null && _selectedTaskId!.isNotEmpty) {
      return markTaskMusterAttendance(
        taskId: _selectedTaskId!,
        machine: machine,
      );
    }

    if (_isSubmitting) return false;

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage =
          'Unable to capture your current location. Please enable location services and try again.';
      notifyListeners();
      return false;
    }

    if (!await _ensurePhotoCapturedForSubmit()) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final record = await repository.checkInMachine(
        machine: machine,
        latitude: _capturedLocation!.latitude,
        longitude: _capturedLocation!.longitude,
        accuracy: _capturedLocation!.accuracy,
        locationSource: _locationSource,
        photoBytes: _capturedPhotoBytes,
        photoFilename: _capturedPhoto?.name ?? 'machine_check_in.jpg',
      );

      _registerTeamAttendanceRecord(record);
      if (machine.chassisNumber.isNotEmpty) {
        _markedMachineAttendanceMap[machine.chassisNumber
                .trim()
                .toLowerCase()] =
            record;
      }
      if (machine.machineChassisNo.isNotEmpty) {
        _markedMachineAttendanceMap[machine.machineChassisNo
                .trim()
                .toLowerCase()] =
            record;
      }
      await AttendanceStorageService().saveRecord(record);

      if (_todayAttendance == null || _todayAttendance!.isMachineAttendance) {
        _todayAttendance = record;
      }
      if (!record.isSynced) {
        _infoMessage =
            'Attendance saved offline due to poor network. It will automatically sync when connected.';
      }
      _isSubmitting = false;
      notifyListeners();

      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();
      fetchHistory();
      fetchPendingApprovals();

      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Submit Team Attendance Transaction
  Future<bool> submitTeamCheckIn(UserModel targetMember) async {
    if (_selectedTaskId != null && _selectedTaskId!.isNotEmpty) {
      return markTaskMusterAttendance(
        taskId: _selectedTaskId!,
        targetUserId: targetMember.id,
      );
    }

    if (_isSubmitting) return false;

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage =
          'Unable to capture your current location. Please enable location services and try again.';
      notifyListeners();
      return false;
    }

    if (!await _ensurePhotoCapturedForSubmit()) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final record = await repository.checkInTeamMember(
        targetMember: targetMember,
        latitude: _capturedLocation!.latitude,
        longitude: _capturedLocation!.longitude,
        accuracy: _capturedLocation!.accuracy,
        locationSource: _locationSource,
        photoBytes: _capturedPhotoBytes,
        photoFilename: _capturedPhoto?.name ?? 'team_check_in.jpg',
      );

      _registerTeamAttendanceRecord(record);
      await AttendanceStorageService().saveRecord(record);

      _todayAttendance = record;
      if (!record.isSynced) {
        _infoMessage =
            'Attendance saved offline due to poor network. It will automatically sync when connected.';
      }
      _isSubmitting = false;
      notifyListeners();

      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();
      fetchHistory();
      fetchPendingApprovals();

      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Submit Check-In Transaction
  Future<bool> submitCheckIn() async {
    if (_selectedTaskId != null && _selectedTaskId!.isNotEmpty) {
      return markTaskMusterAttendance(taskId: _selectedTaskId!);
    }

    if (_isSubmitting) return false;

    if (_todayAttendance != null &&
        _todayAttendance!.status != 'NOT_CHECKED_IN' &&
        _todayAttendance!.status != 'REJECTED' &&
        _todayAttendance!.isCheckedIn) {
      _errorMessage = 'Attendance has already been marked for today.';
      notifyListeners();
      return false;
    }

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage =
          'Unable to capture your current location. Please enable location services and try again.';
      notifyListeners();
      return false;
    }

    if (!await _ensurePhotoCapturedForSubmit()) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newAttendance = await repository.checkIn(
        latitude: _capturedLocation!.latitude,
        longitude: _capturedLocation!.longitude,
        accuracy: _capturedLocation!.accuracy,
        locationSource: _locationSource,
        photoBytes: _capturedPhotoBytes,
        photoFilename: _capturedPhoto?.name ?? 'check_in.jpg',
      );

      _registerTeamAttendanceRecord(newAttendance);
      await AttendanceStorageService().saveRecord(newAttendance);

      _todayAttendance = newAttendance;
      if (!newAttendance.isSynced) {
        _infoMessage =
            'Attendance saved offline due to poor network. It will automatically sync when connected.';
      }
      _isSubmitting = false;
      notifyListeners();

      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();
      fetchHistory();
      fetchPendingApprovals();

      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Submit Check-Out Transaction
  Future<bool> submitCheckOut() async {
    if (_isSubmitting) return false;

    var attId = _todayAttendance?.id;
    if (attId == null || attId.isEmpty) {
      await fetchTodayAttendance();
      attId = _todayAttendance?.id;
    }
    if (attId == null || attId.isEmpty) {
      attId = 'ATT_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage =
          'Unable to capture your current location. Please enable location services and try again.';
      notifyListeners();
      return false;
    }

    if (!await _ensurePhotoCapturedForSubmit()) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedAttendance = await repository.checkOut(
        attendanceId: attId,
        latitude: _capturedLocation!.latitude,
        longitude: _capturedLocation!.longitude,
        accuracy: _capturedLocation!.accuracy,
        locationSource: _locationSource,
        photoBytes: _capturedPhotoBytes,
        photoFilename: _capturedPhoto?.name ?? 'check_out.jpg',
      );

      _registerTeamAttendanceRecord(updatedAttendance);
      await AttendanceStorageService().saveRecord(updatedAttendance);

      _todayAttendance = updatedAttendance;
      if (!updatedAttendance.isSynced) {
        _infoMessage =
            'Attendance saved offline due to poor network. It will automatically sync when connected.';
      }
      _isSubmitting = false;
      notifyListeners();

      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();
      fetchHistory();
      fetchPendingApprovals();

      return true;
    } catch (e) {
      _isSubmitting = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Fetch User Attendance History Timeline
  Future<void> fetchHistory({int page = 0, String? statusFilter}) async {
    _isLoadingHistory = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _history = await repository.getHistory(
        page: page,
        statusFilter: statusFilter,
      );
      for (final item in _history) {
        _registerTeamAttendanceRecord(item);
      }
      await _syncLocalTeamRecords();
      _isLoadingHistory = false;
      notifyListeners();
    } catch (e) {
      _isLoadingHistory = false;
      if (kDebugMode) {
        print('[AttendanceController] Fetch history error: $e');
      }
      notifyListeners();
    }
  }

  /// Fetch Pending Team Approvals
  Future<void> fetchPendingApprovals({int page = 0}) async {
    _isLoadingApprovals = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _pendingApprovals = await repository.getPendingApprovals(page: page);
      _pendingMusterApprovals = await repository.getPendingMusterApprovals();
      _isLoadingApprovals = false;
      notifyListeners();
    } catch (e) {
      _isLoadingApprovals = false;
      if (kDebugMode) {
        print('[AttendanceController] Fetch pending approvals error: $e');
      }
      notifyListeners();
    }
  }

  /// Manager Approves Attendance Record
  Future<bool> approveAttendance(
    String attendanceId, {
    String remarks = 'Attendance approved',
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await repository.approveAttendance(attendanceId);
      if (!success) {
        await repository.approveMuster(attendanceId, remarks: remarks);
      }

      _pendingApprovals.removeWhere((item) => item.id == attendanceId);
      _pendingMusterApprovals.removeWhere((m) => m.id == attendanceId);

      final index = _history.indexWhere((item) => item.id == attendanceId);
      if (index != -1) {
        final old = _history[index];
        final updated = AttendanceModel(
          id: old.id,
          userId: old.userId,
          userName: old.userName,
          employeeId: old.employeeId,
          attendanceType: old.attendanceType,
          markedForUserId: old.markedForUserId,
          markedForUserName: old.markedForUserName,
          markedByUserId: old.markedByUserId,
          markedByUserName: old.markedByUserName,
          reportingManagerId: old.reportingManagerId,
          reportingManagerName: old.reportingManagerName,
          status: 'APPROVED',
          checkInTime: old.checkInTime,
          checkOutTime: old.checkOutTime,
          checkInLat: old.checkInLat,
          checkInLng: old.checkInLng,
          checkInAccuracy: old.checkInAccuracy,
          checkInPhotoUrl: old.checkInPhotoUrl,
          locationSource: old.locationSource,
          approvalStatus: 'APPROVED',
          machineChassisNo: old.machineChassisNo,
          machineId: old.machineId,
          createdAt: old.createdAt,
        );
        _registerTeamAttendanceRecord(updated);
        await AttendanceStorageService().saveRecord(updated);
      }
      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Manager Rejects Attendance Record
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    _errorMessage = null;
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      _errorMessage = 'Please provide a valid rejection reason.';
      notifyListeners();
      return false;
    }

    notifyListeners();

    try {
      final success = await repository.rejectAttendance(
        attendanceId,
        cleanReason,
      );
      if (!success) {
        await repository.rejectMuster(attendanceId, reason: cleanReason);
      }

      _pendingApprovals.removeWhere((item) => item.id == attendanceId);
      _pendingMusterApprovals.removeWhere((m) => m.id == attendanceId);

      final index = _history.indexWhere((item) => item.id == attendanceId);
      if (index != -1) {
        final old = _history[index];
        final updated = AttendanceModel(
          id: old.id,
          userId: old.userId,
          userName: old.userName,
          employeeId: old.employeeId,
          attendanceType: old.attendanceType,
          markedForUserId: old.markedForUserId,
          markedForUserName: old.markedForUserName,
          markedByUserId: old.markedByUserId,
          markedByUserName: old.markedByUserName,
          reportingManagerId: old.reportingManagerId,
          reportingManagerName: old.reportingManagerName,
          status: 'REJECTED',
          checkInTime: old.checkInTime,
          checkOutTime: old.checkOutTime,
          checkInLat: old.checkInLat,
          checkInLng: old.checkInLng,
          checkInAccuracy: old.checkInAccuracy,
          checkInPhotoUrl: old.checkInPhotoUrl,
          locationSource: old.locationSource,
          approvalStatus: 'REJECTED',
          rejectionReason: cleanReason,
          machineChassisNo: old.machineChassisNo,
          machineId: old.machineId,
          createdAt: old.createdAt,
        );
        _registerTeamAttendanceRecord(updated);
        await AttendanceStorageService().saveRecord(updated);
      }
      fetchTodayAttendance();
      fetchAuthorizedTeamMembers();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}

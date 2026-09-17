import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/attendance_location.dart';
import '../../../models/attendance_model.dart';
import '../../../models/machine.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_storage_service.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../services/attendance_storage_service.dart';
import '../../../services/camera_service.dart';
import '../../../services/face_detection_service.dart';
import '../../../services/location_service.dart';

/// State Controller managing Attendance Check-In/Out workflow, Machine Attendance, Team Attendance,
/// Location/GPS Validation, Camera Capture with face verification, History timeline, and Persistence.
class AttendanceController extends ChangeNotifier {
  final AttendanceRepository repository;
  final LocationService locationService;
  final AttendanceCameraService cameraService;
  final AttendanceFaceDetectionService faceDetectionService;

  static const double maxLocationAccuracyMeters = 50.0;

  bool _isLoadingToday = true;
  bool _isSubmitting = false;
  bool _isVerifyingFace = false;
  bool _isLoadingHistory = false;
  bool _isLoadingApprovals = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _faceVerified = false;
  String? _faceRejectionMessage;

  AttendanceModel? _todayAttendance;

  // Machine Attendance & Team Attendance Lists
  List<Machine> _assignedMachines = [];
  List<UserModel> _teamMembers = [];

  // In-memory cache for today's marked team/machine attendance records
  final Map<String, AttendanceModel> _markedTeamAttendanceMap = {};

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
  bool _isDisposed = false;

  AttendanceController({
    AttendanceRepository? repository,
    LocationService? locationService,
    AttendanceCameraService? cameraService,
    AttendanceFaceDetectionService? faceDetectionService,
  })  : repository = repository ?? ApiAttendanceRepository(),
        locationService = locationService ?? AppLocationService(),
        cameraService = cameraService ?? AttendanceCameraService(),
        faceDetectionService =
            faceDetectionService ?? AttendanceFaceDetectionService();

  @override
  void notifyListeners() {
    if (_isDisposed) return;

    // Avoid "setState()/markNeedsBuild() called during build" when fetch*
    // methods are triggered from initState while a ListenableBuilder is mounting.
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
    faceDetectionService.dispose();
    super.dispose();
  }

  // Getters
  bool get isLoadingToday => _isLoadingToday;
  bool get isSubmitting => _isSubmitting;
  bool get isVerifyingFace => _isVerifyingFace;
  bool get isFaceVerified => _faceVerified;
  String? get faceRejectionMessage => _faceRejectionMessage;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingApprovals => _isLoadingApprovals;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

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

  void _registerTeamAttendanceRecord(AttendanceModel record) {
    final now = DateTime.now();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == now.year && local.month == now.month && local.day == now.day;
    }

    final dt = record.checkInTime ?? record.createdAt;
    if (!isSameDay(dt)) return;

    if (record.userId.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.userId.trim().toLowerCase()] = record;
    }
    if (record.markedForUserId != null && record.markedForUserId!.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.markedForUserId!.trim().toLowerCase()] = record;
    }
    if (record.employeeId != null && record.employeeId!.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.employeeId!.trim().toLowerCase()] = record;
    }
    if (record.userName.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.userName.trim().toLowerCase()] = record;
    }
    if (record.machineChassisNo != null && record.machineChassisNo!.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.machineChassisNo!.trim().toLowerCase()] = record;
    }
    if (record.machineId != null && record.machineId!.trim().isNotEmpty) {
      _markedTeamAttendanceMap[record.machineId!.trim().toLowerCase()] = record;
    }

    _history.removeWhere((item) => item.id == record.id);
    _history.insert(0, record);
  }

  Future<void> _syncLocalTeamRecords() async {
    try {
      final localRecords = await AttendanceStorageService().getAllRecords();
      final now = DateTime.now();
      for (final rec in localRecords) {
        final dt = rec.checkInTime ?? rec.createdAt;
        if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          _registerTeamAttendanceRecord(rec);
        }
      }
    } catch (_) {}
  }

  /// Returns today's active attendance record for a specific team member or user ID, if any.
  AttendanceModel? getTodayAttendanceForUser(String targetUserId, {String? employeeId, String? userName}) {
    final now = DateTime.now();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == now.year && local.month == now.month && local.day == now.day;
    }

    final idClean = targetUserId.trim().toLowerCase();
    final empClean = employeeId?.trim().toLowerCase() ?? '';
    final nameClean = userName?.trim().toLowerCase() ?? '';

    // 1. Check in-memory map first
    if (idClean.isNotEmpty && _markedTeamAttendanceMap.containsKey(idClean)) {
      final rec = _markedTeamAttendanceMap[idClean]!;
      if (isSameDay(rec.checkInTime ?? rec.createdAt)) return rec;
    }
    if (empClean.isNotEmpty && _markedTeamAttendanceMap.containsKey(empClean)) {
      final rec = _markedTeamAttendanceMap[empClean]!;
      if (isSameDay(rec.checkInTime ?? rec.createdAt)) return rec;
    }
    if (nameClean.isNotEmpty && _markedTeamAttendanceMap.containsKey(nameClean)) {
      final rec = _markedTeamAttendanceMap[nameClean]!;
      if (isSameDay(rec.checkInTime ?? rec.createdAt)) return rec;
    }

    // 2. Check todayAttendance
    if (_todayAttendance != null) {
      final t = _todayAttendance!;
      final matchesUser = (t.userId.toLowerCase().trim() == idClean) ||
          (t.markedForUserId != null && t.markedForUserId!.toLowerCase().trim() == idClean) ||
          (empClean.isNotEmpty && t.employeeId != null && t.employeeId!.toLowerCase().trim() == empClean) ||
          (nameClean.isNotEmpty && t.userName.toLowerCase().trim() == nameClean);

      final isMarkedStatus = t.status != 'NOT_CHECKED_IN' && t.status != 'REJECTED' && t.approvalStatus != 'REJECTED';

      if (matchesUser && isSameDay(t.checkInTime ?? t.createdAt) && isMarkedStatus) {
        return t;
      }
    }

    // 3. Check history records
    for (final record in _history) {
      final matchesUser = (record.userId.toLowerCase().trim() == idClean) ||
          (record.markedForUserId != null && record.markedForUserId!.toLowerCase().trim() == idClean) ||
          (empClean.isNotEmpty && record.employeeId != null && record.employeeId!.toLowerCase().trim() == empClean) ||
          (nameClean.isNotEmpty && record.userName.toLowerCase().trim() == nameClean);

      final recordDate = record.checkInTime ?? record.createdAt;
      final isMarkedStatus = record.status != 'NOT_CHECKED_IN' && record.status != 'REJECTED' && record.approvalStatus != 'REJECTED';

      if (matchesUser && isSameDay(recordDate) && isMarkedStatus) {
        return record;
      }
    }

    return null;
  }

  /// Returns today's active attendance record for a specific machine chassis number, if any.
  AttendanceModel? getTodayAttendanceForMachine(String chassisNo) {
    final now = DateTime.now();
    bool isSameDay(DateTime? dt) {
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == now.year && local.month == now.month && local.day == now.day;
    }

    final chassisLower = chassisNo.toLowerCase().trim();

    if (chassisLower.isNotEmpty && _markedTeamAttendanceMap.containsKey(chassisLower)) {
      final rec = _markedTeamAttendanceMap[chassisLower]!;
      if (isSameDay(rec.checkInTime ?? rec.createdAt)) return rec;
    }

    if (_todayAttendance != null) {
      final t = _todayAttendance!;
      final matchesMachine = (t.machineChassisNo != null && t.machineChassisNo!.toLowerCase().trim() == chassisLower) ||
          (t.machineId != null && t.machineId!.toLowerCase().trim() == chassisLower);
      final isMarkedStatus = t.status != 'NOT_CHECKED_IN' && t.status != 'REJECTED' && t.approvalStatus != 'REJECTED';

      if (matchesMachine && isSameDay(t.checkInTime ?? t.createdAt) && isMarkedStatus) {
        return t;
      }
    }

    for (final record in _history) {
      final matchesMachine = (record.machineChassisNo != null && record.machineChassisNo!.toLowerCase().trim() == chassisLower) ||
          (record.machineId != null && record.machineId!.toLowerCase().trim() == chassisLower);
      final recordDate = record.checkInTime ?? record.createdAt;
      final isMarkedStatus = record.status != 'NOT_CHECKED_IN' && record.status != 'REJECTED' && record.approvalStatus != 'REJECTED';

      if (matchesMachine && isSameDay(recordDate) && isMarkedStatus) {
        return record;
      }
    }

    return null;
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
      final locResult = await locationService.getCurrentLocation(
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
        _infoMessage = 'GPS accuracy is ±${locResult.accuracy.toStringAsFixed(1)}m.';
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _infoMessage = null;
      notifyListeners();
      return false;
    }
  }

  /// Open camera and capture attendance photo.
  /// When [requireFace] is true (team attendance), rejects photos without a valid face.
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

      final validation =
          await faceDetectionService.validateAttendanceSelfie(photo.path);

      _isVerifyingFace = false;

      if (!validation.isValid) {
        _capturedPhoto = null;
        _capturedPhotoPath = null;
        _capturedPhotoBytes = null;
        _faceVerified = false;
        _faceRejectionMessage = validation.message ??
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

  /// Re-run face checks before team attendance submit.
  Future<bool> ensureFaceVerifiedForSubmit() async {
    if (_capturedPhotoPath == null ||
        _capturedPhotoBytes == null ||
        _capturedPhotoBytes!.isEmpty) {
      _faceRejectionMessage =
          'A clear face selfie is required for team attendance.';
      _errorMessage = null;
      _faceVerified = false;
      notifyListeners();
      return false;
    }

    _isVerifyingFace = true;
    _errorMessage = null;
    _faceRejectionMessage = null;
    notifyListeners();

    final validation =
        await faceDetectionService.validateAttendanceSelfie(_capturedPhotoPath!);

    _isVerifyingFace = false;

    if (!validation.isValid) {
      _faceVerified = false;
      _capturedPhoto = null;
      _capturedPhotoPath = null;
      _capturedPhotoBytes = null;
      _faceRejectionMessage = validation.message ??
          'No face detected. Please look at the camera and retake a clear selfie.';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _faceVerified = true;
    _faceRejectionMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> _ensurePhotoCapturedForSubmit() async {
    if (_capturedPhotoBytes == null || _capturedPhotoBytes!.isEmpty) {
      _errorMessage = 'Please capture an attendance photo before submitting.';
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Reset captured state for retaking photo / location
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

  /// Submit Machine Attendance Transaction
  Future<bool> submitMachineCheckIn(Machine machine) async {
    if (_isSubmitting) return false;

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage = 'Unable to determine location. Please capture location.';
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
      await AttendanceStorageService().saveRecord(record);

      _todayAttendance = record;
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

  /// Submit Team Attendance Transaction (for self or team member)
  Future<bool> submitTeamCheckIn(UserModel targetMember) async {
    if (_isSubmitting) return false;

    if (_capturedLocation == null) {
      await captureFreshLocation();
    }
    if (_capturedLocation == null) {
      _errorMessage = 'Unable to determine location. Please capture location.';
      notifyListeners();
      return false;
    }

    if (!await ensureFaceVerifiedForSubmit()) {
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
    if (_isSubmitting) return false;

    // Allow re-checking in if status is NOT_CHECKED_IN or REJECTED
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
      _errorMessage = 'Unable to determine your location. Please capture location before submitting.';
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
      _isSubmitting = false;
      notifyListeners();

      // Refresh today's attendance, team members, history & pending approvals from server
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
      _errorMessage = 'Unable to determine your location. Please capture location before submitting.';
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
      _history = await repository.getHistory(page: page, statusFilter: statusFilter);
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
  Future<bool> approveAttendance(String attendanceId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await repository.approveAttendance(attendanceId);
      if (success) {
        _pendingApprovals.removeWhere((item) => item.id == attendanceId);
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
      } else {
        _errorMessage = 'Unable to approve attendance. Please verify reporting manager permissions.';
      }
      notifyListeners();
      return success;
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
      final success = await repository.rejectAttendance(attendanceId, cleanReason);
      if (success) {
        _pendingApprovals.removeWhere((item) => item.id == attendanceId);
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
      } else {
        _errorMessage = 'Unable to reject attendance. Please verify reporting manager permissions.';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}

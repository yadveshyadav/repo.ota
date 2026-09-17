import '../features/auth/models/user_model.dart';
import '../features/auth/services/auth_storage_service.dart';
import '../services/authorization_service.dart';

/// Data model representing an employee or machine attendance transaction and approval state
class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String? employeeId;
  final String? reportingManagerId;
  final String? reportingManagerName;
  final String attendanceType; // 'MACHINE' or 'TEAM'
  final String? machineId;
  final String? machineChassisNo;
  final String? machineAssignmentId;
  final String? vendorId;
  final String? siteId;
  final String? markedForUserId;
  final String? markedForUserName;
  final String? markedByUserId;
  final String? markedByUserName;
  final String status; // PENDING, PRESENT, REJECTED, CHECKED_IN, CHECKED_OUT, NOT_CHECKED_IN
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkInAccuracy;
  final String? checkInPhotoUrl;
  final String? locationSource; // GPS or TEST_LOCATION
  final double? checkOutLat;
  final double? checkOutLng;
  final double? checkOutAccuracy;
  final String? checkOutPhotoUrl;
  final int? totalWorkingSeconds;
  final String? formattedWorkingHours;
  final String approvalStatus; // PENDING, APPROVED, REJECTED
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? createdAt;

  const AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.employeeId,
    this.reportingManagerId,
    this.reportingManagerName,
    this.attendanceType = 'TEAM',
    this.machineId,
    this.machineChassisNo,
    this.machineAssignmentId,
    this.vendorId,
    this.siteId,
    this.markedForUserId,
    this.markedForUserName,
    this.markedByUserId,
    this.markedByUserName,
    this.status = 'NOT_CHECKED_IN',
    this.checkInTime,
    this.checkOutTime,
    this.checkInLat,
    this.checkInLng,
    this.checkInAccuracy,
    this.checkInPhotoUrl,
    this.locationSource = 'GPS',
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutAccuracy,
    this.checkOutPhotoUrl,
    this.totalWorkingSeconds,
    this.formattedWorkingHours,
    this.approvalStatus = 'PENDING',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.createdAt,
  });

  bool get isMachineAttendance => attendanceType.toUpperCase() == 'MACHINE';
  bool get isTeamAttendance => attendanceType.toUpperCase() == 'TEAM';

  bool get isCheckedIn => status == 'CHECKED_IN' || (checkInTime != null && checkOutTime == null);
  bool get isCheckedOut => status == 'CHECKED_OUT' || (checkInTime != null && checkOutTime != null);
  bool get isPendingApproval => approvalStatus == 'PENDING';
  bool get isApproved => approvalStatus == 'APPROVED';
  bool get isRejected => approvalStatus == 'REJECTED';

  bool get isTestLocation => locationSource == 'TEST_LOCATION';
  String? get primaryImagePath => checkInPhotoUrl ?? checkOutPhotoUrl;
  double? get primaryLatitude => checkInLat ?? checkOutLat;
  double? get primaryLongitude => checkInLng ?? checkOutLng;

  String get displayStatus {
    if (isRejected) return 'Rejected';
    if (isApproved || status == 'PRESENT') return 'Approved';
    if (isPendingApproval || status == 'PENDING') return 'Pending Approval';
    if (isCheckedOut) return 'Checked Out';
    return 'Not Marked';
  }

  /// Checks if attendance record can be approved by [user] (Admin or assigned Reporting Manager)
  bool canBeApprovedBy(UserModel? user) {
    if (user == null) return false;

    // 1. Admin / Fleet Admin can approve ALL attendance records
    if (user.isAdmin || user.role.toUpperCase().contains('ADMIN')) {
      return true;
    }

    // 2. Assigned Reporting Manager if matching by ID or Name
    if (reportingManagerId != null && reportingManagerId!.isNotEmpty) {
      if (user.id == reportingManagerId) return true;
    }

    if (reportingManagerName != null && reportingManagerName!.isNotEmpty) {
      final nameLower = reportingManagerName!.toLowerCase().trim();
      if (user.displayName.toLowerCase().trim() == nameLower ||
          user.username.toLowerCase().trim() == nameLower ||
          user.name.toLowerCase().trim() == nameLower) {
        return true;
      }
    }

    // 3. Authorized Supervisors & Managers with attendance.approve permission
    return AuthorizationService.instance.can('attendance.approve');
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> source = json;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      source = json['data'] as Map<String, dynamic>;
    }

    var rawId = source['id'] ?? source['attendance_id'] ?? source['attendanceId'] ?? source['pk'] ?? '';
    if (rawId.toString().isEmpty) {
      rawId = 'ATT_${DateTime.now().millisecondsSinceEpoch}';
    }

    final currentUser = AuthStorageService().currentUser;
    final userObj = source['user'] is Map<String, dynamic> ? source['user'] as Map<String, dynamic> : null;
    final managerObj = source['reporting_manager'] is Map<String, dynamic>
        ? source['reporting_manager'] as Map<String, dynamic>
        : null;

    var uId = source['user_id']?.toString() ??
        source['userId']?.toString() ??
        userObj?['id']?.toString() ??
        '';
    if (uId.isEmpty && currentUser != null) {
      uId = currentUser.id;
    }

    var uName = source['user_name']?.toString() ??
        source['userName']?.toString() ??
        userObj?['name']?.toString() ??
        userObj?['username']?.toString() ??
        '';
    if (uName.isEmpty || uName == 'Employee') {
      if (currentUser != null && currentUser.displayName.isNotEmpty) {
        uName = currentUser.displayName;
      }
    }

    var managerName = source['reporting_manager_name']?.toString() ??
        source['reportingManagerName']?.toString() ??
        managerObj?['name']?.toString() ??
        '';
    if (managerName.isEmpty && currentUser != null && currentUser.reportingManagerName != null) {
      managerName = currentUser.reportingManagerName!;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    double? parseNum(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    var checkInDt = parseDate(source['check_in_time'] ?? source['checkInTime'] ?? source['checkin_time'] ?? source['created_at'] ?? source['createdAt']);
    final rawStatus = source['status']?.toString().toUpperCase() ?? 'NOT_CHECKED_IN';
    if (checkInDt == null && (rawStatus == 'CHECKED_IN' || rawStatus == 'PRESENT')) {
      checkInDt = DateTime.now();
    }

    final totalSec = source['total_working_seconds'] as int? ??
        source['totalWorkingSeconds'] as int? ??
        (source['working_seconds'] as int?);

    String? workingHrs = source['total_working_hours']?.toString() ??
        source['formattedWorkingHours']?.toString();

    if (workingHrs == null && totalSec != null && totalSec > 0) {
      final hrs = totalSec ~/ 3600;
      final mins = (totalSec % 3600) ~/ 60;
      workingHrs = '${hrs.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
    }

    return AttendanceModel(
      id: rawId.toString(),
      userId: uId,
      userName: uName,
      employeeId: source['employee_id']?.toString() ?? source['employeeId']?.toString() ?? userObj?['employee_id']?.toString() ?? currentUser?.employeeId,
      reportingManagerId: source['reporting_manager_id']?.toString() ?? managerObj?['id']?.toString() ?? currentUser?.reportingManagerId,
      reportingManagerName: managerName,
      attendanceType: source['attendance_type']?.toString().toUpperCase() ?? source['attendanceType']?.toString().toUpperCase() ?? 'TEAM',
      machineId: source['machine_id']?.toString() ?? source['machineId']?.toString(),
      machineChassisNo: source['machine_chassis_no']?.toString() ?? source['machineChassisNo']?.toString(),
      machineAssignmentId: source['machine_assignment_id']?.toString() ?? source['machineAssignmentId']?.toString(),
      vendorId: source['vendor_id']?.toString() ?? source['vendorId']?.toString(),
      siteId: source['site_id']?.toString() ?? source['siteId']?.toString(),
      markedForUserId: source['marked_for_user_id']?.toString() ?? source['markedForUserId']?.toString(),
      markedForUserName: source['marked_for_user_name']?.toString() ?? source['markedForUserName']?.toString(),
      markedByUserId: source['marked_by_user_id']?.toString() ?? source['markedByUserId']?.toString(),
      markedByUserName: source['marked_by_user_name']?.toString() ?? source['markedByUserName']?.toString(),
      status: rawStatus,
      checkInTime: checkInDt,
      checkOutTime: parseDate(source['check_out_time'] ?? source['checkOutTime']),
      checkInLat: parseNum(source['check_in_latitude'] ?? source['check_in_lat'] ?? source['latitude']),
      checkInLng: parseNum(source['check_in_longitude'] ?? source['check_in_lng'] ?? source['longitude']),
      checkInAccuracy: parseNum(source['check_in_accuracy'] ?? source['accuracy']),
      checkInPhotoUrl: source['check_in_photo']?.toString() ??
          source['checkInPhotoUrl']?.toString() ??
          source['check_in_photo_url']?.toString() ??
          source['check_in_photo_base64']?.toString() ??
          source['photo_base64']?.toString() ??
          source['photo']?.toString() ??
          source['photo_url']?.toString() ??
          source['photoUrl']?.toString() ??
          source['image']?.toString() ??
          source['image_url']?.toString() ??
          source['imageUrl']?.toString() ??
          source['imagePath']?.toString(),
      locationSource: source['location_source']?.toString() ?? source['locationSource']?.toString() ?? 'GPS',
      checkOutLat: parseNum(source['check_out_latitude'] ?? source['check_out_lat']),
      checkOutLng: parseNum(source['check_out_longitude'] ?? source['check_out_lng']),
      checkOutAccuracy: parseNum(source['check_out_accuracy']),
      checkOutPhotoUrl: source['check_out_photo']?.toString() ??
          source['checkOutPhotoUrl']?.toString() ??
          source['check_out_photo_url']?.toString() ??
          source['check_out_photo_base64']?.toString() ??
          source['photo']?.toString() ??
          source['photo_url']?.toString(),
      totalWorkingSeconds: totalSec,
      formattedWorkingHours: workingHrs,
      approvalStatus: source['approval_status']?.toString().toUpperCase() ?? source['approvalStatus']?.toString().toUpperCase() ?? 'PENDING',
      approvedBy: source['approved_by']?.toString() ?? source['approvedBy']?.toString(),
      approvedAt: parseDate(source['approved_at'] ?? source['approvedAt']),
      rejectionReason: source['rejection_reason']?.toString() ?? source['rejectionReason']?.toString(),
      createdAt: parseDate(source['created_at'] ?? source['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        if (employeeId != null) 'employee_id': employeeId,
        if (reportingManagerId != null) 'reporting_manager_id': reportingManagerId,
        if (reportingManagerName != null) 'reporting_manager_name': reportingManagerName,
        'attendance_type': attendanceType,
        if (machineId != null) 'machine_id': machineId,
        if (machineChassisNo != null) 'machine_chassis_no': machineChassisNo,
        if (machineAssignmentId != null) 'machine_assignment_id': machineAssignmentId,
        if (vendorId != null) 'vendor_id': vendorId,
        if (siteId != null) 'site_id': siteId,
        if (markedForUserId != null) 'marked_for_user_id': markedForUserId,
        if (markedForUserName != null) 'marked_for_user_name': markedForUserName,
        if (markedByUserId != null) 'marked_by_user_id': markedByUserId,
        if (markedByUserName != null) 'marked_by_user_name': markedByUserName,
        'status': status,
        if (checkInTime != null) 'check_in_time': checkInTime!.toIso8601String(),
        if (checkOutTime != null) 'check_out_time': checkOutTime!.toIso8601String(),
        if (checkInLat != null) 'check_in_latitude': checkInLat,
        if (checkInLng != null) 'check_in_longitude': checkInLng,
        if (checkInAccuracy != null) 'check_in_accuracy': checkInAccuracy,
        if (checkInPhotoUrl != null) 'check_in_photo': checkInPhotoUrl,
        'location_source': locationSource ?? 'GPS',
        if (checkOutLat != null) 'check_out_latitude': checkOutLat,
        if (checkOutLng != null) 'check_out_longitude': checkOutLng,
        if (checkOutAccuracy != null) 'check_out_accuracy': checkOutAccuracy,
        if (checkOutPhotoUrl != null) 'check_out_photo': checkOutPhotoUrl,
        if (totalWorkingSeconds != null) 'total_working_seconds': totalWorkingSeconds,
        if (formattedWorkingHours != null) 'total_working_hours': formattedWorkingHours,
        'approval_status': approvalStatus,
        if (approvedBy != null) 'approved_by': approvedBy,
        if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

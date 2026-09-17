import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/models/attendance_location.dart';
import 'package:hero_app/models/attendance_model.dart';
import 'package:hero_app/models/machine.dart';
import 'package:hero_app/repositories/attendance_repository.dart';

class MockAttendanceRepository implements AttendanceRepository {
  AttendanceModel? mockToday;
  final List<AttendanceModel> mockHistoryList = [];
  final List<AttendanceModel> mockPendingList = [];

  @override
  Future<AttendanceModel?> getTodayAttendance() async => mockToday;

  @override
  Future<List<Machine>> getAssignedMachines(String userId) async {
    return const [
      Machine(
        machineChassisNo: '600202608396',
        engineNo: 'TPHM106451',
        modelCode: 'A600',
        modelName: 'APOLLO A600 V2',
        siteName: 'Sujangarh-SITE',
        vendorName: 'Gurukripa Enterprises',
      ),
    ];
  }

  @override
  Future<List<UserModel>> getAuthorizedTeamMembers(String supervisorId) async {
    return const [
      UserModel(
        id: '101',
        username: 'john.doe',
        email: 'john@hero.com',
        name: 'John Doe',
        employeeId: 'EMP-101',
      ),
    ];
  }

  @override
  Future<AttendanceModel> checkInMachine({
    required Machine machine,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final newAtt = AttendanceModel(
      id: 'att_mach_101',
      userId: '254',
      userName: 'Mahaveer Operator',
      attendanceType: 'MACHINE',
      machineId: machine.machineChassisNo,
      machineChassisNo: machine.machineChassisNo,
      status: 'PENDING',
      checkInTime: DateTime.now(),
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      locationSource: locationSource,
      approvalStatus: 'PENDING',
    );
    mockToday = newAtt;
    return newAtt;
  }

  @override
  Future<AttendanceModel> checkInTeamMember({
    required UserModel targetMember,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final newAtt = AttendanceModel(
      id: 'att_team_101',
      userId: targetMember.id,
      userName: targetMember.displayName,
      attendanceType: 'TEAM',
      markedForUserId: targetMember.id,
      markedForUserName: targetMember.displayName,
      markedByUserId: 'supervisor_1',
      markedByUserName: 'Fleet Supervisor',
      status: 'PENDING',
      checkInTime: DateTime.now(),
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      locationSource: locationSource,
      approvalStatus: 'PENDING',
    );
    mockToday = newAtt;
    return newAtt;
  }

  @override
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final newAtt = AttendanceModel(
      id: 'att_101',
      userId: '254',
      userName: 'Papu Ram 2',
      status: 'CHECKED_IN',
      checkInTime: DateTime.now(),
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAccuracy: accuracy,
      checkInPhotoUrl: 'https://hero.com/photos/checkin_101.jpg',
      locationSource: locationSource,
      approvalStatus: 'PENDING',
    );
    mockToday = newAtt;
    return newAtt;
  }

  @override
  Future<AttendanceModel> checkOut({
    required String attendanceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String locationSource = 'GPS',
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    final updated = AttendanceModel(
      id: attendanceId,
      userId: '254',
      userName: 'Papu Ram 2',
      status: 'CHECKED_OUT',
      checkInTime: mockToday?.checkInTime ?? DateTime.now().subtract(const Duration(hours: 8)),
      checkOutTime: DateTime.now(),
      checkInLat: mockToday?.checkInLat ?? latitude,
      checkInLng: mockToday?.checkInLng ?? longitude,
      checkOutLat: latitude,
      checkOutLng: longitude,
      checkOutAccuracy: accuracy,
      checkOutPhotoUrl: 'https://hero.com/photos/checkout_101.jpg',
      totalWorkingSeconds: 28800,
      formattedWorkingHours: '08h 00m',
      approvalStatus: 'PENDING',
    );
    mockToday = updated;
    return updated;
  }

  @override
  Future<List<AttendanceModel>> getHistory({int page = 0, String? statusFilter}) async => mockHistoryList;

  @override
  Future<List<AttendanceModel>> getPendingApprovals({int page = 0}) async => mockPendingList;

  @override
  Future<bool> approveAttendance(String attendanceId) async {
    mockPendingList.removeWhere((a) => a.id == attendanceId);
    return true;
  }

  @override
  Future<bool> rejectAttendance(String attendanceId, String reason) async {
    mockPendingList.removeWhere((a) => a.id == attendanceId);
    return true;
  }
}

void main() {
  group('Attendance Model & Location DTO Tests', () {
    test('AttendanceLocation checks accuracy threshold correctly', () {
      final locGood = AttendanceLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 12.5,
        timestamp: DateTime.now(),
      );

      final locPoor = AttendanceLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 85.0,
        timestamp: DateTime.now(),
      );

      expect(locGood.isAccurateEnough(50.0), isTrue);
      expect(locPoor.isAccurateEnough(50.0), isFalse);
    });

    test('AttendanceModel parses JSON and calculates status getters', () {
      final json = {
        'id': 123,
        'user_id': 254,
        'user_name': 'Papu Ram 2',
        'attendance_type': 'MACHINE',
        'machine_chassis_no': '600202608396',
        'status': 'CHECKED_IN',
        'check_in_time': '2026-09-09T09:30:00Z',
        'check_in_latitude': 28.6139,
        'check_in_longitude': 77.2090,
        'check_in_accuracy': 15.0,
        'approval_status': 'PENDING',
      };

      final att = AttendanceModel.fromJson(json);

      expect(att.id, equals('123'));
      expect(att.userName, equals('Papu Ram 2'));
      expect(att.isMachineAttendance, isTrue);
      expect(att.machineChassisNo, equals('600202608396'));
      expect(att.isPendingApproval, isTrue);
    });
  });

  group('AttendanceController Unit Tests', () {
    late MockAttendanceRepository mockRepo;
    late AttendanceController controller;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockRepo = MockAttendanceRepository();
      controller = AttendanceController(repository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('fetchAssignedMachines populates operator assigned machines', () async {
      await controller.fetchAssignedMachines();

      expect(controller.assignedMachines.length, equals(1));
      expect(controller.assignedMachines.first.machineChassisNo, equals('600202608396'));
    });

    test('fetchAuthorizedTeamMembers populates supervisor team members', () async {
      await controller.fetchAuthorizedTeamMembers();

      expect(controller.teamMembers.length, equals(1));
      expect(controller.teamMembers.first.displayName, equals('John Doe'));
    });

    test('Manager approveAttendance removes record from pending approvals', () async {
      final pendingAtt = AttendanceModel(
        id: 'att_200',
        userId: '300',
        userName: 'Team Member A',
        status: 'CHECKED_OUT',
        approvalStatus: 'PENDING',
      );
      mockRepo.mockPendingList.add(pendingAtt);

      await controller.fetchPendingApprovals();
      expect(controller.pendingApprovals.length, equals(1));

      final approved = await controller.approveAttendance('att_200');

      expect(approved, isTrue);
      expect(controller.pendingApprovals, isEmpty);
    });

    test('Manager rejectAttendance requires non-empty reason', () async {
      final success = await controller.rejectAttendance('att_200', '   ');
      expect(success, isFalse);
      expect(controller.errorMessage, equals('Please provide a valid rejection reason.'));
    });
  });
}

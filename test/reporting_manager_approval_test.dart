import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/auth/models/auth_token.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/repositories/attendance_repository.dart';
import 'package:hero_app/services/attendance_storage_service.dart';
import 'package:hero_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAttendanceRepository repository;

  const mukeshUser = UserModel(
    id: '4',
    username: 'mukesh.panday',
    email: 'mukesh@hero.com',
    name: 'Mukesh Panday',
    employeeId: '6350491603',
    reportingManagerId: '254',
    reportingManagerName: 'Papu Ram 2',
    role: 'Field Employee',
    roles: ['EMPLOYEE'],
  );

  const managerPapu = UserModel(
    id: '254',
    username: 'papu.ram2',
    email: 'papu@hero.com',
    name: 'Papu Ram 2',
    employeeId: 'EMP-254',
    role: 'Supervisor',
    roles: ['SUPERVISOR'],
  );

  const managerUnrelated = UserModel(
    id: '300',
    username: 'unrelated.manager',
    email: 'manager300@hero.com',
    name: 'Unrelated Manager B',
    employeeId: 'EMP-300',
    role: 'Supervisor',
    roles: ['SUPERVISOR'],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AttendanceStorageService().clearAllRecords();
    await NotificationService().clearAll();
    repository = LocalAttendanceRepository();
  });

  group('Reporting Manager Attendance Routing & Approval Tests', () {
    test('TEST 1 & 2: Employee Mukesh submits attendance -> Status is PENDING with reportingManagerId=254', () async {
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_mukesh'),
        user: mukeshUser,
      );

      final attendance = await repository.checkIn(
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 12.0,
      );

      expect(attendance.approvalStatus, equals('PENDING'));
      expect(attendance.userId, equals('4'));
      expect(attendance.reportingManagerId, equals('254'));
      expect(attendance.reportingManagerName, equals('Papu Ram 2'));
    });

    test('TEST 3 & 4: Manager 254 sees Mukesh pending approval, Manager 300 does NOT see it', () async {
      // 1. Mukesh submits attendance
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_mukesh'),
        user: mukeshUser,
      );
      await repository.checkIn(latitude: 28.6139, longitude: 77.2090, accuracy: 12.0);

      // 2. Manager Papu (ID 254) logs in and checks pending approvals
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_papu'),
        user: managerPapu,
      );
      final papuPending = await repository.getPendingApprovals();
      expect(papuPending.length, equals(1));
      expect(papuPending.first.userName, equals('Mukesh Panday'));

      // 3. Unrelated Manager B (ID 300) logs in and checks pending approvals
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_manager300'),
        user: managerUnrelated,
      );
      final manager300Pending = await repository.getPendingApprovals();
      expect(manager300Pending, isEmpty);
    });

    test('TEST 5 & 6: Manager 254 approves attendance -> Status APPROVED & Employee Mukesh receives notification', () async {
      // 1. Mukesh submits attendance
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_mukesh'),
        user: mukeshUser,
      );
      final att = await repository.checkIn(latitude: 28.6139, longitude: 77.2090, accuracy: 12.0);

      // 2. Manager Papu approves attendance
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_papu'),
        user: managerPapu,
      );
      final approved = await repository.approveAttendance(att.id);
      expect(approved, isTrue);

      // 3. Verify notification generated specifically for employee Mukesh (ID 4)
      final notifications = NotificationService().getNotificationsForUser('4');
      expect(notifications.length, equals(1));
      expect(notifications.first.type, equals('ATTENDANCE_APPROVED'));
      expect(notifications.first.recipientId, equals('4'));
      expect(notifications.first.message, contains('approved by Papu Ram 2'));
    });

    test('TEST 7 & 8: Manager 254 rejects attendance -> Status REJECTED with reason & Employee Mukesh receives rejection notification', () async {
      // 1. Mukesh submits attendance
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_mukesh'),
        user: mukeshUser,
      );
      final att = await repository.checkIn(latitude: 28.6139, longitude: 77.2090, accuracy: 12.0);

      // 2. Manager Papu rejects attendance with reason
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_papu'),
        user: managerPapu,
      );
      final rejected = await repository.rejectAttendance(att.id, 'Photo is unclear');
      expect(rejected, isTrue);

      // 3. Verify rejection notification for employee Mukesh (ID 4)
      final notifications = NotificationService().getNotificationsForUser('4');
      expect(notifications.length, equals(1));
      expect(notifications.first.type, equals('ATTENDANCE_REJECTED'));
      expect(notifications.first.recipientId, equals('4'));
      expect(notifications.first.reason, equals('Photo is unclear'));
    });

    test('TEST 10: Employee attempts self-approval -> throws exception', () async {
      // Mukesh submits attendance
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_mukesh'),
        user: mukeshUser,
      );
      final att = await repository.checkIn(latitude: 28.6139, longitude: 77.2090, accuracy: 12.0);

      // Mukesh attempts to approve own attendance
      expect(() => repository.approveAttendance(att.id), throwsA(isA<Exception>()));
    });

    test('TEST 11: Rejection without reason throws exception', () async {
      await AuthStorageService().saveSession(
        token: const AuthToken(accessToken: 'token_papu'),
        user: managerPapu,
      );

      expect(() => repository.rejectAttendance('att_101', '   '), throwsA(isA<Exception>()));
    });
  });
}

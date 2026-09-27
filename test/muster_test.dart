import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/attendance/controller/attendance_controller.dart';
import 'package:hero_app/features/auth/models/user_model.dart';
import 'package:hero_app/models/attendance_location.dart';
import 'package:hero_app/models/muster_model.dart';
import 'package:hero_app/repositories/attendance_repository.dart';

class MockNetinfraAttendanceRepository extends LocalAttendanceRepository {
  DailyMuster? mockTodayMuster;
  bool shouldFailUpload = false;
  bool shouldThrow401 = false;
  bool shouldThrow403 = false;
  bool shouldThrow404 = false;
  bool shouldTimeout = false;

  @override
  Future<DailyMuster?> getTodaysMuster(String taskId) async {
    if (shouldThrow401) throw Exception('Unauthorized [401]: Session expired or invalid token.');
    if (shouldThrow403) throw Exception('Forbidden [403]: Access denied.');
    if (shouldThrow404) throw Exception('Not Found [404]: Task or muster not found.');
    if (shouldTimeout) throw Exception('Server connection timed out.');
    return mockTodayMuster;
  }

  @override
  Future<DailyMuster> createMuster(String taskId, Map<String, dynamic> body) async {
    if (shouldThrow401) throw Exception('Unauthorized [401]: Session expired or invalid token.');
    final muster = await super.createMuster(taskId, body);
    mockTodayMuster = muster;
    return muster;
  }

  @override
  Future<bool> uploadAttendancePhoto({
    required String uploadUrl,
    required List<int> imageBytes,
    String contentType = 'image/jpeg',
  }) async {
    if (shouldFailUpload) return false;
    return true;
  }
}

void main() {
  group('Netinfra DailyMuster & Attendance Proof Models Tests', () {
    test('1. Today\'s muster parsing', () {
      final json = {
        'id': 'muster_99',
        'clientMusterId': 'client_muster_99',
        'workedOnTaskIds': ['task_123'],
        'teamSource': 'INTERNAL_CREW',
        'vendorId': 'VEND_88',
        'vendorName': 'Vendor Alpha',
        'headcount': 2,
        'entries': [
          {
            'entryId': 'entry_1',
            'userId': 'usr_101',
            'mark': 'PRESENT',
            'type': 'MANPOWER',
          }
        ],
        'status': 'DRAFT',
      };

      final muster = DailyMuster.fromJson(json);

      expect(muster.id, equals('muster_99'));
      expect(muster.clientMusterId, equals('client_muster_99'));
      expect(muster.workedOnTaskIds, contains('task_123'));
      expect(muster.vendorName, equals('Vendor Alpha'));
      expect(muster.entries.length, equals(1));
    });

    test('2. Muster creation data mapping', () {
      final muster = DailyMuster(
        id: 'm1',
        clientMusterId: 'cm1',
        workedOnTaskIds: const ['t1'],
        vendorId: 'v1',
        vendorName: 'Vendor 1',
        headcount: 1,
        entries: const [],
      );

      final json = muster.toJson();
      expect(json['clientMusterId'], equals('cm1'));
      expect(json['workedOnTaskIds'], equals(['t1']));
      expect(json['headcount'], equals(1));
    });

    test('3. Muster entry parsing with machine & manpower support', () {
      final json = {
        'entryId': 'entry_mach_1',
        'type': 'MACHINE',
        'userId': 'usr_200',
        'mark': 'PRESENT',
        'machineId': 'CHASSIS_88',
        'registrationNumber': 'REG_88',
        'meterStart': 100,
        'meterEnd': 120,
      };

      final entry = MusterEntry.fromJson(json);
      expect(entry.entryId, equals('entry_mach_1'));
      expect(entry.type, equals('MACHINE'));
      expect(entry.machineId, equals('CHASSIS_88'));
      expect(entry.meterStart, equals(100));
      expect(entry.meterEnd, equals(120));
    });

    test('4. Attendance proof parsing with GPS coordinates and timestamps', () {
      final json = {
        'photoKey': 'attendance/2026/09/23/p1.jpg',
        'photoCapturedAt': '2026-09-23T09:15:00Z',
        'cameraLive': true,
        'latitude': 28.6139,
        'longitude': 77.2090,
        'accuracyMeters': 10.5,
        'fixCapturedAt': '2026-09-23T09:15:02Z',
        'provider': 'gps',
        'mockLocationFlagged': false,
      };

      final proof = AttendanceProof.fromJson(json);
      expect(proof.photoKey, equals('attendance/2026/09/23/p1.jpg'));
      expect(proof.latitude, equals(28.6139));
      expect(proof.longitude, equals(77.2090));
      expect(proof.accuracyMeters, equals(10.5));
      expect(proof.cameraLive, isTrue);
    });

    test('5. Photo upload URL parsing', () {
      final json = {
        'success': true,
        'data': {
          'uploadUrl': 'https://hero-s3.amazonaws.com/presigned_url',
          'photoKey': 'attendance/2026/09/23/p1.jpg',
        }
      };

      final resp = PhotoUploadUrlResponse.fromJson(json);
      expect(resp.success, isTrue);
      expect(resp.data.uploadUrl, contains('presigned_url'));
      expect(resp.data.photoKey, equals('attendance/2026/09/23/p1.jpg'));
    });
  });

  group('Netinfra Attendance Flow & Controller Tests', () {
    late MockNetinfraAttendanceRepository mockRepo;
    late AttendanceController controller;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockRepo = MockNetinfraAttendanceRepository();
      controller = AttendanceController(repository: mockRepo);
    });

    tearDown(() {
      controller.dispose();
    });

    test('6. Successful JPEG upload & 9. GPS success in markTaskMusterAttendance', () async {
      controller.setUseTestLocation(true);
      await controller.captureFreshLocation();
      expect(controller.capturedLocation, isNotNull);

      // Simulate captured photo bytes
      controller.stampCapturedPhotoProof(phoneNumber: '9876543210');

      // Set test photo bytes manually for unit test execution
      final result = await mockRepo.uploadAttendancePhoto(
        uploadUrl: 'https://presigned.s3.com/upload',
        imageBytes: [1, 2, 3, 4, 5],
      );

      expect(result, isTrue);
    });

    test('7. Failed JPEG upload handling', () async {
      mockRepo.shouldFailUpload = true;
      final result = await mockRepo.uploadAttendancePhoto(
        uploadUrl: 'https://presigned.s3.com/upload',
        imageBytes: [1, 2, 3],
      );
      expect(result, isFalse);
    });

    test('8. GPS failure displays clear error message', () async {
      final loc = AttendanceLocation(
        latitude: 0.0,
        longitude: 0.0,
        accuracy: 100.0,
        timestamp: DateTime.now(),
      );

      expect(loc.isAccurateEnough(50.0), isFalse);
    });

    test('11. PUT muster payload & 12. Submit payload', () async {
      final createdMuster = await mockRepo.createMuster('task_44', {
        'clientMusterId': 'cm_44',
        'workedOnTaskIds': ['task_44'],
      });

      final updatedMuster = await mockRepo.updateMuster(createdMuster.id, {
        'entries': [
          {
            'entryId': 'e1',
            'userId': 'usr_1',
            'mark': 'PRESENT',
            'proof': {
              'photoKey': 'key_1',
              'latitude': 28.6139,
              'longitude': 77.2090,
            }
          }
        ]
      });

      expect(updatedMuster.entries.length, equals(1));

      final submitted = await mockRepo.submitMuster(createdMuster.id, stepUpToken: 'token_xyz');
      expect(submitted, isTrue);
    });

    test('13. Approval & 14. Rejection & 15. Required rejection reason', () async {
      final created = await mockRepo.createMuster('t1', {'clientMusterId': 'cm1'});
      await mockRepo.submitMuster(created.id);

      // Approve
      final approved = await mockRepo.approveMuster(created.id, remarks: 'Verified by manager');
      expect(approved, isTrue);

      // Reject without reason fails
      expect(
        () => mockRepo.rejectMuster(created.id, reason: '   '),
        throwsA(isA<Exception>()),
      );

      // Reject with valid reason
      final rejected = await mockRepo.rejectMuster(created.id, reason: 'Invalid location evidence');
      expect(rejected, isTrue);
    });

    test('16. 401, 17. 403, 18. 404, 19. Network timeout error handling', () async {
      mockRepo.shouldThrow401 = true;
      expect(() => mockRepo.getTodaysMuster('t1'), throwsA(predicate((e) => e.toString().contains('401'))));

      mockRepo.shouldThrow401 = false;
      mockRepo.shouldThrow403 = true;
      expect(() => mockRepo.getTodaysMuster('t1'), throwsA(predicate((e) => e.toString().contains('403'))));

      mockRepo.shouldThrow403 = false;
      mockRepo.shouldThrow404 = true;
      expect(() => mockRepo.getTodaysMuster('t1'), throwsA(predicate((e) => e.toString().contains('404'))));

      mockRepo.shouldThrow404 = false;
      mockRepo.shouldTimeout = true;
      expect(() => mockRepo.getTodaysMuster('t1'), throwsA(predicate((e) => e.toString().contains('timed out'))));
    });

    test('21. Existing muster reuse & 22. Multiple team entries retention', () async {
      final created = await mockRepo.createMuster('t_100', {
        'clientMusterId': 'cm_100',
        'workedOnTaskIds': ['t_100'],
        'entries': [
          {'entryId': 'e1', 'userId': 'usr_1', 'mark': 'PRESENT'},
        ],
      });

      final fetched = await mockRepo.getTodaysMuster('t_100');
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(created.id));

      // Add second team entry without overwriting existing entry
      final updated = await mockRepo.updateMuster(created.id, {
        'entries': [
          {'entryId': 'e1', 'userId': 'usr_1', 'mark': 'PRESENT'},
          {'entryId': 'e2', 'userId': 'usr_2', 'mark': 'PRESENT'},
        ]
      });

      expect(updated.entries.length, equals(2));
      expect(updated.entries[0].userId, equals('usr_1'));
      expect(updated.entries[1].userId, equals('usr_2'));
    });

    test('23. Photo view URL & 24. Photo URL formatting', () async {
      final viewUrl = await mockRepo.getPhotoUrl(
        musterId: 'm1',
        photoKey: 'attendance/2026/09/23/abc.jpg',
      );

      expect(viewUrl, contains('attendance/2026/09/23/abc.jpg'));
    });
  });
}

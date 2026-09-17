import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/models/task_execution_model.dart';
import 'package:hero_app/models/task_media_model.dart';
import 'package:hero_app/models/task_model.dart';

void main() {
  group('DateParserUtils Unit Tests', () {
    test('Parses ISO-8601 string correctly', () {
      final dt = DateParserUtils.parse('2026-09-05T08:30:00.000Z');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 5);
    });

    test('Parses Unix timestamp in milliseconds and seconds correctly', () {
      final dtMs = DateParserUtils.parse(1788597000000);
      expect(dtMs, isNotNull);
      expect(dtMs!.year, 2026);

      final dtSec = DateParserUtils.parse(1788597000);
      expect(dtSec, isNotNull);
      expect(dtSec!.year, 2026);

      final dtStringMs = DateParserUtils.parse('1788597000000');
      expect(dtStringMs, isNotNull);
    });

    test('Handles null, empty, or malformed date inputs safely', () {
      expect(DateParserUtils.parse(null), isNull);
      expect(DateParserUtils.parse(''), isNull);
      expect(DateParserUtils.parse('invalid_date_string'), isNull);
      expect(DateParserUtils.parse('N/A'), isNull);
      expect(DateParserUtils.formatDisplay(null), 'N/A');
      expect(DateParserUtils.formatDisplay('invalid_date'), 'N/A');
    });
  });

  group('TaskMediaModel Unit Tests & Location Rules', () {
    test('Valid GPS coordinates format as lat, lng string', () {
      const media = TaskMediaModel(
        label: 'Depth Photo',
        photoUrl: 'https://example.com/photo.jpg',
        latitude: 26.850000,
        longitude: 74.380000,
      );

      expect(media.hasValidCoordinates, isTrue);
      expect(media.formattedLocation, '26.850000, 74.380000');
    });

    test('Null or 0.0 GPS coordinates strictly return "Location not available"', () {
      const mediaNull = TaskMediaModel(
        label: 'Photo without GPS',
        latitude: null,
        longitude: null,
      );
      expect(mediaNull.hasValidCoordinates, isFalse);
      expect(mediaNull.formattedLocation, 'Location not available');

      const mediaZero = TaskMediaModel(
        label: 'Photo with 0.0 coords',
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(mediaZero.hasValidCoordinates, isFalse);
      expect(mediaZero.formattedLocation, 'Location not available');
    });

    test('Parses json safely with missing or string photoUrl', () {
      final mediaFromJson = TaskMediaModel.fromJson({
        'title': 'Test Media',
        'url': 'https://example.com/test.png',
        'lat': '26.8500',
        'lng': '74.3800',
      });

      expect(mediaFromJson.label, 'Test Media');
      expect(mediaFromJson.photoUrl, 'https://example.com/test.png');
      expect(mediaFromJson.latitude, 26.85);
      expect(mediaFromJson.longitude, 74.38);
      expect(mediaFromJson.formattedLocation, '26.850000, 74.380000');
    });
  });

  group('TaskModel Master Data Parsing Tests', () {
    test('Parses full TaskModel json with snapshots safely', () {
      final json = {
        'id': 'task_6021',
        'taskCode': 'TASK-2026-99001',
        'displayName': 'Sujangarh Trenching Task',
        'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
        'status': 'IN_PROGRESS',
        'stage': 'EXECUTION',
        'approvalStatus': 'PENDING',
        'locationCode': 'LOC-001',
        'locationSnapshot': {
          'code': 'LOC-001',
          'name': 'Sujangarh Junction',
          'district': 'CHURU',
          'circle': 'RAJASTHAN',
          'blockName': 'SUJANGARH',
          'state': 'RAJASTHAN',
          'latitude': 27.7000,
          'longitude': 74.4600,
        },
        'assigneeSnapshot': {
          'id': 'usr_102',
          'name': 'Ramesh Sharma',
          'designation': 'Field Supervisor',
          'mobile': '9876543210',
        },
        'approverSnapshots': [
          {
            'id': 'usr_501',
            'name': 'Devesh Dubey',
            'role': 'Project Manager',
            'stepIndex': 1,
            'status': 'PENDING',
          }
        ],
        'totalLengthKm': 15.5,
        'coveredLengthKm': 5.2,
        'createdAt': '2026-09-01T10:00:00.000Z',
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 'task_6021');
      expect(task.taskCode, 'TASK-2026-99001');
      expect(task.displayName, 'Sujangarh Trenching Task');
      expect(task.locationName, 'Sujangarh Junction');
      expect(task.district, 'CHURU');
      expect(task.blockName, 'SUJANGARH');
      expect(task.assigneeName, 'Ramesh Sharma');
      expect(task.approverName, 'Devesh Dubey');
      expect(task.plannedScope, 15.5);
      expect(task.completedScope, 5.2);
      expect(task.remainingScope, 10.3);
      expect(task.createdAt, isNotNull);
    });

    test('Handles missing nested objects or null fields without throwing', () {
      final task = TaskModel.fromJson({});

      expect(task.id, '');
      expect(task.taskCode, 'TASK-00000');
      expect(task.displayName, 'Task');
      expect(task.locationName, 'Location');
      expect(task.district, 'N/A');
      expect(task.assigneeName, 'Unassigned');
      expect(task.approverName, 'Unassigned Supervisor');
      expect(task.plannedScope, 0.0);
      expect(task.completedScope, 0.0);
      expect(task.progress, 0.0);
      expect(task.createdAt, isNull);
    });
  });

  group('TaskExecutionModel Parsing Tests & Task ID Safety', () {
    test('Parses standalone TaskExecutionModel and preserves distinct TaskExecution.id vs Task.id', () {
      final json = {
        'id': 'exec_9901',
        'taskId': 'task_6021',
        'assigneeUserId': 'usr_102',
        'fieldData': {
          'surveyKind': 'GP_SURVEY',
          'currentStep': 'EXECUTING',
          'hindranceFound': false,
          'pitDetails': [
            {
              'pitId': 'pit_01',
              'pitName': 'Joint Chamber 01',
              'pitType': 'Standard',
              'depthMeters': 1.65,
              'latitude': 27.7000,
              'longitude': 74.4600,
            }
          ],
          'hddShot': [
            {
              'shotId': 'shot_01',
              'shotNumber': 1,
              'lengthMeters': 50.0,
              'depthMeters': 2.0,
              'pipeDiameterMm': 110.0,
            }
          ]
        }
      };

      final execution = TaskExecutionModel.fromJson(json);

      expect(execution.id, 'exec_9901');
      expect(execution.taskId, 'task_6021');
      expect(execution.id != execution.taskId, isTrue);

      final fieldData = execution.fieldData;
      expect(fieldData, isNotNull);
      expect(fieldData!.surveyKind, 'GP_SURVEY');
      expect(fieldData.pitDetails.length, 1);
      expect(fieldData.pitDetails.first.pitName, 'Joint Chamber 01');
      expect(fieldData.pitDetails.first.depthMeters, 1.65);

      expect(fieldData.hddShot.length, 1);
      expect(fieldData.hddShot.first.lengthMeters, 50.0);
      expect(fieldData.hddShot.first.pipeDiameterMm, 110.0);
    });

    test('Handles empty pitDetails and empty hddShot gracefully', () {
      final json = {
        'id': 'exec_9902',
        'taskId': 'task_6022',
        'fieldData': {
          'pitDetails': [],
          'hddShot': [],
        }
      };

      final execution = TaskExecutionModel.fromJson(json);

      expect(execution.fieldData, isNotNull);
      expect(execution.fieldData!.pitDetails, isEmpty);
      expect(execution.fieldData!.hddShot, isEmpty);
    });

    test('Null execution or null fieldData returns clean empty model without crashing UI', () {
      final executionNull = TaskExecutionModel.fromJson(null);

      expect(executionNull.id, '');
      expect(executionNull.taskId, '');
      expect(executionNull.fieldData, isNull);
    });
  });
}

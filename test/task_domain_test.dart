import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/core/utils/date_parser_utils.dart';
import 'package:hero_app/features/hindrance/data/hindrance_task_data_source.dart';
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

  group('TaskModel Master Data Parsing Tests', () {
    test('Maps embedded trenching routes to Rings with selectable Segments', () {
      const block = TaskModel(
        id: 'block-1',
        taskCode: 'TASK-1',
        displayName: 'Block One',
        taskType: hindranceHierarchyTaskType,
        status: 'ASSIGNED',
        approvalStatus: 'APPROVED',
        legacyRoutes: [
          TaskRouteModel(
            taskId: 'ring-task-id',
            routeCode: 'R01',
            routeName: 'Ring One',
            distanceKm: 2.5,
            segmentsCount: 1,
            startNode: 'GP A',
            targetNode: 'GP B',
            segments: [
              TaskSegmentModel(
                taskId: 'segment-task-id',
                segmentCode: 'R01-S01',
                startNode: 'GP A',
                targetNode: 'GP B',
                distanceKm: 2.5,
              ),
            ],
          ),
        ],
      );

      expect(HindranceTaskDataSource.isBlockTask(block), isTrue);
      final rings = HindranceTaskDataSource.ringsForBlock(block, [block]);
      expect(rings, hasLength(1));
      expect(rings.single.id, 'ring-task-id');
      expect(rings.single.displayName, 'Ring One');
      expect(rings.single.parentTaskId, block.id);
      expect(rings.single.routeSnapshot?.segments.single.segmentCode, 'R01-S01');
      expect(rings.single.routeSnapshot?.segments.single.taskId, 'segment-task-id');
    });

    test('Parses UAT Block to Ring to nested Segment route snapshots', () {
      final block = TaskModel.fromJson({
        'id': 'block-uat',
        'taskCode': 'TASK-2026-57762',
        'displayName': 'GANGANAGAR',
        'taskType': hindranceHierarchyTaskType,
        'status': 'CREATED',
        'approvalStatus': 'PENDING',
        'routeSnapshot': {
          'level': 'BLOCK',
          'routes': [
            {
              'level': 'RING',
              'routeName': 'R1',
              'routeCode': 'RING-R1',
              'lengthKm': 3.6,
              'routes': [
                {
                  'id': 'segment-task-001',
                  'routeId': 'ring-id',
                  'level': 'SEGMENT',
                  'segmentCode': 'SEG-001',
                  'routeName': 'R1',
                  'lengthKm': 1.8,
                  'currentNode': {'code': 'BHQ', 'lat': 29.24, 'lng': 73.52},
                  'nextNode': {'code': 'JC001', 'lat': 29.23, 'lng': 73.51},
                },
                {
                  'id': 'segment-task-002',
                  'routeId': 'ring-id',
                  'level': 'SEGMENT',
                  'segmentCode': 'SEG-002',
                  'routeName': 'R1',
                  'lengthKm': 1.8,
                  'currentNode': {'code': 'JC001'},
                  'nextNode': {'code': 'JC002'},
                },
              ],
            },
          ],
        },
      });

      final rings = HindranceTaskDataSource.ringsForBlock(block, [block]);
      expect(rings, hasLength(1));
      expect(rings.single.displayName, 'R1');
      final segments = HindranceTaskDataSource.segmentsForRing(
        rings.single,
        [block],
      );
      expect(segments.map((segment) => segment.taskCode), ['SEG-001', 'SEG-002']);
      expect(segments.map((segment) => segment.id), [
        'segment-task-001',
        'segment-task-002',
      ]);
      expect(segments.map((segment) => segment.routeSnapshot?.routeCode), [
        'SEG-001',
        'SEG-002',
      ]);
      expect(rings.single.routeSnapshot?.segments.map((s) => s.startNode), [
        'BHQ',
        'JC001',
      ]);
      expect(rings.single.routeSnapshot?.segments.first.startLat, 29.24);
      expect(rings.single.routeSnapshot?.segments.first.targetLng, 73.51);
    });

    test('Uses real Block, Ring, and Segment task IDs from the hierarchy', () {
      const block = TaskModel(
        id: 'block-id',
        taskCode: 'TASK-2026-57710',
        displayName: 'BHERUNDA',
        taskType: hindranceHierarchyTaskType,
        taskLevel: 'BLOCK',
        taskLevelProvided: true,
        status: 'CREATED',
        approvalStatus: 'PENDING',
      );
      const ring = TaskModel(
        id: 'ring-id',
        taskCode: 'TASK-2026-57711',
        displayName: 'R01',
        taskType: hindranceHierarchyTaskType,
        taskLevel: 'RING',
        taskLevelProvided: true,
        status: 'CREATED',
        approvalStatus: 'PENDING',
        parentTaskId: 'block-id',
      );
      const segment = TaskModel(
        id: 'segment-id',
        taskCode: 'TASK-2026-57712',
        displayName: 'BHERUNDA - JC0002',
        taskType: hindranceHierarchyTaskType,
        taskLevel: 'SEGMENT',
        taskLevelProvided: true,
        status: 'CREATED',
        approvalStatus: 'PENDING',
        parentTaskId: 'ring-id',
      );

      expect(HindranceTaskDataSource.isBlockTask(block), isTrue);
      expect(HindranceTaskDataSource.isBlockTask(ring), isFalse);
      expect(HindranceTaskDataSource.isBlockTask(segment), isFalse);
      final rings = HindranceTaskDataSource.ringsForBlock(
        block,
        [block, ring, segment],
      );
      expect(rings.single.id, 'ring-id');
      final segments = HindranceTaskDataSource.segmentsForRing(
        ring,
        [block, ring, segment],
      );
      expect(segments.single.id, 'segment-id');
      expect(segments.single.displayName, 'BHERUNDA - JC0002');
      expect(segments.single.taskCode, 'TASK-2026-57712');
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

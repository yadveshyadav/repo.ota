import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_app/features/tasks/controller/task_controller.dart';
import 'package:hero_app/features/hindrance/data/hindrance_task_data_source.dart';
import 'package:hero_app/features/tasks/screens/task_detail_screen.dart';
import 'package:hero_app/features/tasks/screens/tasks_screen.dart';
import 'package:hero_app/features/tasks/widgets/task_card.dart';
import 'package:hero_app/features/tasks/widgets/task_status_badge.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/models/task_response.dart';
import 'package:hero_app/repositories/task_repository.dart';

void main() {
  group('TaskModel & TaskResponse Parser Tests', () {
    test('Parses full task model JSON correctly', () {
      final json = {
        'id': '6a965e971500691f142a45da',
        'taskCode': 'TASK-2026-54397',
        'displayName': 'BHERUNDA FIBER TRENCHING',
        'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
        'taskLevel': 'BLOCK',
        'status': 'CREATED',
        'stage': 'PLANNING',
        'approvalStatus': 'PENDING',
        'locationCode': 'RJ-NAG-BHE-54397',
        'location': {
          'locationName': 'BHERUNDA',
          'district': 'NAGAUR',
          'circle': 'RAJASTHAN',
          'blockName': 'BHERUNDA',
          'state': 'RAJASTHAN',
        },
        'vendor': {'name': 'Unassigned Vendor'},
        'supervisor': {'name': 'Devesh Dubey'},
        'assigneeSnapshot': {
          'name': 'Devesh Dubey',
          'designation': 'Project Supervisor',
          'mobile': '9876543210',
        },
        'scope': {
          'planned': 180.40,
          'remaining': 162.44,
          'completed': 17.96,
        },
        'progress': 0.0,
        'routes': [
          {
            'id': 'ring-task-id',
            'routeCode': 'R01',
            'routeName': 'Route 01',
            'distanceKm': 57.60,
            'segmentsCount': 4,
            'startNode': 'Modi Kalan',
            'targetNode': 'Jawla',
            'segments': [
              {
                'id': 'segment-task-id',
                'segmentCode': 'R01-S01',
                'startNode': 'Modi Kalan',
                'targetNode': 'Bherunda Junction',
                'distanceKm': 14.40,
              }
            ],
          }
        ],
        'pitsCount': 0,
        'telemetry': {
          'oltIp': '10.0.183.2',
          'baCmp': 'BA-CMP-01',
          'companyPhase': 'HERO Infra Phase 2',
        },
        'coordinates': {'latitude': 26.8500, 'longitude': 74.3800},
        'createdAt': '2026-08-15T08:30:00.000Z',
        'updatedAt': '2026-09-01T10:15:00.000Z',
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, '6a965e971500691f142a45da');
      expect(task.taskCode, 'TASK-2026-54397');
      expect(task.displayName, 'BHERUNDA FIBER TRENCHING');
      expect(task.taskType, 'FIBER_TRENCHING_DUCTING_TASK');
      expect(task.status, 'CREATED');
      expect(task.locationName, 'BHERUNDA');
      expect(task.district, 'NAGAUR');
      expect(task.plannedScope, 180.40);
      expect(task.routes.length, 1);
      expect(task.routes.first.routeCode, 'R01');
      expect(task.routes.first.taskId, 'ring-task-id');
      expect(task.routes.first.segments.first.segmentCode, 'R01-S01');
      expect(task.routes.first.segments.first.taskId, 'segment-task-id');
      final offlineTask = TaskModel.fromJson(task.toJson());
      expect(offlineTask.legacyRoutes.length, 1);
      expect(offlineTask.legacyRoutes.first.segments.first.segmentCode, 'R01-S01');
      expect(offlineTask.legacyRoutes.first.taskId, 'ring-task-id');
      expect(offlineTask.legacyRoutes.first.segments.first.taskId, 'segment-task-id');
      expect(task.latitude, 26.8500);
      expect(task.longitude, 74.3800);
    });

    test('Handles missing/null fields safely without crashing', () {
      final json = <String, dynamic>{};
      final task = TaskModel.fromJson(json);

      expect(task.id, '');
      expect(task.taskCode, 'TASK-2026-00000');
      expect(task.displayName, 'Unnamed Task');
      expect(task.taskType, 'FIBER_TRENCHING_DUCTING_TASK');
      expect(task.status, 'CREATED');
      expect(task.district, 'N/A');
      expect(task.plannedScope, 0.0);
      expect(task.routes, isEmpty);
      expect(task.latitude, isNull);
      expect(task.longitude, isNull);
    });

    test('Parses TaskResponse paginated structure correctly', () {
      final json = {
        'content': [
          {
            'id': 'task-1',
            'taskCode': 'TASK-101',
            'displayName': 'Test Task 1',
            'taskType': 'GP_SURVEY',
            'status': 'IN_PROGRESS',
            'approvalStatus': 'PENDING',
          }
        ],
        'totalElements': 1,
        'totalPages': 1,
        'page': 0,
        'size': 10,
        'summary': {
          'ALL': 10,
          'GP_SURVEY': 5,
        }
      };

      final response = TaskResponse.fromJson(json);

      expect(response.tasks.length, 1);
      expect(response.totalCount, 1);
      expect(response.summaryCounts['GP_SURVEY'], 5);
      expect(response.tasks.first.taskCode, 'TASK-101');
    });

    test('Flattens nested Block, Ring, Segment hierarchy with parent IDs', () {
      final response = TaskResponse.fromJson({
        'data': {
          'content': [
            {
              'id': 'block-1',
              'taskCode': 'TASK-B',
              'name': 'BHERUNDA',
              'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
              'rings': [
                {
                  'id': 'ring-1',
                  'taskCode': 'TASK-R',
                  'name': 'R01',
                  'segments': [
                    {
                      'id': 'segment-1',
                      'taskCode': 'TASK-S',
                      'name': 'BHERUNDA - JC0002',
                    },
                  ],
                },
              ],
            },
          ],
          'totalElements': 1,
        },
      });

      expect(response.tasks, hasLength(3));
      final block = response.tasks[0];
      final ring = response.tasks[1];
      final segment = response.tasks[2];
      expect(block.taskLevel, 'BLOCK');
      expect(ring.taskLevel, 'RING');
      expect(ring.parentTaskId, block.id);
      expect(segment.taskLevel, 'SEGMENT');
      expect(segment.parentTaskId, ring.id);
      expect(HindranceTaskDataSource.isBlockTask(block), isTrue);
      expect(
        HindranceTaskDataSource.ringsForBlock(block, response.tasks),
        [ring],
      );
      expect(
        HindranceTaskDataSource.segmentsForRing(ring, response.tasks),
        [segment],
      );
    });
  });

  group('TaskController Unit Tests', () {
    late MockTaskRepository mockRepo;
    late TaskController controller;

    setUp(() {
      mockRepo = MockTaskRepository();
      controller = TaskController(repository: mockRepo);
    });

    test('Initial fetch populates tasks and summary counts correctly', () async {
      await controller.fetchTasks(page: 0);

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.tasks.length, greaterThan(0));
      expect(controller.totalCount, greaterThan(0));
    });

    test('Selecting task type updates active task type filter', () async {
      await controller.fetchTasks(page: 0);
      controller.selectTaskType('FIBER_TRENCHING_DUCTING_TASK');

      expect(controller.filter.taskType, 'FIBER_TRENCHING_DUCTING_TASK');
    });

    test('Completing task updates task status in state', () async {
      await controller.fetchTasks(page: 0);
      final firstTask = controller.tasks.first;

      final result = await controller.completeTask(firstTask.id);

      expect(result, isTrue);
      final updated = controller.tasks.firstWhere((t) => t.id == firstTask.id);
      expect(updated.status, 'COMPLETED');
      expect(updated.progress, 100.0);
    });
  });

  group('TasksScreen & Components Widget Tests', () {
    testWidgets('Renders TaskStatusBadge correctly for CREATED and COMPLETED',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TaskStatusBadge(status: 'CREATED'),
                TaskStatusBadge(status: 'COMPLETED'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('CREATED'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('Renders TaskCard with task code, vendor, and action buttons',
        (tester) async {
      final task = TaskModel.fromJson({
        'id': '1',
        'taskCode': 'TASK-2026-54397',
        'displayName': 'BHERUNDA TRENCHING',
        'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
        'status': 'CREATED',
        'approvalStatus': 'PENDING',
        'locationCode': 'RJ-01',
        'locationSnapshot': {
          'code': 'RJ-01',
          'name': 'BHERUNDA',
          'district': 'NAGAUR',
          'circle': 'RAJASTHAN',
          'blockName': 'BHERUNDA',
        },
        'assigneeSnapshot': {
          'id': '1',
          'name': 'Devesh Dubey',
          'designation': 'Supervisor',
          'mobile': '9876543210',
        },
        'createdAt': '2026-08-15',
        'updatedAt': '2026-08-15',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: task,
              onInspect: () {},
            ),
          ),
        ),
      );

      expect(find.text('TASK-2026-54397'), findsOneWidget);
      expect(find.text('BHERUNDA TRENCHING'), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('Renders TasksScreen with summary cards, search field and list',
        (tester) async {
      final repo = MockTaskRepository();
      final controller = TaskController(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: TasksScreen(
            repository: repo,
            controller: controller,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('My Tasks'), findsOneWidget);
      expect(find.text('Task Management'), findsOneWidget);
      expect(find.text('All Tasks'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Renders TaskDetailScreen with route hierarchy & attributes',
        (tester) async {
      final task = TaskModel.fromJson({
        'id': '1',
        'taskCode': 'TASK-2026-54397',
        'displayName': 'BHERUNDA TRENCHING',
        'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
        'status': 'CREATED',
        'approvalStatus': 'PENDING',
        'locationCode': 'RJ-01',
        'locationSnapshot': {
          'code': 'RJ-01',
          'name': 'BHERUNDA',
          'district': 'NAGAUR',
          'circle': 'RAJASTHAN',
          'blockName': 'BHERUNDA',
        },
        'assigneeSnapshot': {
          'id': '1',
          'name': 'Devesh Dubey',
          'designation': 'Supervisor',
          'mobile': '9876543210',
        },
        'vendorName': 'Unassigned Vendor',
        'supervisorName': 'Devesh Dubey',
        'plannedScope': 180.40,
        'remainingScope': 162.44,
        'createdAt': '2026-08-15T08:30:00.000Z',
        'updatedAt': '2026-08-15T08:30:00.000Z',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailScreen(task: task),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('TASK-2026-54397'), findsWidgets);
      expect(find.text('Block Route Hierarchy'), findsOneWidget);
    });
  });
}

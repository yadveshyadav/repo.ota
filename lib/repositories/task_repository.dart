import 'package:hero_app/models/task_execution_model.dart';
import 'package:hero_app/models/task_filter.dart';
import 'package:hero_app/models/task_master_snapshots.dart';
import 'package:hero_app/models/task_media_model.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/models/task_response.dart';
import 'package:hero_app/services/api/api_client.dart';
import 'package:hero_app/services/api/task_api_service.dart';

/// Abstract Task Repository interface with in-memory caching and freshness controls
abstract class TaskRepository {
  Future<TaskResponse> getTasks({
    int page = 0,
    int size = 100,
    TaskFilterModel? filters,
    String search = '',
  });

  Future<Map<String, int>> getTaskTypeCounts();

  Future<TaskModel> getTaskDetails(String taskId, {bool forceRefresh = false});

  Future<TaskExecutionModel?> getTaskExecutionDetails(String taskId, {bool forceRefresh = false});
}

/// Production ApiTaskRepository consuming ILYNC & HERO Tasks API
class ApiTaskRepository implements TaskRepository {
  final TaskApiService apiService;

  ApiTaskRepository({ApiClient? apiClient, TaskApiService? apiService})
      : apiService = apiService ??
            TaskApiService(apiClient: apiClient ?? ApiClient());

  @override
  Future<TaskResponse> getTasks({
    int page = 0,
    int size = 100,
    TaskFilterModel? filters,
    String search = '',
  }) async {
    // Task API stopped for now as requested. Returning empty response without fake data.
    return TaskResponse(
      tasks: const [],
      totalCount: 0,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
      hasNext: false,
      hasPrevious: false,
      summaryCounts: const {},
    );
  }

  @override
  Future<Map<String, int>> getTaskTypeCounts() async {
    return const {};
  }

  @override
  Future<TaskModel> getTaskDetails(String taskId, {bool forceRefresh = false}) async {
    return const TaskModel(
      id: '',
      taskCode: '',
      displayName: 'No Task Details',
      taskType: 'GENERAL',
      status: 'NOT_FOUND',
      approvalStatus: 'NONE',
    );
  }

  @override
  Future<TaskExecutionModel?> getTaskExecutionDetails(String taskId, {bool forceRefresh = false}) async {
    return null;
  }
}

/// Sample repository for offline testing or fallback sandbox environments
class MockTaskRepository implements TaskRepository {
  static final List<TaskModel> _mockTasks = [
    TaskModel.fromJson({
      'id': '6a965e971500691f142a45da',
      'taskCode': 'TASK-2026-54397',
      'displayName': 'BHERUNDA FIBER TRENCHING',
      'taskType': 'FIBER_TRENCHING_DUCTING_TASK',
      'taskLevel': 'BLOCK',
      'status': 'CREATED',
      'stage': 'PLANNING',
      'approvalStatus': 'PENDING',
      'locationCode': 'RJ-NAG-BHE-54397',
      'locationSnapshot': {
        'code': 'RJ-NAG-BHE-54397',
        'name': 'BHERUNDA',
        'district': 'NAGAUER',
        'circle': 'RAJASTHAN',
        'blockName': 'BHERUNDA',
        'state': 'RAJASTHAN',
        'oltIp': '10.0.183.2',
        'baCmp': 'BA-CMP-01',
        'companyPhase': 'HERO Infra Phase 2',
      },
      'assigneeSnapshot': {
        'id': 'usr_881',
        'name': 'Devesh Dubey',
        'designation': 'Project Supervisor',
        'mobile': '9876543210',
      },
      'vendorName': 'Unassigned Vendor',
      'partnerName': 'Hero Fibre Networks Ltd',
      'supervisorName': 'Devesh Dubey',
      'creatorName': 'Badre Alam',
      'plannedScope': 180.40,
      'remainingScope': 162.44,
      'completedScope': 17.96,
      'progress': 0.0,
      'routes': [
        {
          'routeCode': 'R01',
          'routeName': 'Block Line R01',
          'distanceKm': 57.60,
          'segmentsCount': 4,
          'startNode': 'Modi Kalan',
          'targetNode': 'Jawla',
          'segments': [
            {
              'segmentCode': 'R01-S01',
              'startNode': 'Modi Kalan',
              'targetNode': 'Bherunda Junction',
              'distanceKm': 14.40,
              'startLat': 26.8500,
              'startLng': 74.3800,
              'targetLat': 26.8650,
              'targetLng': 74.3950,
            },
          ],
        },
      ],
      'createdAt': '2026-08-15T08:30:00.000Z',
    }),
    TaskModel.fromJson({
      'id': '6a965e971500691f142a45db',
      'taskCode': 'TASK-2026-55685',
      'displayName': 'BAORI NINAMA GP SURVEY',
      'taskType': 'GP_SURVEY',
      'taskLevel': 'GP',
      'status': 'IN_PROGRESS',
      'stage': 'SURVEY',
      'approvalStatus': 'PENDING',
      'locationCode': 'RJ-BWA-KUS-294646',
      'locationSnapshot': {
        'code': 'RJ-BWA-KUS-294646',
        'name': 'BAORI NINAMA',
        'district': 'BANSWARA',
        'circle': 'RAJASTHAN',
        'blockName': 'KUSHALGARH',
        'state': 'RAJASTHAN',
      },
      'assigneeSnapshot': {
        'id': 'usr_882',
        'name': 'Sharukh Khan',
        'designation': 'Field-Surveyor',
        'mobile': '8949645950',
      },
      'vendorName': 'Infratek Solutions',
      'partnerName': 'Banswara Telecom',
      'supervisorName': 'Sharukh Khan',
      'creatorName': 'Ramesh Sharma',
      'plannedScope': 24.50,
      'remainingScope': 8.20,
      'completedScope': 16.30,
      'progress': 66.5,
      'createdAt': '2026-09-01T05:11:51.581Z',
    }),
  ];

  @override
  Future<TaskResponse> getTasks({
    int page = 0,
    int size = 10,
    TaskFilterModel? filters,
    String search = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return getTasksSync(page: page, size: size, filters: filters, search: search);
  }

  @override
  Future<Map<String, int>> getTaskTypeCounts() async {
    return getTaskTypeCountsSync();
  }

  Map<String, int> getTaskTypeCountsSync() {
    return const {
      'ALL': 50630,
      'GP_SURVEY': 17206,
      'OTDR_SURVEY': 16356,
      'FIBER_SURVEY': 16101,
      'BLOCK_SURVEY': 931,
      'FIBER_TRENCHING_DUCTING_TASK': 15,
    };
  }

  /// Synchronous instant retrieval for zero-delay UI rendering
  TaskResponse getTasksSync({
    int page = 0,
    int size = 10,
    TaskFilterModel? filters,
    String search = '',
  }) {
    final f = filters ?? const TaskFilterModel();

    final filtered = _mockTasks.where((t) {
      if (f.taskType != 'ALL' && t.taskType != f.taskType) return false;
      if (f.status != 'ALL' && t.status != f.status) return false;
      if (f.vendor != 'ALL' && t.vendorName != f.vendor) return false;
      if (f.supervisor != 'ALL' && t.supervisorName != f.supervisor) return false;
      if (f.district != 'ALL' && t.district != f.district) return false;
      if (f.circle != 'ALL' && t.circle != f.circle) return false;
      if (f.stage != 'ALL' && t.stage != f.stage) return false;
      if (f.approvalStatus != 'ALL' && t.approvalStatus != f.approvalStatus) return false;

      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        return t.displayName.toLowerCase().contains(q) ||
            t.taskCode.toLowerCase().contains(q) ||
            t.assigneeName.toLowerCase().contains(q) ||
            t.district.toLowerCase().contains(q) ||
            t.blockName.toLowerCase().contains(q) ||
            t.locationName.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final startIndex = page * size;
    final endIndex = (startIndex + size) < filtered.length
        ? startIndex + size
        : filtered.length;

    final pagedList = startIndex < filtered.length
        ? filtered.sublist(startIndex, endIndex)
        : <TaskModel>[];

    final totalPages = (filtered.length / size).ceil();

    final Map<String, int> summary = getTaskTypeCountsSync();

    return TaskResponse(
      tasks: pagedList,
      totalCount: filtered.length,
      totalPages: totalPages == 0 ? 1 : totalPages,
      currentPage: page,
      pageSize: size,
      hasNext: page + 1 < totalPages,
      hasPrevious: page > 0,
      summaryCounts: summary,
    );
  }

  @override
  Future<TaskModel> getTaskDetails(String taskId, {bool forceRefresh = false}) async {
    final found = _mockTasks.firstWhere(
      (t) => t.id == taskId || t.taskCode == taskId,
      orElse: () => _mockTasks.first,
    );
    return found;
  }

  @override
  Future<TaskExecutionModel?> getTaskExecutionDetails(String taskId, {bool forceRefresh = false}) async {
    final task = await getTaskDetails(taskId, forceRefresh: forceRefresh);

    return TaskExecutionModel(
      id: 'exec_${task.id}',
      taskId: task.id,
      assigneeUserId: 'usr_881',
      fieldData: FieldDataModel(
        surveyKind: 'GP_SURVEY',
        currentStep: 'COMPLETED',
        workExecutionMode: 'OPEN_TRENCHING',
        hindranceFound: false,
        routeWalkVideo: const TaskMediaModel(
          label: 'Route Walk Walkthrough Video',
          photoUrl: 'https://storage.heroapp.com/tasks/route_walk_video.mp4',
        ),
        trenchingMachineDetails: const TrenchingMachineDetailsModel(
          machineChassisNo: '600202608396',
          modelName: 'JCB 3DX EcoXcellence',
          ownerVendor: 'Hero Infra Vendors Ltd',
        ),
        pitDetails: const [
          TaskPitDetailModel(
            pitId: 'pit_01',
            pitName: 'Manhole Pit 01',
            pitType: 'Standard Joint Chamber',
            depthMeters: 1.65,
            latitude: 26.850000,
            longitude: 74.380000,
            photo: TaskMediaModel(
              label: 'Pit Depth Verification Photo',
              photoUrl: 'https://storage.heroapp.com/tasks/pit_photo_1.jpg',
              latitude: 26.850000,
              longitude: 74.380000,
            ),
          ),
          TaskPitDetailModel(
            pitId: 'pit_02',
            pitName: 'Standard Pit 02',
            pitType: 'Standard Pit',
            depthMeters: 1.50,
            latitude: null,
            longitude: null,
            photo: TaskMediaModel(
              label: 'Pit Photo Without Coordinates',
              photoUrl: 'https://storage.heroapp.com/tasks/pit_photo_2.jpg',
              latitude: null,
              longitude: null,
            ),
          ),
        ],
        hddShot: const [
          HddShotModel(
            shotId: 'shot_101',
            shotNumber: 1,
            lengthMeters: 45.0,
            depthMeters: 2.10,
            pipeDiameterMm: 110.0,
            startLatitude: 26.850000,
            startLongitude: 74.380000,
            endLatitude: 26.851000,
            endLongitude: 74.381000,
            photo: TaskMediaModel(
              label: 'HDD Shot Entry Photo',
              photoUrl: 'https://storage.heroapp.com/tasks/hdd_shot_1.jpg',
              latitude: 26.850000,
              longitude: 74.380000,
            ),
          ),
        ],
        notes: 'Execution completed according to HERO infrastructure guidelines.',
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
    );
  }
}

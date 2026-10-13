import 'package:hero_app/features/hindrance/data/hindrance_local_store.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/models/task_master_snapshots.dart';
import 'package:hero_app/services/api/task_api_service.dart';

const hindranceHierarchyTaskType = 'FIBER_TRENCHING_DUCTING_TASK';

class HindranceTaskData {
  final List<TaskModel> tasks;
  final bool fromCache;
  final bool hasMore;
  final int nextPage;

  const HindranceTaskData({
    required this.tasks,
    required this.fromCache,
    this.hasMore = false,
    this.nextPage = 0,
  });
}

class HindranceRouteGroup {
  final String key;
  final String startName;
  final String endName;
  final List<TaskSegmentModel> segments;

  const HindranceRouteGroup({
    required this.key,
    required this.startName,
    required this.endName,
    required this.segments,
  });

  String get label => '$startName → $endName';
}

/// Loads planning Blocks from live master data and their Ring/Segment choices
/// from the approved Geo BoQ. The task-list endpoint is assignment-scoped and
/// therefore is not a source for all Blocks that can be used for a Hindrance.
class HindranceTaskDataSource {
  static final Map<String, Future<HindranceTaskData>> _loads = {};

  HindranceTaskDataSource({TaskApiService? api, HindranceLocalStore? store})
    : _api = api ?? TaskApiService(),
      _store = store ?? HindranceLocalStore.instance;

  final TaskApiService _api;
  final HindranceLocalStore _store;
  final Map<String, Future<List<Map<String, dynamic>>>> _approvedPlanLoads = {};

  /// Groups route segments using the BoQ API's startLocation/endLocation
  /// metadata, then orders each path by connected start/end nodes. These are
  /// the GP-to-GP paths shown as selectable routes inside a Ring.
  static List<HindranceRouteGroup> routeGroupsForSegments(
    List<TaskSegmentModel> segments,
  ) {
    final grouped = <String, List<TaskSegmentModel>>{};
    final labels = <String, (String, String)>{};
    for (final segment in segments) {
      final start = segment.groupStart?.trim() ?? '';
      final end = segment.groupEnd?.trim() ?? '';
      if (start.isEmpty || end.isEmpty) continue;
      final startIdentity = segment.groupStartId?.trim().isNotEmpty == true
          ? segment.groupStartId!.trim()
          : start.toLowerCase();
      final endIdentity = segment.groupEndId?.trim().isNotEmpty == true
          ? segment.groupEndId!.trim()
          : end.toLowerCase();
      final key = '$startIdentity::$endIdentity';
      grouped.putIfAbsent(key, () => []).add(segment);
      labels.putIfAbsent(key, () => (start, end));
    }

    return grouped.entries.map((entry) {
      final (startName, endName) = labels[entry.key]!;
      final remaining = [...entry.value]
        ..sort(
          (left, right) => (left.sequenceNo ?? 1 << 30).compareTo(
            right.sequenceNo ?? 1 << 30,
          ),
        );
      final ordered = <TaskSegmentModel>[];
      var currentNode = startName.toLowerCase();
      while (remaining.isNotEmpty) {
        var index = remaining.indexWhere(
          (segment) => segment.startNode.trim().toLowerCase() == currentNode,
        );
        if (index < 0) index = 0;
        final next = remaining.removeAt(index);
        ordered.add(next);
        currentNode = next.targetNode.trim().toLowerCase();
      }
      return HindranceRouteGroup(
        key: entry.key,
        startName: startName,
        endName: endName,
        segments: ordered,
      );
    }).toList()..sort((left, right) => left.label.compareTo(right.label));
  }

  static bool isBlockTask(TaskModel task) => task.taskLevelProvided
      ? task.taskLevel.toUpperCase() == 'BLOCK'
      : task.taskType.toUpperCase() == hindranceHierarchyTaskType;

  /// The task API also represents Ring rows as routes embedded in a Block
  /// task. Normalize those routes into Ring task models for both workflows.
  static List<TaskModel> ringsForBlock(
    TaskModel? block,
    List<TaskModel> tasks,
  ) {
    if (block == null) return const [];
    final explicitRings = tasks
        .where(
          (task) =>
              task.taskLevelProvided &&
              task.taskLevel.toUpperCase() == 'RING' &&
              task.parentTaskId == block.id,
        )
        .toList();
    if (explicitRings.isNotEmpty) return explicitRings;

    final snapshotRoutes =
        block.routeSnapshot?.routes ?? const <TaskRouteModel>[];
    final blockRoutes = snapshotRoutes.isNotEmpty
        ? snapshotRoutes
        : block.legacyRoutes;
    return blockRoutes
        .where((route) {
          final level = route.level.toUpperCase();
          return level == 'RING' ||
              route.childRoutes.isNotEmpty ||
              (level.isEmpty && route.segments.isNotEmpty);
        })
        .map((route) {
          final routeCode = route.routeCode.trim().isEmpty
              ? 'RING-${block.legacyRoutes.indexOf(route) + 1}'
              : route.routeCode;
          RouteNodeModel node(String name, String suffix) => RouteNodeModel(
            id: '${block.id}::$routeCode::$suffix',
            code: '$routeCode-$suffix',
            name: name,
          );
          return TaskModel(
            id: route.taskId?.trim().isNotEmpty == true
                ? route.taskId!.trim()
                : '${block.id}::$routeCode',
            taskCode: routeCode,
            displayName: route.routeName.trim().isEmpty
                ? routeCode
                : route.routeName,
            taskType: block.taskType,
            taskLevel: 'RING',
            taskLevelProvided: true,
            status: block.status,
            taskStage: block.taskStage,
            approvalStatus: block.approvalStatus,
            parentTaskId: block.id,
            locationCode: block.locationCode,
            routeSnapshot: RouteSnapshotModel(
              routeCode: routeCode,
              routeName: route.routeName,
              distanceKm: route.distanceKm,
              segmentsCount: route.childRoutes.isNotEmpty
                  ? route.childRoutes.length
                  : route.segments.length,
              startNode: node(route.startNode, 'START'),
              targetNode: node(route.targetNode, 'END'),
              segments: route.childRoutes.isNotEmpty
                  ? route.childRoutes
                        .where(
                          (child) => child.level.toUpperCase() == 'SEGMENT',
                        )
                        .map(
                          (child) => TaskSegmentModel(
                            // Keep the authoritative segment task ID when the API
                            // provides one. A segment code is a display/reference
                            // value and must never be sent as a task ID.
                            taskId: child.taskId,
                            segmentCode: child.segmentCode.isEmpty
                                ? child.routeCode
                                : child.segmentCode,
                            startNode: child.startNode,
                            targetNode: child.targetNode,
                            distanceKm: child.distanceKm,
                            startLat: child.startLat,
                            startLng: child.startLng,
                            targetLat: child.targetLat,
                            targetLng: child.targetLng,
                          ),
                        )
                        .toList()
                  : route.segments,
              polylineCoordinates: route.polylineCoordinates,
            ),
          );
        })
        .toList();
  }

  static List<TaskModel> segmentsForRing(
    TaskModel? ring,
    List<TaskModel> tasks,
  ) {
    if (ring == null) return const [];
    final explicit = tasks
        .where(
          (task) =>
              task.taskLevelProvided &&
              task.taskLevel.toUpperCase() == 'SEGMENT' &&
              task.parentTaskId == ring.id,
        )
        .toList();
    if (explicit.isNotEmpty) return explicit;
    final embedded = ring.routeSnapshot?.segments ?? const <TaskSegmentModel>[];
    return embedded
        .map(
          (segment) => TaskModel(
            id: segment.taskId ?? segment.segmentCode,
            taskCode: segment.segmentCode,
            displayName: '${segment.startNode} - ${segment.targetNode}',
            taskType: ring.taskType,
            taskLevel: 'SEGMENT',
            taskLevelProvided: true,
            status: ring.status,
            taskStage: ring.taskStage,
            approvalStatus: ring.approvalStatus,
            parentTaskId: ring.id,
            locationCode: ring.locationCode,
            routeSnapshot: RouteSnapshotModel(
              routeCode: segment.segmentCode,
              routeName: segment.segmentCode,
              distanceKm: segment.distanceKm,
              segmentsCount: 1,
              segments: [segment],
              startNode: RouteNodeModel(
                id: '${segment.segmentCode}:start',
                code: segment.startNode,
                name: segment.startNode,
                latitude: segment.startLat,
                longitude: segment.startLng,
              ),
              targetNode: RouteNodeModel(
                id: '${segment.segmentCode}:end',
                code: segment.targetNode,
                name: segment.targetNode,
                latitude: segment.targetLat,
                longitude: segment.targetLng,
              ),
            ),
          ),
        )
        .toList();
  }

  /// Returns the last successful account snapshot without starting or waiting
  /// for a network request. Used to render Hindrance immediately offline.
  Future<HindranceTaskData> loadCached(String ownerId) async {
    final cached = await _store.loadTasks(ownerId);
    return HindranceTaskData(
      tasks: cached
          .map(TaskModel.fromJson)
          .where((task) => task.id.isNotEmpty)
          .toList(),
      fromCache: true,
    );
  }

  /// Persists only one selected Block and its descendant Ring/Segment tasks.
  /// The authorized `/my-tasks` response remains in memory and is never copied
  /// wholesale into the offline database.
  Future<void> cacheBlockHierarchy({
    required String ownerId,
    required String blockId,
    required List<TaskModel> tasks,
  }) async {
    final byId = {for (final task in tasks) task.id: task};
    final selected = <String>{blockId};
    var frontier = <String>{blockId};
    while (frontier.isNotEmpty) {
      final children = tasks
          .where(
            (task) =>
                task.parentTaskId != null &&
                frontier.contains(task.parentTaskId),
          )
          .map((task) => task.id)
          .where((id) => id.isNotEmpty && !selected.contains(id))
          .toSet();
      selected.addAll(children);
      frontier = children;
    }
    final hierarchy = selected
        .map((id) => byId[id])
        .whereType<TaskModel>()
        .toList();
    if (byId[blockId] == null || hierarchy.isEmpty) {
      throw StateError('The selected Block is not in this account task list.');
    }
    // Keep previously downloaded Block BoQs as well. Replacing the whole
    // snapshot here meant that syncing one Block silently removed offline
    // Ring data for every other Block.
    final cached = (await _store.loadTasks(
      ownerId,
    )).map(TaskModel.fromJson).where((task) => task.id.isNotEmpty).toList();
    final mergedById = {for (final task in cached) task.id: task};
    for (final task in hierarchy) {
      mergedById[task.id] = task;
    }
    await _store.saveTasks(
      ownerId,
      mergedById.values.map((task) => task.toJson()).toList(),
    );
  }

  Future<HindranceTaskData> load(String ownerId, {bool forceRefresh = false}) {
    if (forceRefresh || !_loads.containsKey(ownerId)) {
      _loads[ownerId] = _fetch(ownerId);
    }
    return _loads[ownerId]!;
  }

  /// Fetches one additional page on demand. The task API remains read-only and
  /// only the selected Block hierarchy is persisted for offline use.
  Future<HindranceTaskData> loadPage(String ownerId, int page) async {
    return const HindranceTaskData(tasks: [], fromCache: false);
  }

  Future<HindranceTaskData> _fetch(String ownerId) async {
    try {
      final cached = (await _store.loadTasks(
        ownerId,
      )).map(TaskModel.fromJson).where((task) => task.id.isNotEmpty).toList();
      final cachedById = {for (final task in cached) task.id: task};
      final master = await _loadMasterBlocks();
      // LOCATION master data has no BoQ routes. Overlay only previously
      // downloaded route hierarchies onto the matching live Block rows.
      final tasks = master.map((block) {
        final snapshot = cachedById[block.id];
        if (snapshot?.routeSnapshot?.routes.isNotEmpty != true) return block;
        return TaskModel(
          id: block.id,
          taskCode: block.taskCode,
          displayName: block.displayName,
          taskType: block.taskType,
          taskLevel: block.taskLevel,
          taskLevelProvided: block.taskLevelProvided,
          status: block.status,
          taskStage: block.taskStage,
          approvalStatus: block.approvalStatus,
          parentTaskId: block.parentTaskId,
          ancestors: block.ancestors,
          depth: block.depth,
          rootTaskId: block.rootTaskId,
          locationCode: block.locationCode,
          locationSnapshot: block.locationSnapshot,
          routeSnapshot: snapshot!.routeSnapshot,
          totalLengthKm: snapshot.totalLengthKm,
          meta: {...?block.meta, ...?snapshot.meta},
        );
      }).toList();
      return HindranceTaskData(tasks: tasks, fromCache: false);
    } catch (_) {
      final cached = await _store.loadTasks(ownerId);
      return HindranceTaskData(
        tasks: cached
            .map(TaskModel.fromJson)
            .where((task) => task.id.isNotEmpty)
            .toList(),
        fromCache: true,
      );
    }
  }

  /// Loads one Block's approved BoQ using the same endpoints as the Dev web
  /// task form. The selected plan ID is retained on the Block for submission.
  Future<TaskModel> loadBlockHierarchy(TaskModel block) async {
    final blockId = block.locationSnapshot?.blockId?.trim().isNotEmpty == true
        ? block.locationSnapshot!.blockId!.trim()
        : block.id;
    final approvedPlans = await _approvedPlansForBlock(block);
    if (approvedPlans.isEmpty) {
      throw StateError(
        'No approved BoQ revision is available for ${block.displayName}. Select a Block with an approved BoQ.',
      );
    }
    if (approvedPlans.length != 1) {
      throw StateError(
        'More than one approved BoQ is available for ${block.displayName}; the app needs a plan selector before this Block can be used.',
      );
    }
    final planId = approvedPlans.single['resolvedPlanId'].toString();
    final revisionNo = approvedPlans.single['resolvedRevisionNo'].toString();
    final routeResponse = await _api.fetchPlanningData(
      '/geo/api/boq/routes/by-block/${Uri.encodeComponent(planId)}'
      '?source=BOQ_IMPORT&revisionNo=${Uri.encodeQueryComponent(revisionNo)}',
    );
    final routeData = _dataMap(routeResponse);
    if (routeData == null ||
        routeResponse is! Map ||
        routeResponse['success'] != true) {
      throw StateError('Dev did not return the approved BoQ routes.');
    }
    final responseBlockId = routeData['blockId']?.toString();
    if (responseBlockId != null && responseBlockId != blockId) {
      throw StateError(
        'Dev returned BoQ routes for Block $responseBlockId instead of $blockId.',
      );
    }
    final routes = (routeData['routes'] as List? ?? const [])
        .whereType<Map>()
        .map((route) => _routeFromGeo(Map<String, dynamic>.from(route)))
        .toList();
    if (routes.isEmpty) {
      throw StateError(
        'The approved BoQ has no routes for ${block.displayName}.',
      );
    }
    final location = block.locationSnapshot;
    return TaskModel(
      id: block.id,
      taskCode: block.taskCode,
      displayName: block.displayName,
      taskType: hindranceHierarchyTaskType,
      taskLevel: 'BLOCK',
      taskLevelProvided: true,
      status: 'ACTIVE',
      approvalStatus: 'APPROVED',
      locationCode: block.locationCode,
      locationSnapshot: location,
      totalLengthKm: routes.fold<double>(
        0,
        (sum, route) => sum + route.distanceKm,
      ),
      routeSnapshot: RouteSnapshotModel(
        level: 'BLOCK',
        routeCode: blockId,
        routeName: block.displayName,
        distanceKm: routes.fold<double>(
          0,
          (sum, route) => sum + route.distanceKm,
        ),
        segmentsCount: routes.fold<int>(
          0,
          (sum, route) => sum + route.segmentsCount,
        ),
        routes: routes,
      ),
      meta: {
        ...?block.meta,
        'blockId': blockId,
        'networkPlanId': planId,
        'boqRevisionNo': revisionNo,
        if (location?.projectPhase != null)
          'projectPhase': location!.projectPhase,
      },
    );
  }

  /// Checks whether a Block has exactly one approved plan, the same eligibility
  /// required to load its route hierarchy.
  Future<bool> hasUsableApprovedBoq(TaskModel block) async =>
      (await _approvedPlansForBlock(block)).length == 1;

  Future<List<Map<String, dynamic>>> _approvedPlansForBlock(TaskModel block) {
    final blockId = block.locationSnapshot?.blockId?.trim().isNotEmpty == true
        ? block.locationSnapshot!.blockId!.trim()
        : block.id;
    return _approvedPlanLoads.putIfAbsent(blockId, () async {
      try {
        final plansResponse = await _api.fetchPlanningData(
          '/geo/api/boq/plans?blockId=${Uri.encodeQueryComponent(blockId)}&size=50',
        );
        if (plansResponse is Map && plansResponse['success'] == false) {
          throw StateError(
            plansResponse['message']?.toString() ??
                'Dev could not load BoQ plans for ${block.displayName}.',
          );
        }
        final plansData = _dataMap(plansResponse);
        final planRows =
            plansData?['content'] ??
            plansData?['plans'] ??
            _dataList(plansResponse);
        final plans = (planRows as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id'] != null || item['planId'] != null)
            .toList();
        if (plans.isEmpty) return const <Map<String, dynamic>>[];

        final approvedPlans = <Map<String, dynamic>>[];
        for (final plan in plans) {
          final planId = (plan['id'] ?? plan['planId']).toString();
          final revisionResponse = await _api.fetchPlanningData(
            '/geo/api/boq/plans/${Uri.encodeComponent(planId)}/revisions',
          );
          if (revisionResponse is Map && revisionResponse['success'] == false) {
            throw StateError(
              revisionResponse['message']?.toString() ??
                  'Dev could not load BoQ revisions for ${block.displayName}.',
            );
          }
          final revisionData = _dataMap(revisionResponse);
          final revisionRows =
              revisionData?['content'] ??
              revisionData?['revisions'] ??
              _dataList(revisionResponse);
          final revisions = (revisionRows as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(
                (item) =>
                    item['status']?.toString().toUpperCase() == 'APPROVED',
              )
              .toList();
          revisions.sort(
            (left, right) =>
                (int.tryParse(right['revisionNo']?.toString() ?? '') ?? -1)
                    .compareTo(
                      int.tryParse(left['revisionNo']?.toString() ?? '') ?? -1,
                    ),
          );
          if (revisions.isNotEmpty && revisions.first['revisionNo'] != null) {
            approvedPlans.add({
              ...plan,
              'resolvedPlanId': planId,
              'resolvedRevisionNo': revisions.first['revisionNo'],
            });
          }
        }
        return approvedPlans;
      } catch (_) {
        _approvedPlanLoads.remove(blockId);
        rethrow;
      }
    });
  }

  Future<List<TaskModel>> _loadMasterBlocks() async {
    // The Dev web task form requests LOCATION master data explicitly. The
    // endpoint rejects an unscoped request with HTTP 400 and the old client
    // would then fall back to stale assigned/cached Blocks (such as BHATTU).
    final response = await _api.fetchPlanningData(
      '/api/master/data?module=LOCATION',
    );
    final data = _dataMap(response);
    final rawDistricts = data?['districts'];
    final rawBlocks = data?['blocks'];
    final rawCircles = data?['circles'];
    if (data == null || rawDistricts is! Map || rawBlocks is! Map) {
      throw StateError('Dev returned an invalid master-data hierarchy.');
    }
    final circleByDistrict = <String, String>{};
    for (final entry in rawDistricts.entries) {
      final circle = entry.key.toString();
      for (final district in (entry.value as List? ?? const [])) {
        circleByDistrict.putIfAbsent(district.toString(), () => circle);
      }
    }
    final circles = (rawCircles as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final circleDisplayByKey = {
      for (final circle in circles)
        circle['key']?.toString() ?? '': circle['value']?.toString() ?? '',
    };
    final tasks = <TaskModel>[];
    for (final districtEntry in rawBlocks.entries) {
      final district = districtEntry.key.toString();
      final circleKey = circleByDistrict[district] ?? '';
      final circle = circleDisplayByKey[circleKey] ?? circleKey;
      for (final rawBlock in (districtEntry.value as List? ?? const [])) {
        if (rawBlock is! Map) continue;
        final block = Map<String, dynamic>.from(rawBlock);
        final id = block['key']?.toString().trim() ?? '';
        final name = block['value']?.toString().trim() ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final phase = block['projectPhase']?.toString();
        final displayName = '$name - $id';
        tasks.add(
          TaskModel(
            id: id,
            taskCode: displayName,
            displayName: displayName,
            taskType: hindranceHierarchyTaskType,
            taskLevel: 'BLOCK',
            taskLevelProvided: true,
            status: 'ACTIVE',
            approvalStatus: 'APPROVED',
            locationCode: id,
            locationSnapshot: LocationSnapshotModel(
              code: id,
              name: name,
              district: district,
              circle: circle,
              blockName: name,
              state: circle,
              blockId: id,
              projectPhase: phase,
            ),
            meta: {
              'blockId': id,
              if (phase != null && phase.isNotEmpty) 'projectPhase': phase,
            },
          ),
        );
      }
    }
    final uniqueTasks = {
      for (final task in tasks) task.id: task,
    }.values.toList();
    uniqueTasks.sort((a, b) => a.displayName.compareTo(b.displayName));
    if (uniqueTasks.isEmpty) {
      throw StateError('Dev master data did not include any Blocks.');
    }
    return uniqueTasks;
  }

  Map<String, dynamic>? _dataMap(dynamic response) {
    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    return response is Map ? Map<String, dynamic>.from(response) : null;
  }

  List<dynamic>? _dataList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    return null;
  }

  TaskRouteModel _routeFromGeo(Map<String, dynamic> route) {
    String nodeName(dynamic node, dynamic fallback) {
      if (node is Map) {
        return (node['name'] ?? node['code'] ?? '').toString();
      }
      return node?.toString() ?? fallback?.toString() ?? '';
    }

    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    final rawSegments =
        (route['segments'] as List? ?? const [])
            .whereType<Map>()
            .map((segment) => Map<String, dynamic>.from(segment))
            .toList()
          ..sort((left, right) {
            final leftSequence =
                int.tryParse(left['sequenceNo']?.toString() ?? '') ?? 0;
            final rightSequence =
                int.tryParse(right['sequenceNo']?.toString() ?? '') ?? 0;
            return leftSequence.compareTo(rightSequence);
          });
    final segments = rawSegments
        .map((rawSegment) {
          final segment = rawSegment;
          final start = segment['startNode'] ?? segment['startLocation'];
          final end = segment['endNode'] ?? segment['endLocation'];
          final groupStart = segment['startLocation'];
          final groupEnd = segment['endLocation'];
          return TaskSegmentModel(
            taskId: segment['id']?.toString(),
            segmentCode:
                (segment['segmentCode'] ?? segment['legacySegmentCode'] ?? '')
                    .toString(),
            startNode: nodeName(start, segment['startPoint']),
            targetNode: nodeName(end, segment['endPoint']),
            distanceKm:
                number(segment['lengthKm'] ?? segment['distanceKm']) ?? 0,
            startLat: number(
              start is Map ? (start['lat'] ?? start['latitude']) : null,
            ),
            startLng: number(
              start is Map ? (start['lng'] ?? start['longitude']) : null,
            ),
            targetLat: number(
              end is Map ? (end['lat'] ?? end['latitude']) : null,
            ),
            targetLng: number(
              end is Map ? (end['lng'] ?? end['longitude']) : null,
            ),
            groupStart: nodeName(groupStart, null),
            groupEnd: nodeName(groupEnd, null),
            groupStartId: groupStart is Map
                ? (groupStart['id'] ?? groupStart['code'])?.toString()
                : null,
            groupEndId: groupEnd is Map
                ? (groupEnd['id'] ?? groupEnd['code'])?.toString()
                : null,
            sequenceNo: int.tryParse(segment['sequenceNo']?.toString() ?? ''),
          );
        })
        .where((segment) => segment.segmentCode.isNotEmpty)
        .toList();
    final first = segments.firstOrNull;
    final last = segments.isEmpty ? null : segments.last;
    final routeName = (route['routeName'] ?? route['routeCode'] ?? '')
        .toString();
    final routeCode = (route['routeCode'] ?? routeName).toString();
    return TaskRouteModel(
      taskId: route['id']?.toString(),
      planId: route['planId']?.toString(),
      level: 'RING',
      routeCode: routeCode,
      routeName: routeName,
      distanceKm: number(route['lengthKm'] ?? route['distanceKm']) ?? 0,
      segmentsCount: segments.length,
      startNode: first?.startNode ?? '',
      targetNode: last?.targetNode ?? '',
      segments: segments,
    );
  }
}

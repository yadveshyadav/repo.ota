import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/features/hindrance/data/ccn_catalog.dart';
import 'package:hero_app/features/hindrance/data/hindrance_kml.dart';
import 'package:hero_app/features/hindrance/data/hindrance_local_store.dart';
import 'package:hero_app/features/hindrance/data/hindrance_media_service.dart';
import 'package:hero_app/features/hindrance/data/hindrance_route_recorder.dart';
import 'package:hero_app/features/hindrance/data/hindrance_submission_service.dart';
import 'package:hero_app/features/hindrance/data/pending_sync_manager.dart';
import 'package:hero_app/features/hindrance/data/hindrance_task_data_source.dart';
import 'package:hero_app/features/hindrance/screens/ccn_camera_recording_screen.dart';
import 'package:hero_app/features/hindrance/widgets/hindrance_route_preview.dart';
import 'package:hero_app/features/hindrance/widgets/hindrance_glass_surface.dart';
import 'package:hero_app/features/hindrance/widgets/pending_sync_action.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/models/task_filter.dart';
import 'package:hero_app/services/api/task_api_service.dart';
import 'package:uuid/uuid.dart';

/// CCN evidence workflow. It can be opened from a saved Hindrance or directly
/// from the Operations sidebar; both paths persist locally until APIs exist.
class CcnWorkflowScreen extends StatefulWidget {
  const CcnWorkflowScreen({super.key, this.hindrance = const {}});

  final Map<String, dynamic> hindrance;

  @override
  State<CcnWorkflowScreen> createState() => _CcnWorkflowScreenState();
}

class _CcnWorkflowScreenState extends State<CcnWorkflowScreen> {
  static const _uuid = Uuid();
  final _store = HindranceLocalStore.instance;
  final _mediaService = HindranceMediaService();
  final _routeRecorder = HindranceRouteRecorder();
  final _taskSource = HindranceTaskDataSource();
  final _submissionService = HindranceSubmissionService();
  final _taskApi = TaskApiService();
  final _description = TextEditingController();
  final List<Map<String, dynamic>> _media = [];
  String? _ownerId;
  String? _reportId;
  String? _ccnId;
  String? _serverTaskId;
  String? _createdAt;
  String? _category;
  String? _subtype;
  String? _error;
  String _kmlChoice = 'generated';
  Map<String, dynamic>? _kmlArtifact;
  List<Map<String, dynamic>> _routePoints = [];
  List<Map<String, dynamic>> _proposedRoutePoints = [];
  List<TaskModel> _tasks = [];
  List<TaskModel> _cachedTasks = [];
  List<TaskModel> _ccnHistory = [];
  String? _blockId;
  String? _circle;
  String? _district;
  String? _ringId;
  String? _routeGroupKey;
  final Set<String> _segmentCodes = {};
  bool _hierarchyConfirmed = false;
  bool _tasksFromCache = false;
  bool _taskListHasMore = false;
  bool _loadingMoreTasks = false;
  bool _loadingCcnHistory = true;
  bool _loadingHierarchy = false;
  String? _hierarchyLoadError;
  String _approvalStatus = 'PENDING';
  int _nextTaskPage = 1;
  bool _saving = false;
  bool _loading = true;
  bool _showLanding = false;
  Timer? _autosave;

  Map<String, dynamic>? get _mediaAtStart =>
      _media.where((item) => item['slot'] == 'ccn_start_point').firstOrNull;
  Map<String, dynamic>? get _walkthrough =>
      _media.where((item) => item['slot'] == 'ccn_walkthrough').firstOrNull;
  Map<String, dynamic>? get _mediaAtEnd =>
      _media.where((item) => item['slot'] == 'ccn_end_point').firstOrNull;
  Map<String, dynamic>? get _proposedMediaAtStart =>
      _media.where((item) => item['slot'] == 'ccn_new_start_point').firstOrNull;
  Map<String, dynamic>? get _proposedWalkthrough =>
      _media.where((item) => item['slot'] == 'ccn_new_walkthrough').firstOrNull;
  Map<String, dynamic>? get _proposedMediaAtEnd =>
      _media.where((item) => item['slot'] == 'ccn_new_end_point').firstOrNull;

  bool get _routeReady =>
      _mediaAtStart != null &&
      _walkthrough != null &&
      _mediaAtEnd != null &&
      _proposedMediaAtStart != null &&
      _proposedWalkthrough != null &&
      _proposedMediaAtEnd != null;

  String _segmentSelectionKey(TaskSegmentModel segment) =>
      segment.taskId?.trim().isNotEmpty == true
      ? segment.taskId!.trim()
      : segment.segmentCode;

  bool _isSegmentSelected(TaskSegmentModel segment) =>
      _segmentCodes.contains(_segmentSelectionKey(segment)) ||
      _segmentCodes.contains(segment.segmentCode);

  List<Map<String, dynamic>> get _selectedSegmentPayload {
    final selected = _segments
        .where(_isSegmentSelected)
        .map(
          (segment) => {
            if (segment.taskId != null) 'taskId': segment.taskId,
            'code': segment.segmentCode,
            'startNode': segment.startNode,
            'endNode': segment.targetNode,
            'startLatitude': segment.startLat,
            'startLongitude': segment.startLng,
            'endLatitude': segment.targetLat,
            'endLongitude': segment.targetLng,
          },
        )
        .toList();
    if (selected.isNotEmpty) return selected;
    return (widget.hindrance['affectedSegments'] as List? ?? const [])
        .whereType<Map>()
        .where(
          (segment) =>
              _segmentCodes.contains(segment['code']?.toString() ?? ''),
        )
        .map((segment) => Map<String, dynamic>.from(segment))
        .toList();
  }

  List<Map<String, dynamic>> get _previewPoints {
    final points = <Map<String, dynamic>>[];
    final start = _mediaAtStart?['location'];
    if (start is Map) points.add(Map<String, dynamic>.from(start));
    points.addAll(_routePoints);
    final end = _mediaAtEnd?['location'];
    if (end is Map) points.add(Map<String, dynamic>.from(end));
    return _deduplicatePoints(points);
  }

  List<Map<String, dynamic>> get _proposedPreviewPoints {
    final points = <Map<String, dynamic>>[];
    final start = _proposedMediaAtStart?['location'];
    if (start is Map) points.add(Map<String, dynamic>.from(start));
    points.addAll(_proposedRoutePoints);
    final end = _proposedMediaAtEnd?['location'];
    if (end is Map) points.add(Map<String, dynamic>.from(end));
    return _deduplicatePoints(points);
  }

  List<Map<String, dynamic>> get _displayPoints =>
      _kmlChoice == 'uploaded' && _kmlArtifact?['previewPoints'] is List
      ? List<Map<String, dynamic>>.from(_kmlArtifact!['previewPoints'] as List)
      : _proposedPreviewPoints;

  bool get _isProposedRouteApproved =>
      _approvalStatus.toUpperCase() == 'APPROVED';

  List<Map<String, dynamic>> get _existingRoutePoints {
    final result = <Map<String, dynamic>>[];
    for (final segment in _selectedSegmentPayload) {
      final start = _coordinatePoint(
        segment['startLatitude'],
        segment['startLongitude'],
      );
      final end = _coordinatePoint(
        segment['endLatitude'],
        segment['endLongitude'],
      );
      if (start != null &&
          (result.isEmpty || !_samePoint(result.last, start))) {
        result.add(start);
      }
      if (end != null && (result.isEmpty || !_samePoint(result.last, end))) {
        result.add(end);
      }
    }
    return result;
  }

  Map<String, dynamic>? _coordinatePoint(Object? latitude, Object? longitude) {
    final lat = double.tryParse(latitude?.toString() ?? '');
    final lng = double.tryParse(longitude?.toString() ?? '');
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return {'latitude': lat, 'longitude': lng};
  }

  bool _samePoint(Map<String, dynamic> first, Map<String, dynamic> second) =>
      first['latitude'] == second['latitude'] &&
      first['longitude'] == second['longitude'];

  @override
  void initState() {
    super.initState();
    _description.addListener(_scheduleSave);
    _initialize();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _description
      ..removeListener(_scheduleSave)
      ..dispose();
    unawaited(_routeRecorder.stop());
    super.dispose();
  }

  Future<void> _initialize() async {
    final user = AuthStorageService().currentUser;
    if (user == null || user.id.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign in to save CCN evidence on this device.';
        });
      }
      return;
    }
    _ownerId = user.id;
    _blockId = widget.hindrance['blockId']?.toString();
    _ringId = widget.hindrance['ringId']?.toString();
    _routeGroupKey = widget.hindrance['routeGroupKey']?.toString();
    _segmentCodes.addAll(
      (widget.hindrance['affectedSegments'] as List? ?? const [])
          .whereType<Map>()
          .map((segment) => segment['code']?.toString() ?? '')
          .where((code) => code.isNotEmpty),
    );
    final cachedTasks = await _taskSource.loadCached(user.id);
    PendingSyncManager.instance.restore(await _store.loadReports(user.id));
    if (!mounted) return;
    final now = DateTime.now().toUtc();
    final reportId = _uuid.v4();
    setState(() {
      _reportId = reportId;
      _ccnId = 'CCN-${_uuid.v4().toUpperCase()}';
      _createdAt = now.toIso8601String();
      _cachedTasks = cachedTasks.tasks;
      _tasks = cachedTasks.tasks;
      _tasksFromCache = cachedTasks.tasks.isNotEmpty;
      _showLanding = widget.hindrance.isEmpty;
      _loading = false;
    });
    final initialBlock = _blocks
        .where((task) => task.id == _blockId)
        .firstOrNull;
    _circle = initialBlock?.circle;
    _district = initialBlock?.district;
    unawaited(_refreshTasks());
    unawaited(_refreshCcnHistory());
  }

  Future<void> _refreshCcnHistory() async {
    if (mounted) setState(() => _loadingCcnHistory = true);
    try {
      final found = <TaskModel>[];
      final seen = <String>{};
      var page = 0;
      var hasNext = true;
      // Fetch the user's CCN task pages so older submissions appear too.
      while (hasNext && page < 20) {
        final response = await _taskApi.fetchTasks(
          page: page,
          size: 100,
          filters: const TaskFilterModel(taskType: 'CCN'),
        );
        for (final task in response.tasks) {
          if (task.taskType.trim().toUpperCase() == 'CCN' &&
              seen.add(task.id)) {
            found.add(task);
          }
        }
        hasNext = response.hasNext;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _ccnHistory = found
          ..sort((a, b) {
            final aDate = a.createdAt ?? a.submittedAt;
            final bDate = b.createdAt ?? b.submittedAt;
            if (aDate == null) return bDate == null ? 0 : 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
        _loadingCcnHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingCcnHistory = false);
      debugPrint('[CCN] Could not load CCN task history: $error');
    }
  }

  Future<void> _startNewCcn() async {
    if (!mounted) return;
    setState(() => _showLanding = false);
    await _persist();
  }

  Future<void> _refreshTasks() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    try {
      final data = await _taskSource.load(ownerId);
      if (!mounted) return;
      var tasks = data.tasks;
      if (_blockId != null) {
        final selected = tasks.where((task) => task.id == _blockId).firstOrNull;
        if (selected != null) {
          final hierarchy = await _taskSource.loadBlockHierarchy(selected);
          tasks = tasks
              .map((task) => task.id == selected.id ? hierarchy : task)
              .toList();
          await _taskSource.cacheBlockHierarchy(
            ownerId: ownerId,
            blockId: selected.id,
            tasks: tasks,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        final selectedBlock = tasks
            .where((task) => task.id == _blockId)
            .firstOrNull;
        if (selectedBlock != null) {
          _circle = selectedBlock.circle;
          _district = selectedBlock.district;
        }
        _restoreRouteGroupFromSelection();
        _cachedTasks = data.fromCache ? data.tasks : const [];
        _tasksFromCache = data.fromCache && data.tasks.isNotEmpty;
        _hierarchyLoadError = null;
        _taskListHasMore = data.hasMore;
        _nextTaskPage = data.nextPage;
      });
    } catch (error) {
      // Keep the account-scoped cached pack usable when the GET fails, and
      // explain when this Block has never had its approved BoQ saved locally.
      if (!mounted || _blockId == null) return;
      final selected = _blocks.where((task) => task.id == _blockId).firstOrNull;
      if (selected?.routeSnapshot?.routes.isNotEmpty != true) {
        setState(() => _hierarchyLoadError = _hierarchyErrorMessage(error));
      }
    }
  }

  Future<void> _selectBlock(String? blockId) async {
    final selected = _blocks.where((task) => task.id == blockId).firstOrNull;
    final hasCachedRoutes = selected?.routeSnapshot?.routes.isNotEmpty == true;
    setState(() {
      _circle = selected?.circle;
      _district = selected?.district;
      _blockId = blockId;
      _ringId = null;
      _routeGroupKey = null;
      _segmentCodes.clear();
      _loadingHierarchy = selected != null && !hasCachedRoutes;
      _hierarchyLoadError = null;
      _scheduleSave();
    });
    if (selected == null) return;
    try {
      final hierarchy = await _taskSource.loadBlockHierarchy(selected);
      if (!mounted || _blockId != blockId) return;
      setState(() {
        _tasks = _tasks
            .map((task) => task.id == blockId ? hierarchy : task)
            .toList();
        _loadingHierarchy = false;
        _hierarchyLoadError = null;
      });
      await _taskSource.cacheBlockHierarchy(
        ownerId: _ownerId!,
        blockId: blockId!,
        tasks: _tasks,
      );
    } catch (error) {
      if (!mounted || _blockId != blockId) return;
      setState(() {
        _loadingHierarchy = false;
        _hierarchyLoadError = hasCachedRoutes
            ? null
            : _hierarchyErrorMessage(error);
      });
    }
  }

  String _hierarchyErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final normalized = message.toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection timed out')) {
      return 'No saved Ring data for this Block. Connect to the internet and select this Block to sync its approved BoQ for offline use.';
    }
    return message;
  }

  Future<void> _loadMoreTasks() async {
    final ownerId = _ownerId;
    if (ownerId == null || !_taskListHasMore || _loadingMoreTasks) return;
    setState(() => _loadingMoreTasks = true);
    try {
      final page = await _taskSource.loadPage(ownerId, _nextTaskPage);
      if (!mounted) return;
      final knownIds = _tasks.map((task) => task.id).toSet();
      setState(() {
        _tasks = [
          ..._tasks,
          ...page.tasks.where((task) => !knownIds.contains(task.id)),
        ];
        _taskListHasMore = page.hasMore;
        _nextTaskPage = page.nextPage;
        _loadingMoreTasks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreTasks = false);
      _showMessage('Could not load the next task page: $error');
    }
  }

  List<TaskModel> get _blocks => _tasks
      .where(HindranceTaskDataSource.isBlockTask)
      .where((task) => task.id.isNotEmpty)
      .toList();

  List<String> get _circles =>
      (_blocks
          .map((block) => block.circle.trim())
          .where((value) => value.isNotEmpty && value != 'N/A')
          .toSet()
          .toList()
        ..sort());

  List<String> get _districts =>
      (_blocks
          .where((block) => _circle == null || block.circle == _circle)
          .map((block) => block.district.trim())
          .where((value) => value.isNotEmpty && value != 'N/A')
          .toSet()
          .toList()
        ..sort());

  List<TaskModel> get _visibleBlocks => _blocks
      .where((block) => _circle == null || block.circle == _circle)
      .where((block) => _district == null || block.district == _district)
      .toList();

  TaskModel? get _selectedBlock {
    for (final task in _blocks) {
      if (task.id == _blockId) return task;
    }
    return null;
  }

  List<TaskModel> get _rings =>
      HindranceTaskDataSource.ringsForBlock(_selectedBlock, _tasks);

  TaskModel? get _selectedRing {
    for (final task in _rings) {
      if (task.id == _ringId) return task;
    }
    return null;
  }

  List<TaskSegmentModel> get _segments {
    final group = _routeGroups
        .where((candidate) => candidate.key == _routeGroupKey)
        .firstOrNull;
    if (_routeGroups.isNotEmpty) return group?.segments ?? const [];
    return _ringSegments;
  }

  List<TaskSegmentModel> get _ringSegments {
    final ring = _selectedRing;
    if (ring == null) return const [];
    final explicitSegments =
        HindranceTaskDataSource.segmentsForRing(ring, _tasks)
            .map(
              (task) => TaskSegmentModel(
                taskId: task.id,
                segmentCode: _taskSegmentCode(task),
                startNode: task.routeSnapshot?.startNode?.name ?? '',
                targetNode: task.routeSnapshot?.targetNode?.name ?? '',
                distanceKm: task.routeSnapshot?.distanceKm ?? 0,
                startLat: task.routeSnapshot?.segments.firstOrNull?.startLat,
                startLng: task.routeSnapshot?.segments.firstOrNull?.startLng,
                targetLat: task.routeSnapshot?.segments.firstOrNull?.targetLat,
                targetLng: task.routeSnapshot?.segments.firstOrNull?.targetLng,
                groupStart:
                    task.routeSnapshot?.segments.firstOrNull?.groupStart,
                groupEnd: task.routeSnapshot?.segments.firstOrNull?.groupEnd,
                groupStartId:
                    task.routeSnapshot?.segments.firstOrNull?.groupStartId,
                groupEndId:
                    task.routeSnapshot?.segments.firstOrNull?.groupEndId,
                sequenceNo:
                    task.routeSnapshot?.segments.firstOrNull?.sequenceNo,
              ),
            )
            .toList();
    if (explicitSegments.isNotEmpty) return explicitSegments;

    final embedded = ring.routeSnapshot?.segments.isNotEmpty == true
        ? ring.routeSnapshot!.segments
        : ring.segmentSnapshots;
    if (embedded.isNotEmpty) {
      return embedded
          .where((segment) => segment.segmentCode.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<HindranceRouteGroup> get _routeGroups =>
      HindranceTaskDataSource.routeGroupsForSegments(_ringSegments);

  void _restoreRouteGroupFromSelection() {
    if (_routeGroupKey != null &&
        _routeGroups.any((group) => group.key == _routeGroupKey)) {
      return;
    }
    if (_segmentCodes.isEmpty || _routeGroups.isEmpty) return;
    final matches = _routeGroups.where((group) {
      final codes = group.segments
          .map((segment) => segment.segmentCode)
          .toSet();
      return _segmentCodes.every(codes.contains);
    }).toList();
    _routeGroupKey = matches.length == 1 ? matches.single.key : null;
  }

  String _taskName(TaskModel? task, String? fallback) {
    final name = task?.displayName.trim() ?? '';
    return name.isNotEmpty && name != 'Unnamed Task'
        ? name
        : (fallback?.trim().isNotEmpty == true
              ? fallback!.trim()
              : task?.taskCode ?? '');
  }

  String _taskSegmentCode(TaskModel task) {
    final routeCode = task.routeSnapshot?.routeCode.trim() ?? '';
    if (routeCode.isNotEmpty && routeCode != 'N/A') return routeCode;
    if (task.taskCode.trim().isNotEmpty) return task.taskCode.trim();
    return task.displayName.trim();
  }

  Future<void> _continueFromHierarchy() async {
    if (_blockId == null ||
        _ringId == null ||
        _segmentCodes.isEmpty ||
        (_routeGroups.isNotEmpty && _routeGroupKey == null)) {
      return;
    }
    final ownerId = _ownerId;
    if (ownerId != null) {
      final hasCachedPack = _cachedTasks.any((task) => task.id == _blockId);
      if (_taskListHasMore && !hasCachedPack) {
        _showMessage(
          'Load all task pages to save a complete offline hierarchy.',
        );
        return;
      }
      try {
        await _taskSource.cacheBlockHierarchy(
          ownerId: ownerId,
          blockId: _blockId!,
          tasks: _taskListHasMore ? _cachedTasks : _tasks,
        );
      } catch (error) {
        _showMessage('Could not save this task hierarchy offline: $error');
        return;
      }
    }
    setState(() => _hierarchyConfirmed = true);
    await _persist();
  }

  void _scheduleSave() {
    if (_reportId == null || _ownerId == null) return;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 400), () => _persist());
  }

  Map<String, dynamic> _payload({String? state}) => {
    'recordType': 'CCN',
    'reportId': _reportId,
    'ccnId': _ccnId,
    'serverTaskId': _serverTaskId,
    'hindranceId': widget.hindrance['hindranceId'],
    'hindranceReportId': widget.hindrance['reportId'],
    'hindranceSummary': widget.hindrance,
    'blockId': _blockId,
    'blockName': _taskName(
      _selectedBlock,
      widget.hindrance['blockName']?.toString(),
    ),
    'ringId': _ringId,
    'ringName': _taskName(
      _selectedRing,
      widget.hindrance['ringName']?.toString(),
    ),
    'routeGroupKey': _routeGroupKey,
    'routeGroupName': _routeGroups
        .where((group) => group.key == _routeGroupKey)
        .map((group) => group.label)
        .firstOrNull,
    'affectedSegments': _selectedSegmentPayload,
    'category': _category,
    'subtype': _subtype,
    'description': _description.text,
    'media': List<Map<String, dynamic>>.from(_media),
    'routePoints': _routePoints,
    'proposedRoutePoints': _proposedRoutePoints,
    'existingRouteEvidence': _media
        .where(
          (item) =>
              (item['slot']?.toString() ?? '').startsWith('ccn_') &&
              !(item['slot']?.toString() ?? '').startsWith('ccn_new_'),
        )
        .toList(),
    'routeApprovalStatus': _approvalStatus,
    'kmlChoice': _kmlChoice,
    'kmlArtifact': _kmlArtifact,
    'queueState': state ?? 'LOCAL_SAVED',
    'createdAt': _createdAt,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  Future<bool> _persist({String? state}) async {
    if (_reportId == null || _ownerId == null) return false;
    try {
      await _store.saveReport(
        reportId: _reportId!,
        ownerId: _ownerId!,
        state: state ?? 'LOCAL_SAVED',
        payload: _payload(state: state),
        createdAt:
            DateTime.tryParse(_createdAt ?? '') ?? DateTime.now().toUtc(),
      );
      return true;
    } catch (error) {
      _showMessage('Could not save the CCN locally: $error');
      return false;
    }
  }

  Future<void> _capturePhoto(String slot) async {
    if (_saving || _ownerId == null || _reportId == null) return;
    setState(() => _saving = true);
    try {
      final media = await _mediaService.capturePhoto(
        ownerId: _ownerId!,
        reportId: _reportId!,
        slot: 'ccn_$slot',
        recordType: 'CCN',
        createdAt: DateTime.tryParse(_createdAt ?? ''),
      );
      if (media != null && mounted) {
        setState(() {
          _media.add(media);
          _invalidateKml();
        });
        await _persist();
      }
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _captureVideo(String slot, Duration maxDuration) async {
    if (_saving || _ownerId == null || _reportId == null) return;
    setState(() => _saving = true);
    var trackingStarted = false;
    List<Map<String, dynamic>> trace = [];
    try {
      if (slot.contains('walkthrough')) {
        try {
          await _routeRecorder.start();
          trackingStarted = true;
        } catch (error) {
          _showMessage('Route GPS sampling could not start: $error');
        }
      }
      Map<String, dynamic>? media;
      if (slot.contains('walkthrough')) {
        final captureLocation = await _mediaService.getFreshLocation();
        if (!mounted) return;
        final recorded = await Navigator.of(context).push<RecordedCcnVideo>(
          MaterialPageRoute(
            builder: (_) => CcnCameraRecordingScreen(maxDuration: maxDuration),
          ),
        );
        if (recorded != null) {
          media = await _mediaService.storeRecordedVideo(
            picked: recorded.file,
            location: captureLocation,
            ownerId: _ownerId!,
            reportId: _reportId!,
            slot: 'ccn_$slot',
            duration: recorded.duration,
            maxDuration: maxDuration,
            recordType: 'CCN',
            createdAt: DateTime.tryParse(_createdAt ?? ''),
          );
        }
      } else {
        media = await _mediaService.captureVideo(
          ownerId: _ownerId!,
          reportId: _reportId!,
          slot: 'ccn_$slot',
          maxDuration: maxDuration,
          recordType: 'CCN',
          createdAt: DateTime.tryParse(_createdAt ?? ''),
        );
      }
      if (trackingStarted) trace = await _routeRecorder.stop();
      final capturedMedia = media;
      if (capturedMedia != null && mounted) {
        capturedMedia['routePoints'] = trace;
        capturedMedia['routeSampling'] = '3m_or_10s_while_app_active';
        setState(() {
          _media.add(capturedMedia);
          if (slot == 'walkthrough') _routePoints = trace;
          if (slot == 'new_walkthrough') _proposedRoutePoints = trace;
          _invalidateKml();
        });
        await _persist();
      }
    } catch (error) {
      if (trackingStarted) await _routeRecorder.stop();
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeMedia(Map<String, dynamic> item) async {
    final slot = item['slot']?.toString();
    final dependentSlots = switch (slot) {
      'ccn_start_point' => {
        'ccn_start_photo',
        'ccn_walkthrough',
        'ccn_additional_video',
        'ccn_end_point',
        'ccn_additional_photo',
        'ccn_endpoint_video',
      },
      'ccn_new_start_point' => {'ccn_new_walkthrough', 'ccn_new_end_point'},
      'ccn_new_walkthrough' => {'ccn_new_end_point'},
      'ccn_walkthrough' => {
        'ccn_additional_video',
        'ccn_end_point',
        'ccn_additional_photo',
        'ccn_endpoint_video',
      },
      _ => <String>{},
    };
    final removed = _media
        .where(
          (media) =>
              identical(media, item) || dependentSlots.contains(media['slot']),
        )
        .toList();
    for (final media in removed) {
      await _mediaService.deleteFileManagerCopy(media);
      if ((media['storage'] == 'indexeddb' || media['storage'] == 'database') &&
          media['mediaId'] != null) {
        await _store.deleteMediaBytes(media['mediaId'].toString());
      } else if (media['storage'] == 'file' && media['path'] != null) {
        await _mediaService.deleteLocalMediaFiles(media);
      }
    }
    if (!mounted) return;
    setState(() {
      _media.removeWhere(removed.contains);
      if (slot == 'ccn_walkthrough') _routePoints.clear();
      if (slot == 'ccn_new_walkthrough') _proposedRoutePoints.clear();
      if (slot == 'ccn_start_point' || slot == 'ccn_walkthrough') {
        _routePoints.clear();
      }
      if (slot == 'ccn_new_start_point' || slot == 'ccn_new_walkthrough') {
        _proposedRoutePoints.clear();
      }
      _invalidateKml();
    });
    await _persist();
  }

  Future<void> _retakeMedia(String slot, {Duration? duration}) async {
    final existingIndex = _media.indexWhere((m) => m['slot'] == slot);
    if (existingIndex != -1) {
      final oldMedia = _media[existingIndex];
      await _mediaService.deleteFileManagerCopy(oldMedia);
      final mediaId = oldMedia['mediaId']?.toString();
      final path = oldMedia['path']?.toString();
      if (oldMedia['storage'] == 'indexeddb' && mediaId != null) {
        try {
          await _store.deleteMediaBytes(mediaId);
        } catch (_) {}
      } else if (path != null) {
        try {
          await _mediaService.deleteLocalMediaFiles(oldMedia);
        } catch (_) {}
      }
      setState(() {
        _media.removeAt(existingIndex);
      });
    }
    if (slot.contains('video') || slot.contains('walkthrough')) {
      await _captureVideo(slot, duration ?? const Duration(minutes: 5));
    } else {
      await _capturePhoto(slot);
    }
  }

  void _invalidateKml() {
    final previous = _kmlArtifact;
    final mediaId = previous?['mediaId']?.toString();
    _kmlArtifact = null;
    _kmlChoice = 'generated';
    if (mediaId != null) unawaited(_store.deleteMediaBytes(mediaId));
    if (previous != null) {
      unawaited(_mediaService.deleteFileManagerCopy(previous));
    }
  }

  Future<void> _useGeneratedKml() async {
    try {
      final text = HindranceKml.build(
        name: _ccnId ?? 'CCN route',
        routePoints: _proposedPreviewPoints,
      );
      final artifact = await _mediaService.storePickedBytes(
        ownerId: _ownerId!,
        reportId: _reportId!,
        filename: '${_ccnId ?? 'route'}.kml',
        kind: 'kml',
        bytes: Uint8List.fromList(utf8.encode(text)),
        recordType: 'CCN',
        createdAt: DateTime.tryParse(_createdAt ?? ''),
      );
      artifact['previewPoints'] = _proposedPreviewPoints;
      artifact['source'] = 'generated_from_captured_gps';
      final previousArtifact = _kmlArtifact;
      final previousId = previousArtifact?['mediaId']?.toString();
      setState(() {
        _kmlArtifact = artifact;
        _kmlChoice = 'generated';
      });
      if (previousId != null) {
        await _store.deleteMediaBytes(previousId);
      }
      if (previousArtifact != null) {
        await _mediaService.deleteFileManagerCopy(previousArtifact);
      }
      await _persist();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('FormatException: ', ''));
    }
  }

  Future<void> _uploadKml() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['kml'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('Could not read the KML file.');
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final points = HindranceKml.parse(text);
      final artifact = await _mediaService.storePickedBytes(
        ownerId: _ownerId!,
        reportId: _reportId!,
        filename: file.name,
        kind: 'kml',
        bytes: bytes,
        recordType: 'CCN',
        createdAt: DateTime.tryParse(_createdAt ?? ''),
      );
      artifact['previewPoints'] = points;
      artifact['source'] = 'uploaded_kml';
      final previousArtifact = _kmlArtifact;
      final previousId = previousArtifact?['mediaId']?.toString();
      setState(() {
        _kmlArtifact = artifact;
        _kmlChoice = 'uploaded';
      });
      if (previousId != null) await _store.deleteMediaBytes(previousId);
      if (previousArtifact != null) {
        await _mediaService.deleteFileManagerCopy(previousArtifact);
      }
      await _persist();
    } catch (error) {
      _showMessage('Could not read this KML: ${error.toString()}');
    }
  }

  Future<void> _submit() async {
    if (!_routeReady) {
      _showMessage(
        'Capture both route sets: existing start photo, walkthrough video and end-point video, then the proposed start photo, walkthrough video and end-point video.',
      );
      return;
    }
    if (_kmlArtifact == null) {
      _showMessage('Generate a KML or choose a KML file before submitting.');
      return;
    }
    final block = _selectedBlock;
    final ring = _selectedRing;
    final segments = _segments.where(_isSegmentSelected).toList();
    if (block == null || ring == null || segments.isEmpty) {
      _showMessage('Select a Block, Ring, and at least one segment first.');
      return;
    }
    final ownerId = _ownerId;
    final reportId = _reportId;
    if (ownerId == null || reportId == null) {
      _showMessage('Save this CCN on the device before submitting.');
      return;
    }
    if (PendingSyncManager.instance.isActive(reportId)) return;
    final linkedReportId = widget.hindrance['reportId']?.toString();
    setState(() => _saving = true);
    try {
      var totalBytes = 0;
      for (final item in _media) {
        final size = await _savedFileSize(item);
        item['sizeBytes'] = size;
        totalBytes += size;
      }
      final createdAt =
          DateTime.tryParse(_createdAt ?? '') ?? DateTime.now().toUtc();
      final report = _payload(state: 'PENDING_SYNC')
        ..['syncBytesTotal'] = totalBytes
        ..['syncBytesSent'] = 0
        ..['syncPhase'] = 'QUEUED'
        ..['syncError'] = null;
      report['createdAt'] = createdAt.toIso8601String();
      report['queueState'] = 'PENDING_SYNC';
      await _store.saveReport(
        reportId: reportId,
        ownerId: ownerId,
        state: 'PENDING_SYNC',
        payload: report,
        createdAt: createdAt,
      );
      if (!mounted) return;
      PendingSyncManager.instance.start(
        id: reportId,
        formType: 'CCN',
        totalBytes: totalBytes,
        files: _media.map(PendingSyncManager.fileLabel).toList(),
        run: (onBytesSent) async {
          var sentBytes = _media
              .where((item) => item['uploadKey'] != null)
              .fold<int>(
                0,
                (sum, item) =>
                    sum +
                    (int.tryParse(item['sizeBytes']?.toString() ?? '') ?? 0),
              );
          var lastPersistedBytes = sentBytes;
          report['syncBytesSent'] = sentBytes;
          Future<void> checkpoint(String state) async {
            report['queueState'] = state;
            report['updatedAt'] = DateTime.now().toUtc().toIso8601String();
            PendingSyncManager.instance.updateDetails(
              reportId,
              phase: report['syncPhase']?.toString() ?? state,
              currentFile: report['syncCurrentFile']?.toString(),
              clearCurrentFile: report['syncCurrentFile'] == null,
            );
            await _store.saveReport(
              reportId: reportId,
              ownerId: ownerId,
              state: state,
              payload: report,
              createdAt: createdAt,
            );
          }

          try {
            report['syncPhase'] = _serverTaskId == null
                ? 'CREATING_TASK'
                : 'UPLOADING';
            await checkpoint('SYNCING');
            if (sentBytes > 0) {
              await onBytesSent(sentBytes);
              await checkpoint('SYNCING');
            }
            final taskId = await _submissionService.submitCcn(
              block: block,
              ring: ring,
              segments: segments,
              report: report,
              existingTaskId: _serverTaskId,
              onTaskCreated: (createdTaskId) async {
                report
                  ..['serverTaskId'] = createdTaskId
                  ..['ccnId'] = createdTaskId
                  ..['syncPhase'] = 'UPLOADING';
                await checkpoint('SYNCING');
              },
              onUploadFile: (fileName) async {
                report
                  ..['syncPhase'] = 'UPLOADING'
                  ..['syncCurrentFile'] = fileName;
                await checkpoint('SYNCING');
              },
              onUploadProgress: () => checkpoint('SYNCING'),
              onBeforeSave: () async {
                report['syncPhase'] = 'SAVING';
                report.remove('syncCurrentFile');
                await checkpoint('SYNCING');
              },
              onBeforeSubmit: () async {
                report['syncPhase'] = 'SUBMITTING';
                report.remove('syncCurrentFile');
                await checkpoint('SYNCING');
              },
              onUploadBytes: (count) async {
                sentBytes += count;
                await onBytesSent(count);
                if (sentBytes - lastPersistedBytes >= 1024 * 1024 ||
                    sentBytes >= totalBytes) {
                  report['syncBytesSent'] = sentBytes;
                  lastPersistedBytes = sentBytes;
                  await checkpoint('SYNCING');
                }
              },
            );
            await _mediaService.cleanupOriginalVideosAfterSubmit(
              report['media'] as List,
            );
            report
              ..['serverTaskId'] = taskId
              ..['ccnId'] = taskId
              ..['syncBytesSent'] = totalBytes
              ..['syncError'] = null
              ..['syncPhase'] = 'COMPLETE'
              ..remove('syncCurrentFile');
            await checkpoint('SUBMITTED');
            await _markLinkedHindranceCcnSubmitted(
              ownerId,
              taskId,
              linkedReportId,
            );
          } catch (error) {
            report['syncError'] = error.toString();
            report['syncBytesSent'] = sentBytes;
            report['syncFailedFromPhase'] = report['syncPhase'];
            report['syncPhase'] = 'SYNC_FAILED';
            await checkpoint('SYNC_FAILED');
            rethrow;
          }
        },
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop({'queued': true, 'reportId': reportId});
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<int> _savedFileSize(Map item) async {
    final knownSize = int.tryParse(item['sizeBytes']?.toString() ?? '');
    if (knownSize != null && knownSize > 0) return knownSize;
    final mediaId = item['mediaId']?.toString();
    if (mediaId != null &&
        (item['storage'] == 'indexeddb' || item['storage'] == 'database')) {
      return (await _store.loadMediaBytes(mediaId))?.length ?? 0;
    }
    final path = item['path']?.toString();
    if (path != null && path.isNotEmpty && !kIsWeb) {
      final file = File(path);
      if (await file.exists()) return file.length();
    }
    return 0;
  }

  Future<void> _markLinkedHindranceCcnSubmitted(
    String ownerId,
    String ccnId,
    String? linkedReportId,
  ) async {
    if (linkedReportId == null || linkedReportId.isEmpty) return;
    final reports = await _store.loadReports(ownerId);
    final linked = reports
        .where((item) => item['reportId'] == linkedReportId)
        .firstOrNull;
    if (linked == null) return;
    linked
      ..['ccnRequired'] = true
      ..['ccnId'] = ccnId
      ..['workflowStage'] = 'completed'
      ..['queueState'] = 'SUBMITTED';
    await _store.saveReport(
      reportId: linkedReportId,
      ownerId: ownerId,
      state: 'SUBMITTED',
      payload: linked,
      createdAt:
          DateTime.tryParse(linked['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  List<Map<String, dynamic>> _deduplicatePoints(
    List<Map<String, dynamic>> points,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final point in points) {
      final lat = (point['latitude'] as num?)?.toDouble();
      final lng = (point['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if (result.isNotEmpty) {
        final previous = result.last;
        final previousLat = (previous['latitude'] as num).toDouble();
        final previousLng = (previous['longitude'] as num).toDouble();
        if (lat == previousLat && lng == previousLng) continue;
      }
      result.add(Map<String, dynamic>.from(point));
    }
    return result;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          title: const Text('CCN'),
          backgroundColor: AppColors.headerGreen,
          foregroundColor: Colors.white,
          actions: [
            const PendingSyncAction(),
            IconButton(
              tooltip: 'Saved offline CCNs',
              onPressed: _ownerId == null ? null : _showSavedReports,
              icon: const Icon(Icons.folder_open_outlined),
            ),
          ],
        ),
        body: HindranceGlassBackdrop(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : _showLanding
              ? _buildLandingPage()
              : _hierarchyConfirmed
              ? _buildForm()
              : _buildTaskHierarchyStep(),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: HindranceGlassSurface(
            padding: const EdgeInsets.all(8),
            radius: 22,
            child: SizedBox(
              width: double.infinity,
              child: _showLanding
                  ? FilledButton.icon(
                      onPressed: _startNewCcn,
                      icon: const Icon(Icons.add),
                      label: const Text('Create CCN'),
                    )
                  : _hierarchyConfirmed
                  ? FilledButton.icon(
                      onPressed: _saving || !_routeReady ? null : _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Submitting…' : 'Submit CCN'),
                    )
                  : FilledButton.icon(
                      onPressed:
                          _blockId == null ||
                              _ringId == null ||
                              _segmentCodes.isEmpty ||
                              (_routeGroups.isNotEmpty &&
                                  _routeGroupKey == null)
                          ? null
                          : _continueFromHierarchy,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to CCN'),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandingPage() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    children: [
      _section('CCN', [
        const Icon(
          Icons.route_outlined,
          size: 42,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: 12),
        const Text(
          'Create a Change Control Note',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Start a CCN, then choose the circle, district, block, ring, and affected segments.',
        ),
      ]),
      const SizedBox(height: 4),
      _section('Your CCN History', [
        Row(
          children: [
            const Expanded(child: Text('Tasks created from your account')),
            IconButton(
              tooltip: 'Refresh CCN history',
              onPressed: _loadingCcnHistory ? null : _refreshCcnHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_loadingCcnHistory && _ccnHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_ccnHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('No CCN history is available yet.'),
          )
        else
          ..._ccnHistory.map(_buildCcnHistoryTile),
      ]),
    ],
  );

  Widget _buildCcnHistoryTile(TaskModel task) {
    final taskStatus = task.status.trim();
    final approvalStatus = task.approvalStatus.trim();
    final status =
        taskStatus.isNotEmpty && taskStatus.toUpperCase() != 'UNKNOWN'
        ? taskStatus
        : approvalStatus;
    final date = task.createdAt ?? task.submittedAt;
    final statusText = status.isEmpty || status.toUpperCase() == 'UNKNOWN'
        ? 'Status unavailable'
        : status.replaceAll('_', ' ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.route_outlined)),
      title: Text(
        task.displayName.trim().isEmpty ? task.taskCode : task.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${task.taskCode} • $statusText${date == null ? '' : ' • ${MaterialLocalizations.of(context).formatShortDate(date.toLocal())}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showCcnHistoryDetails(task, statusText),
    );
  }

  Future<void> _showCcnHistoryDetails(TaskModel listedTask, String status) {
    final detailsFuture = _taskApi
        .fetchTaskDetails(listedTask.id)
        .catchError((_) => listedTask);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => FutureBuilder<TaskModel>(
        future: detailsFuture,
        builder: (context, snapshot) {
          final task = snapshot.data ?? listedTask;
          final existing = _historyExistingRoutePoints(task);
          final proposed = _historyProposedRoutePoints(task);
          final canShowMap = existing.length > 1 || proposed.length > 1;
          return AlertDialog(
            title: Text(
              task.displayName.trim().isEmpty ? 'CCN' : task.displayName,
            ),
            content: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Task: ${task.taskCode}'),
                          const SizedBox(height: 8),
                          Text('Status: ${_historyStatus(task, status)}'),
                          if (task.approvalStatus.trim().isNotEmpty)
                            Text(
                              'Approval: ${task.approvalStatus.replaceAll('_', ' ')}',
                            ),
                          if (task.locationSnapshot?.district.isNotEmpty ==
                              true)
                            Text(
                              'District: ${task.locationSnapshot!.district}',
                            ),
                          if (task.locationSnapshot?.circle.isNotEmpty == true)
                            Text('Circle: ${task.locationSnapshot!.circle}'),
                          if ((task.description ?? task.remarks)
                                  ?.trim()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 8),
                            Text(task.description ?? task.remarks!),
                          ],
                          const SizedBox(height: 14),
                          if (canShowMap)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _showCcnHistoryMap(
                                  task,
                                  existing,
                                  proposed,
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Show route map'),
                              ),
                            )
                          else
                            const Text(
                              'Route coordinates are not available in the task response.',
                              style: TextStyle(color: Colors.black54),
                            ),
                        ],
                      ),
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _historyStatus(TaskModel task, String fallback) {
    final status = task.status.trim();
    if (status.isNotEmpty && status.toUpperCase() != 'UNKNOWN') {
      return status.replaceAll('_', ' ');
    }
    return fallback;
  }

  List<Map<String, dynamic>> _historyExistingRoutePoints(TaskModel task) {
    final points = <Map<String, dynamic>>[];
    void addSegment(TaskSegmentModel segment) {
      final start = _coordinatePoint(segment.startLat, segment.startLng);
      final end = _coordinatePoint(segment.targetLat, segment.targetLng);
      if (start != null &&
          (points.isEmpty || !_samePoint(points.last, start))) {
        points.add(start);
      }
      if (end != null && (points.isEmpty || !_samePoint(points.last, end))) {
        points.add(end);
      }
    }

    final segments = task.segmentSnapshots.isNotEmpty
        ? task.segmentSnapshots
        : task.routeSnapshot?.segments ?? const <TaskSegmentModel>[];
    for (final segment in segments) {
      addSegment(segment);
    }
    if (points.length > 1) return points;

    void walkRoutes(List<TaskRouteModel> routes) {
      for (final route in routes) {
        for (final coordinate in route.polylineCoordinates ?? const []) {
          if (coordinate.length < 2) continue;
          final point = _coordinatePoint(coordinate[0], coordinate[1]);
          if (point != null &&
              (points.isEmpty || !_samePoint(points.last, point))) {
            points.add(point);
          }
        }
        if (route.segments.isNotEmpty) {
          for (final segment in route.segments) {
            addSegment(segment);
          }
        }
        walkRoutes(route.childRoutes);
      }
    }

    walkRoutes(task.routeSnapshot?.routes ?? const <TaskRouteModel>[]);
    if (points.length < 2) {
      final start = _coordinatePoint(
        task.routeSnapshot?.startNode?.latitude,
        task.routeSnapshot?.startNode?.longitude,
      );
      final end = _coordinatePoint(
        task.routeSnapshot?.targetNode?.latitude,
        task.routeSnapshot?.targetNode?.longitude,
      );
      if (start != null && end != null) return [start, end];
    }
    return points;
  }

  List<Map<String, dynamic>> _historyProposedRoutePoints(TaskModel task) {
    final fieldData =
        task.meta?['fieldData'] ?? task.meta?['executionFieldData'];
    if (fieldData is! Map) return const [];
    final proposed =
        fieldData['proposedCcn'] ??
        fieldData['proposedCCN'] ??
        fieldData['proposedCcnData'];
    final containers = [if (proposed is Map) proposed, fieldData];
    for (final container in containers) {
      for (final key in const [
        'proposedRoutePoints',
        'routePoints',
        'trace',
        'points',
      ]) {
        final rawPoints = container[key];
        if (rawPoints is! List) continue;
        final points = rawPoints
            .whereType<Map>()
            .map(
              (point) => _coordinatePoint(
                point['latitude'] ?? point['lat'],
                point['longitude'] ?? point['lng'] ?? point['lon'],
              ),
            )
            .whereType<Map<String, dynamic>>()
            .toList();
        if (points.length > 1) return points;
      }
    }

    final photos = proposed is Map ? proposed['photos'] : fieldData['photos'];
    if (photos is! List) return const [];
    final media = photos.whereType<Map>().toList();
    int order(Map item) {
      final label = (item['label'] ?? item['slot'] ?? '')
          .toString()
          .toLowerCase();
      if (label.contains('new_start')) return 0;
      if (label.contains('new_walkthrough')) return 1;
      if (label.contains('new_end')) return 2;
      return 3;
    }

    media.sort((a, b) => order(a).compareTo(order(b)));
    final routePoints = <Map<String, dynamic>>[];
    for (final item in media) {
      for (final key in const ['routePoints', 'gpsPoints', 'trace', 'points']) {
        final rawPoints = item[key];
        if (rawPoints is List) {
          for (final point in rawPoints.whereType<Map>()) {
            final coordinate = _coordinatePoint(
              point['latitude'] ?? point['lat'],
              point['longitude'] ?? point['lng'] ?? point['lon'],
            );
            if (coordinate != null &&
                (routePoints.isEmpty ||
                    !_samePoint(routePoints.last, coordinate))) {
              routePoints.add(coordinate);
            }
          }
        }
      }
      final coordinate = _coordinatePoint(
        item['latitude'] ?? item['lat'],
        item['longitude'] ?? item['lng'] ?? item['lon'],
      );
      if (coordinate != null &&
          (routePoints.isEmpty || !_samePoint(routePoints.last, coordinate))) {
        routePoints.add(coordinate);
      }
    }
    return routePoints;
  }

  void _showCcnHistoryMap(
    TaskModel task,
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> proposed,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('CCN Route Map'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                task.displayName.trim().isEmpty
                    ? task.taskCode
                    : task.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              HindranceRoutePreview(
                existingPoints: existing,
                proposedPoints: proposed,
                proposedRouteApproved:
                    task.approvalStatus.toUpperCase() == 'APPROVED',
                title: 'Existing and proposed routes',
                height: MediaQuery.sizeOf(context).height * 0.68,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskHierarchyStep() {
    final segments = _segments;
    final visibleBlocks = _visibleBlocks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _section('Choose Task Hierarchy', [
          const Text(
            'Select the Block, Ring, and affected Segments before continuing to the CCN form.',
          ),
          if (_tasksFromCache)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _OfflineInfo(),
            ),
          if (_selectedBlock == null && _blockId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'From saved Hindrance: Block ${widget.hindrance['blockName'] ?? _blockId}, '
                'Ring ${widget.hindrance['ringName'] ?? _ringId}, '
                'Segments ${_segmentCodes.join(', ')}',
              ),
            ),
          if (_taskListHasMore)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loadingMoreTasks ? null : _loadMoreTasks,
                icon: _loadingMoreTasks
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(
                  _loadingMoreTasks
                      ? 'Loading tasks…'
                      : 'Load more assigned tasks',
                ),
              ),
            ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('ccn-circle-dropdown-$_circle'),
            initialValue: _circles.contains(_circle) ? _circle : null,
            decoration: const InputDecoration(labelText: 'Circle'),
            isExpanded: true,
            items: _circles
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _circle = value;
              _district = null;
              _blockId = null;
              _ringId = null;
              _routeGroupKey = null;
              _segmentCodes.clear();
              _hierarchyLoadError = null;
              _hierarchyConfirmed = false;
              _scheduleSave();
            }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('ccn-district-dropdown-$_circle-$_district'),
            initialValue: _districts.contains(_district) ? _district : null,
            decoration: const InputDecoration(labelText: 'District'),
            isExpanded: true,
            items: _districts
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _district = value;
              _blockId = null;
              _ringId = null;
              _routeGroupKey = null;
              _segmentCodes.clear();
              _hierarchyLoadError = null;
              _hierarchyConfirmed = false;
              _scheduleSave();
            }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('ccn-block-dropdown-$_blockId'),
            initialValue: visibleBlocks.any((task) => task.id == _blockId)
                ? _blockId
                : null,
            decoration: const InputDecoration(labelText: 'Block'),
            isExpanded: true,
            items: visibleBlocks
                .map(
                  (task) => DropdownMenuItem<String>(
                    value: task.id,
                    child: Text(
                      _taskName(task, null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _selectBlock,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _rings.any((task) => task.id == _ringId)
                ? _ringId
                : null,
            decoration: const InputDecoration(labelText: 'Ring'),
            isExpanded: true,
            hint: Text(
              _blockId == null ? 'Select a Block first' : 'Select Ring',
            ),
            items: _rings
                .map(
                  (task) => DropdownMenuItem<String>(
                    value: task.id,
                    child: Text(
                      _taskName(task, null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _blockId == null || _loadingHierarchy
                ? null
                : (ringId) => setState(() {
                    _ringId = ringId;
                    _routeGroupKey = null;
                    _segmentCodes.clear();
                    _scheduleSave();
                  }),
          ),
          if (_routeGroups.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('ccn-route-group-$_ringId-$_routeGroupKey'),
              initialValue:
                  _routeGroups.any((group) => group.key == _routeGroupKey)
                  ? _routeGroupKey
                  : null,
              decoration: const InputDecoration(labelText: 'Route'),
              hint: const Text('Select a GP route'),
              isExpanded: true,
              items: _routeGroups
                  .map(
                    (group) => DropdownMenuItem(
                      value: group.key,
                      child: Text(
                        '${group.label} · ${group.segments.length} segments · '
                        '${group.segments.fold<double>(0, (sum, segment) => sum + segment.distanceKm).toStringAsFixed(2)} km',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (key) => setState(() {
                _routeGroupKey = key;
                _segmentCodes.clear();
                _scheduleSave();
              }),
            ),
          ],
          if (_loadingHierarchy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_hierarchyLoadError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hierarchyLoadError!,
                      style: const TextStyle(
                        color: Color(0xFF7C2D12),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Affected Segments',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (segments.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final allSelected = segments.every(_isSegmentSelected);
                  for (final segment in segments) {
                    if (allSelected) {
                      _segmentCodes.remove(_segmentSelectionKey(segment));
                      _segmentCodes.remove(segment.segmentCode);
                    } else {
                      _segmentCodes.add(_segmentSelectionKey(segment));
                    }
                  }
                  _scheduleSave();
                }),
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(
                  segments.every(_isSegmentSelected)
                      ? 'Clear segments'
                      : 'Select all ${segments.length}',
                ),
              ),
            ),
          if (segments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Select a Ring and Route with available Segment data.',
              ),
            ),
          if (segments.isNotEmpty)
            SizedBox(
              height: 260,
              child: HindranceGlassSurface(
                padding: EdgeInsets.zero,
                radius: 14,
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      return CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        value: _isSegmentSelected(segment),
                        title: Text(segment.segmentCode),
                        subtitle: Text(
                          '${segment.startNode} → ${segment.targetNode}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _segmentCodes.add(_segmentSelectionKey(segment));
                          } else {
                            _segmentCodes.remove(_segmentSelectionKey(segment));
                            _segmentCodes.remove(segment.segmentCode);
                          }
                          _scheduleSave();
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildForm() {
    final start = _mediaAtStart;
    final walkthrough = _walkthrough;
    final end = _mediaAtEnd;
    final proposedStart = _proposedMediaAtStart;
    final proposedWalkthrough = _proposedWalkthrough;
    final proposedEnd = _proposedMediaAtEnd;
    final startExtras = _media
        .where((item) => item['slot'] == 'ccn_start_photo')
        .toList();
    final videoExtras = _media
        .where((item) => item['slot'] == 'ccn_additional_video')
        .toList();
    final endpointPhotos = _media
        .where((item) => item['slot'] == 'ccn_additional_photo')
        .toList();
    final endpointVideos = _media
        .where((item) => item['slot'] == 'ccn_endpoint_video')
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _section('CCN Details', [
          _detailLine('CCN ID', _ccnId ?? 'Creating…'),
          if (widget.hindrance['hindranceId'] != null)
            _detailLine(
              'Hindrance ID',
              widget.hindrance['hindranceId'].toString(),
            ),
          if (widget.hindrance['blockName'] != null)
            _detailLine('Block', widget.hindrance['blockName'].toString()),
          if (widget.hindrance['ringName'] != null)
            _detailLine('Ring', widget.hindrance['ringName'].toString()),
        ]),
        _section('Classification', [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Subtype 1'),
            isExpanded: true,
            hint: const Text('Select category'),
            items: ccnCategories
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _category = value;
              _subtype = null;
              _scheduleSave();
            }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _subtype,
            decoration: const InputDecoration(labelText: 'Subtype 2'),
            isExpanded: true,
            hint: Text(
              _category == null ? 'Select Subtype 1 first' : 'Select subtype',
            ),
            items: (ccnSubtypes[_category] ?? const <String>[])
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _category == null
                ? null
                : (value) => setState(() {
                    _subtype = value;
                    _scheduleSave();
                  }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'CCN details'),
          ),
        ]),
        _section('Route Evidence', [
          const Text(
            'Existing approved route evidence',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _captureStep(
            'Start Point',
            'Capture Start Photo',
            start,
            slot: 'start_point',
            enabled: !_saving && start == null,
            onPressed: () => _capturePhoto('start_point'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Additional start photos (up to 4)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          _mediaGrid(startExtras),
          OutlinedButton.icon(
            onPressed: !_saving && startExtras.length < 4
                ? () => _capturePhoto('start_photo')
                : null,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text('Add start photo (${startExtras.length}/4)'),
          ),
          const SizedBox(height: 14),
          _captureStep(
            'Route Walk Video · up to 5 minutes',
            'Capture Video',
            walkthrough,
            slot: 'walkthrough',
            enabled: !_saving && walkthrough == null,
            onPressed: () =>
                _captureVideo('walkthrough', const Duration(minutes: 5)),
            helper:
                'GPS is sampled at 3 m movement or every 10 seconds while the app can access location.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Additional route videos (up to 4)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          _mediaGrid(videoExtras),
          OutlinedButton.icon(
            onPressed: !_saving && videoExtras.length < 4
                ? () => _captureVideo(
                    'additional_video',
                    const Duration(minutes: 3),
                  )
                : null,
            icon: const Icon(Icons.video_call_outlined),
            label: Text('Add route video (${videoExtras.length}/4)'),
          ),
          const SizedBox(height: 14),
          _captureStep(
            'End Point Photo',
            'Capture End-Point Photo',
            end,
            slot: 'end_point',
            enabled: !_saving && end == null,
            onPressed: () => _capturePhoto('end_point'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Additional endpoint photos (up to 10)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          _mediaGrid(endpointPhotos),
          OutlinedButton.icon(
            onPressed: !_saving && endpointPhotos.length < 10
                ? () => _capturePhoto('additional_photo')
                : null,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text('Add endpoint photo (${endpointPhotos.length}/10)'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Additional endpoint videos (up to 2)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          _mediaGrid(endpointVideos),
          OutlinedButton.icon(
            onPressed: !_saving && endpointVideos.length < 2
                ? () => _captureVideo(
                    'endpoint_video',
                    const Duration(minutes: 3),
                  )
                : null,
            icon: const Icon(Icons.video_call_outlined),
            label: Text('Add endpoint video (${endpointVideos.length}/2)'),
          ),
        ]),
        _section('New Route Proposal', [
          const Text(
            'Capture the proposed alignment separately. Its GPS trace is shown as a grey dotted line until it is approved.',
          ),
          const SizedBox(height: 10),
          _captureStep(
            'Proposed Start Point',
            'Capture Proposed Start Photo',
            proposedStart,
            slot: 'new_start_point',
            enabled: !_saving && proposedStart == null,
            onPressed: () => _capturePhoto('new_start_point'),
          ),
          const SizedBox(height: 12),
          _captureStep(
            'Proposed Route Walk Video · up to 5 minutes',
            'Capture Proposed Route Video',
            proposedWalkthrough,
            slot: 'new_walkthrough',
            enabled: !_saving && proposedWalkthrough == null,
            onPressed: () =>
                _captureVideo('new_walkthrough', const Duration(minutes: 5)),
            helper:
                'GPS is sampled during this video for the proposed alignment.',
          ),
          const SizedBox(height: 12),
          _captureStep(
            'Proposed End Point Photo',
            'Capture Proposed End-Point Photo',
            proposedEnd,
            slot: 'new_end_point',
            enabled: !_saving && proposedEnd == null,
            onPressed: () => _capturePhoto('new_end_point'),
          ),
        ]),
        if (_routeReady)
          HindranceRoutePreview(
            existingPoints: _previewPoints.length > 1
                ? _previewPoints
                : _existingRoutePoints,
            proposedPoints: _displayPoints,
            proposedRouteApproved: _isProposedRouteApproved,
            title: _kmlArtifact == null
                ? 'Existing and proposed routes'
                : 'KML route preview',
          ),
        if (_serverTaskId?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Route review status: $_approvalStatus')),
                IconButton(
                  tooltip: 'Refresh review status',
                  onPressed: _saving ? null : _refreshApprovalStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        _section('KML Route File', [
          const Text(
            'Choose the generated route or select an existing KML. The file and preview stay available offline.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Use generated KML'),
                selected: _kmlChoice == 'generated' && _kmlArtifact != null,
                onSelected: !_routeReady ? null : (_) => _useGeneratedKml(),
              ),
              ChoiceChip(
                label: const Text('Upload KML'),
                selected: _kmlChoice == 'uploaded',
                onSelected: !_routeReady ? null : (_) => _uploadKml(),
              ),
            ],
          ),
          if (_kmlArtifact != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.primaryGreen,
              ),
              title: Text(
                (_kmlArtifact!['filename'] ?? 'route.kml').toString(),
              ),
              subtitle: Text(
                _kmlArtifact?['fileManagerFolder']?.toString() ??
                    'Saved on this device · upload waits for API integration',
              ),
              trailing: IconButton(
                tooltip: 'Remove KML',
                onPressed: () async {
                  if (_kmlArtifact?['mediaId'] != null) {
                    await _store.deleteMediaBytes(
                      _kmlArtifact!['mediaId'].toString(),
                    );
                  }
                  setState(() => _invalidateKml());
                  await _persist();
                },
                icon: const Icon(Icons.close),
              ),
            ),
        ]),
        const _OfflineInfo(),
      ],
    );
  }

  Future<void> _showSavedReports() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final reports = (await _store.loadReports(ownerId))
        .where(
          (report) =>
              report['recordType'] == 'CCN' &&
              (widget.hindrance.isEmpty ||
                  report['hindranceReportId'] == widget.hindrance['reportId']),
        )
        .toList();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saved CCNs'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(dialogContext).width - 80)
              .clamp(0.0, 420.0)
              .toDouble(),
          child: reports.isEmpty
              ? const Text('No saved CCN reports are available offline.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return ListTile(
                      title: Text((report['ccnId'] ?? 'CCN').toString()),
                      subtitle: Text(
                        (report['queueState'] ?? 'LOCAL_SAVED').toString(),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(dialogContext, report),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selected != null) _resumeReport(selected);
  }

  void _resumeReport(Map<String, dynamic> report) {
    final reportId = report['reportId']?.toString() ?? '';
    if (PendingSyncManager.instance.isActive(reportId)) {
      _showMessage('This CCN is syncing. Check Pending sync for progress.');
      return;
    }
    setState(() {
      _showLanding = false;
      _reportId = report['reportId']?.toString();
      _ccnId = report['ccnId']?.toString();
      _serverTaskId = report['serverTaskId']?.toString();
      _createdAt = report['createdAt']?.toString();
      _category = report['category']?.toString();
      _subtype = report['subtype']?.toString();
      _approvalStatus = report['routeApprovalStatus']?.toString() ?? 'PENDING';
      _description.text = report['description']?.toString() ?? '';
      _media
        ..clear()
        ..addAll(
          (report['media'] as List? ?? const []).whereType<Map>().map(
            Map<String, dynamic>.from,
          ),
        );
      _routePoints = (report['routePoints'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      _proposedRoutePoints =
          (report['proposedRoutePoints'] as List? ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
      _kmlChoice = report['kmlChoice']?.toString() ?? 'generated';
      _kmlArtifact = report['kmlArtifact'] is Map
          ? Map<String, dynamic>.from(report['kmlArtifact'] as Map)
          : null;
      final savedHindrance = report['hindranceSummary'] is Map
          ? Map<String, dynamic>.from(report['hindranceSummary'] as Map)
          : <String, dynamic>{};
      _blockId =
          report['blockId']?.toString() ??
          savedHindrance['blockId']?.toString();
      _ringId =
          report['ringId']?.toString() ?? savedHindrance['ringId']?.toString();
      _routeGroupKey =
          report['routeGroupKey']?.toString() ??
          savedHindrance['routeGroupKey']?.toString();
      _segmentCodes
        ..clear()
        ..addAll(
          ((report['affectedSegments'] as List?) ??
                  (savedHindrance['affectedSegments'] as List?) ??
                  const [])
              .whereType<Map>()
              .map((segment) => segment['code']?.toString() ?? '')
              .where((code) => code.isNotEmpty),
        );
      _hierarchyConfirmed =
          _blockId != null && _ringId != null && _segmentCodes.isNotEmpty;
    });
    if (_serverTaskId?.isNotEmpty == true) {
      unawaited(_refreshApprovalStatus());
    }
  }

  Future<void> _refreshApprovalStatus() async {
    final taskId = _serverTaskId;
    if (taskId == null || taskId.isEmpty) return;
    try {
      final task = await _taskApi.fetchTaskDetails(taskId);
      final approval = task.approvalStatus.trim().toUpperCase();
      final taskStatus = task.status.trim().toUpperCase();
      final status = approval.isNotEmpty && approval != 'UNKNOWN'
          ? approval
          : taskStatus == 'APPROVED'
          ? 'APPROVED'
          : 'PENDING';
      if (!mounted || status == _approvalStatus) return;
      setState(() => _approvalStatus = status);
      await _persist();
    } catch (_) {
      // Keep the last server-confirmed state if the review endpoint is offline.
    }
  }

  Widget _section(String title, List<Widget> children) => HindranceGlassSurface(
    margin: const EdgeInsets.only(bottom: 14),
    radius: 18,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Divider(height: 22),
        ...children,
      ],
    ),
  );

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  void _showMediaViewer(Map<String, dynamic> record) {
    final path = record['path']?.toString() ?? '';
    final filename =
        record['filename']?.toString() ??
        record['path']?.toString().split('/').last ??
        'Saved Evidence';
    final location = record['location'] as Map<String, dynamic>?;
    final lat = location?['latitude'];
    final lng = location?['longitude'];
    final isVideo = record['kind'] == 'video';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isVideo
                    ? Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_fill,
                                size: 56,
                                color: AppColors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                filename,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : record['storage'] == 'indexeddb'
                    ? FutureBuilder<Uint8List?>(
                        future: HindranceLocalStore.instance.loadMediaBytes(
                          record['mediaId'].toString(),
                        ),
                        builder: (context, snapshot) {
                          final bytes = snapshot.data;
                          if (bytes == null) {
                            return Container(
                              height: 220,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return Image.memory(
                            bytes,
                            height: 260,
                            fit: BoxFit.contain,
                          );
                        },
                      )
                    : Image.file(
                        File(path),
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (lat != null && lng != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GPS Coordinates:\n$lat, $lng',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(Map<String, dynamic> record) {
    final isVideo = record['kind'] == 'video';
    final path = record['path']?.toString() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: isVideo ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        child: isVideo
            ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 26)
            : record['storage'] == 'indexeddb'
            ? FutureBuilder<Uint8List?>(
                future: HindranceLocalStore.instance.loadMediaBytes(
                  record['mediaId'].toString(),
                ),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return const Center(
                      child: Icon(Icons.image, size: 20, color: Colors.grey),
                    );
                  }
                  return Image.memory(bytes, fit: BoxFit.cover);
                },
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image, size: 20, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _captureStep(
    String title,
    String label,
    Map<String, dynamic>? record, {
    required bool enabled,
    required VoidCallback onPressed,
    String? slot,
    String? helper,
  }) {
    final resolvedSlot = slot ?? record?['slot']?.toString() ?? 'evidence';
    final filename =
        record?['filename']?.toString() ??
        record?['path']?.toString().split('/').last ??
        'Saved evidence';
    final location = record?['location'] as Map<String, dynamic>?;
    final lat = location?['latitude'];
    final lng = location?['longitude'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (helper != null && record == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              helper,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        if (record == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: Icon(
                title.toLowerCase().contains('video')
                    ? Icons.videocam_outlined
                    : Icons.camera_alt_outlined,
              ),
              label: Text(label),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showMediaViewer(record),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _buildMediaThumbnail(record),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showMediaViewer(record),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.deepNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lat != null && lng != null
                              ? '$lat, $lng'
                              : 'Geotagged Location',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (record['fileManagerFolder'] != null ||
                            record['fileManagerExportError'] != null)
                          Text(
                            record['fileManagerExportError'] != null
                                ? 'File manager copy failed'
                                : 'Files: ${record['fileManagerFolder']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: record['fileManagerExportError'] != null
                                  ? Colors.red
                                  : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (record['kind'] == 'video')
                          Text(
                            _videoCompressionSummary(record),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _retakeMedia(
                        resolvedSlot,
                        duration:
                            resolvedSlot.contains('video') ||
                                resolvedSlot == 'walkthrough'
                            ? const Duration(minutes: 5)
                            : const Duration(minutes: 3),
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                      tooltip: 'Retake',
                    ),
                    IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _removeMedia(record),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.criticalRed,
                        size: 20,
                      ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _videoCompressionSummary(Map<String, dynamic> record) {
    final size = int.tryParse(record['sizeBytes']?.toString() ?? '') ?? 0;
    final originalSize =
        int.tryParse(record['originalSizeBytes']?.toString() ?? '') ?? 0;
    String sizeText(int bytes) => bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (record['videoHandling'] == 'h264_aac_compressed_max_1080p' &&
        originalSize > 0) {
      return '1080p max · device frame rate · ${sizeText(size)} (from ${sizeText(originalSize)})';
    }
    if (record['videoHandling'] == 'original_kept_compression_failed') {
      return 'Compression failed · original kept · ${sizeText(size)}';
    }
    return 'Video · ${sizeText(size)}';
  }

  Widget _mediaGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'None added',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isVideo = item['kind'] == 'video';
        final path = item['path']?.toString() ?? '';
        final location = item['location'] as Map<String, dynamic>?;
        final lat = location?['latitude'];
        final lng = location?['longitude'];
        final labelName = isVideo
            ? 'VID_${index + 1}'
            : 'IMG_${(index + 1).toString().padLeft(2, '0')}';

        return GestureDetector(
          onTap: () => _showMediaViewer(item),
          child: SizedBox(
            width: 90,
            height: 95,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isVideo
                          ? const Color(0xFF1E293B)
                          : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: isVideo
                                ? const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  )
                                : item['storage'] == 'indexeddb'
                                ? FutureBuilder<Uint8List?>(
                                    future: _store.loadMediaBytes(
                                      item['mediaId'].toString(),
                                    ),
                                    builder: (context, snapshot) {
                                      final bytes = snapshot.data;
                                      if (bytes == null) {
                                        return const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 24,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      );
                                    },
                                  )
                                : Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                labelName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepNavy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lat != null && lng != null)
                                Text(
                                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeMedia(item),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.criticalRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OfflineInfo extends StatelessWidget {
  const _OfflineInfo();
  @override
  Widget build(BuildContext context) => HindranceGlassSurface(
    padding: const EdgeInsets.all(14),
    radius: 16,
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, color: AppColors.primaryGreen),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Drafts save on this device. When online, Submit CCN creates and submits the task and uploads photos. Walkthrough video, route points, and KML remain on this device.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

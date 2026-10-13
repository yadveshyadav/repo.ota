import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hero_app/core/constants/app_constants.dart';
import 'package:hero_app/core/theme/app_colors.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/features/hindrance/data/hindrance_local_store.dart';
import 'package:hero_app/features/hindrance/data/hindrance_classification.dart';
import 'package:hero_app/features/hindrance/data/hindrance_media_service.dart';
import 'package:hero_app/features/hindrance/data/hindrance_submission_service.dart';
import 'package:hero_app/features/hindrance/data/pending_sync_manager.dart';
import 'package:hero_app/features/hindrance/data/hindrance_task_data_source.dart';
import 'package:hero_app/features/hindrance/screens/ccn_workflow_screen.dart';
import 'package:hero_app/features/hindrance/widgets/hindrance_glass_surface.dart';
import 'package:hero_app/features/hindrance/widgets/pending_sync_action.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/models/task_filter.dart';
import 'package:hero_app/services/api/task_api_service.dart';
import 'package:uuid/uuid.dart';

class HindranceScreen extends StatefulWidget {
  const HindranceScreen({super.key, this.workflowType = 'HINDRANCE'});

  /// OTN shares the location hierarchy and evidence capture UI. Its API is
  /// intentionally not routed through the Hindrance submit contract.
  final String workflowType;

  @override
  State<HindranceScreen> createState() => _HindranceScreenState();
}

class _HindranceScreenState extends State<HindranceScreen>
    with WidgetsBindingObserver {
  bool get _isOtn => widget.workflowType.trim().toUpperCase() == 'OTN';
  String get _recordType => _isOtn ? 'OTN' : 'HINDRANCE';
  String get _workflowLabel => _isOtn ? 'OTN' : 'Hindrance';
  static const _uuid = Uuid();
  final _store = HindranceLocalStore.instance;
  final _taskSource = HindranceTaskDataSource();
  final _submissionService = HindranceSubmissionService();
  final _taskApi = TaskApiService();
  final _mediaService = HindranceMediaService();
  final _descriptionController = TextEditingController();
  final _otnReasonController = TextEditingController();
  final _otnSubtype1Controller = TextEditingController();
  final _otnSubtype2Controller = TextEditingController();
  String? _hindranceType;
  String? _subHindranceType;
  final _ieNameController = TextEditingController();
  final _iePhoneController = TextEditingController();

  String? _ownerId;
  String? _error;
  bool _loading = true;
  bool _didAutoResumeDraft = false;
  bool _loadingServerHindrances = false;
  bool _serverHindranceLoadFailed = false;
  bool _serverHindrancesHaveMore = false;
  int _serverHindranceNextPage = 1;
  bool _syncingTasks = false;
  bool _savingTaskPack = false;
  bool _taskPackSaved = false;
  bool _taskListHasMore = false;
  bool _loadingHierarchy = false;
  String? _hierarchyLoadError;
  bool _loadingBoqApprovals = false;
  String? _boqApprovalLoadError;
  final Set<String> _approvedBoqBlockIds = {};
  final Set<String> _boqCheckedBlockIds = {};
  int _boqApprovalRequest = 0;
  int _boqApprovalChecked = 0;
  int _boqApprovalTotal = 0;
  bool _loadingMoreTasks = false;
  int _nextTaskPage = 1;
  bool _fromCache = false;
  bool _saving = false;
  String _queueState = 'LOCAL_SAVED';
  bool? _ieAffected;
  List<TaskModel> _tasks = [];
  List<TaskModel> _serverHindranceTasks = [];
  List<TaskModel> _cachedTasks = [];
  List<Map<String, dynamic>> _savedReports = [];
  Map<String, dynamic>? _draft;
  final List<Map<String, dynamic>> _media = [];
  final List<Map<String, dynamic>> _shpFiles = [];
  String? _blockId;
  String? _circle;
  String? _district;
  String? _ringId;
  String? _routeGroupKey;
  final Set<String> _segmentCodes = {};
  String _workflowStage = 'hindrance_form';
  bool? _ccnRequired;
  String? _ccnId;
  String? _serverTaskId;
  Timer? _syncRecoveryTimer;
  bool _checkingSyncRecovery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _descriptionController.addListener(_queueAutosave);
    _otnReasonController.addListener(_queueAutosave);
    _otnSubtype1Controller.addListener(_queueAutosave);
    _otnSubtype2Controller.addListener(_queueAutosave);
    _ieNameController.addListener(_queueAutosave);
    _iePhoneController.addListener(_queueAutosave);
    _load();
    _syncRecoveryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_retrySafelyResumableReports()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRecoveryTimer?.cancel();
    _descriptionController
      ..removeListener(_queueAutosave)
      ..dispose();
    _ieNameController
      ..removeListener(_queueAutosave)
      ..dispose();
    _iePhoneController
      ..removeListener(_queueAutosave)
      ..dispose();
    _otnReasonController.dispose();
    _otnSubtype1Controller.dispose();
    _otnSubtype2Controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_retrySafelyResumableReports());
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh) {
      ++_boqApprovalRequest;
      _boqCheckedBlockIds.clear();
      _approvedBoqBlockIds.clear();
    }
    final user = AuthStorageService().currentUser;
    if (user == null || user.id.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to load your assigned tasks and offline reports.';
      });
      return;
    }
    _ownerId = user.id;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final cachedReports = await _store.loadReports(user.id);
      PendingSyncManager.instance.restore(cachedReports);
      final taskData = await _taskSource.load(
        user.id,
        forceRefresh: forceRefresh,
      );
      unawaited(_restoreHindranceSyncRunners(cachedReports, taskData.tasks));
      if (!mounted) return;
      setState(() {
        _cachedTasks = taskData.fromCache ? taskData.tasks : const [];
        _tasks = taskData.tasks;
        _fromCache = taskData.fromCache && taskData.tasks.isNotEmpty;
        _taskPackSaved = _fromCache;
        _taskListHasMore = taskData.hasMore;
        _nextTaskPage = taskData.nextPage;
        _savedReports = cachedReports
            .where(
              (report) =>
                  report['recordType']?.toString().toUpperCase() == _recordType,
            )
            .toList();
        _loading = false;
      });
      _autoResumeSavedDraft();
      unawaited(_preloadBoqApprovals());
      unawaited(_loadServerHindranceTasks());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load local Hindrance data: $e';
      });
    }
  }

  void _autoResumeSavedDraft() {
    if (_didAutoResumeDraft) return;
    _didAutoResumeDraft = true;
    final saved = _savedReports.where((report) {
      final state = report['queueState']?.toString().toUpperCase();
      final reportId = report['reportId']?.toString() ?? '';
      return const {'LOCAL_SAVED', 'PARTIALLY_SAVED'}.contains(state) &&
          reportId.isNotEmpty &&
          !PendingSyncManager.instance.isActive(reportId);
    }).firstOrNull;
    if (saved != null) unawaited(_resumeDraft(saved));
  }

  Future<void> _loadServerHindranceTasks({
    int page = 0,
    bool append = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _loadingServerHindrances = true;
      _serverHindranceLoadFailed = false;
    });
    try {
      final response = await _taskApi.fetchTasks(
        page: page,
        size: 100,
        filters: TaskFilterModel(taskType: _recordType),
      );
      final hindrances = response.tasks
          .where((task) => task.taskType.toUpperCase().contains(_recordType))
          .toList();
      if (!mounted) return;
      setState(() {
        _serverHindranceTasks = append
            ? [..._serverHindranceTasks, ...hindrances]
            : hindrances;
        _loadingServerHindrances = false;
        _serverHindrancesHaveMore = response.hasNext;
        _serverHindranceNextPage = response.currentPage + 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingServerHindrances = false;
        _serverHindranceLoadFailed = true;
      });
      debugPrint(
        '[HindranceScreen] Could not load server Hindrance tasks: $error',
      );
    }
  }

  bool get _isSubmitted =>
      _queueState.toUpperCase() == 'SUBMITTED' ||
      _workflowStage.toLowerCase() == 'completed';

  List<TaskModel> get _visibleServerHindrances {
    final localTaskIds = _savedReports
        .map((report) => report['serverTaskId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return _serverHindranceTasks
        .where((task) => !localTaskIds.contains(task.id))
        .toList();
  }

  List<TaskModel> get _blocks => _tasks
      .where(HindranceTaskDataSource.isBlockTask)
      .where((task) => _displayName(task).isNotEmpty)
      .toList();

  List<String> get _circles =>
      (_blocks
          .map((block) => block.circle.trim())
          .where((value) => value.isNotEmpty && value != 'N/A')
          .toSet()
          .toList()
        ..sort());

  List<TaskModel> get _boqEligibleBlocks => _circle == null
      ? _blocks
      : _blocks
            .where((block) => _approvedBoqBlockIds.contains(block.id))
            .toList();

  List<String> get _districts =>
      (_blocks
          .where((block) => _circle == null || block.circle == _circle)
          .map((block) => block.district.trim())
          .where((value) => value.isNotEmpty && value != 'N/A')
          .toSet()
          .toList()
        ..sort());

  List<TaskModel> get _visibleBlocks => _boqEligibleBlocks
      .where((block) => _circle == null || block.circle == _circle)
      .where((block) => _district == null || block.district == _district)
      .toList();

  Future<void> _selectCircle(String? circle) async {
    ++_boqApprovalRequest;
    setState(() {
      _circle = circle;
      _district = null;
      _blockId = null;
      _ringId = null;
      _routeGroupKey = null;
      _segmentCodes.clear();
      _boqApprovalLoadError = null;
      _boqApprovalChecked = 0;
      _boqApprovalTotal = 0;
      _loadingBoqApprovals = false;
      _queueAutosave();
    });
  }

  Future<void> _preloadBoqApprovals() async {
    final request = ++_boqApprovalRequest;
    final candidates = _blocks
        .where((block) => !_boqCheckedBlockIds.contains(block.id))
        .toList();
    setState(() {
      _boqApprovalLoadError = null;
      _boqApprovalChecked = _boqCheckedBlockIds.length;
      _boqApprovalTotal = _blocks.length;
      _loadingBoqApprovals = candidates.isNotEmpty;
    });
    if (candidates.isEmpty) {
      if (mounted) setState(() => _loadingBoqApprovals = false);
      return;
    }
    var nextIndex = 0;
    var verificationFailed = false;
    Future<void> worker() async {
      while (true) {
        if (!mounted || request != _boqApprovalRequest) return;
        final index = nextIndex++;
        if (index >= candidates.length) return;
        final block = candidates[index];
        try {
          if (await _taskSource.hasUsableApprovedBoq(block)) {
            _approvedBoqBlockIds.add(block.id);
          }
          _boqCheckedBlockIds.add(block.id);
        } catch (error) {
          final hasCachedApprovedBoq =
              block.approvalStatus.toUpperCase() == 'APPROVED' &&
              block.routeSnapshot?.routes.isNotEmpty == true;
          if (hasCachedApprovedBoq) {
            _approvedBoqBlockIds.add(block.id);
            _boqCheckedBlockIds.add(block.id);
          } else {
            verificationFailed = true;
            debugPrint(
              '[HindranceScreen] Could not check BoQ approval for ${block.id}: $error',
            );
          }
        } finally {
          if (mounted && request == _boqApprovalRequest) {
            setState(() => _boqApprovalChecked++);
          }
        }
      }
    }

    await Future.wait(
      List.generate(candidates.length.clamp(1, 10).toInt(), (_) => worker()),
    );
    if (!mounted || request != _boqApprovalRequest) return;
    setState(() {
      _loadingBoqApprovals = false;
      _boqApprovalLoadError = verificationFailed
          ? 'Some Block approvals could not be checked. Only Blocks confirmed with one approved BoQ are shown.'
          : null;
    });
  }

  List<TaskModel> get _rings => HindranceTaskDataSource.ringsForBlock(
    _selectedBlock,
    _tasks,
  ).where((task) => _displayName(task).isNotEmpty).toList();

  List<TaskSegmentModel> get _ringSegments {
    final ring = _selectedRing;
    if (ring == null) return const [];
    return _segmentsFor(ring);
  }

  List<HindranceRouteGroup> get _routeGroups =>
      HindranceTaskDataSource.routeGroupsForSegments(_ringSegments);

  List<TaskSegmentModel> get _segments {
    final group = _routeGroups
        .where((candidate) => candidate.key == _routeGroupKey)
        .firstOrNull;
    if (_routeGroups.isNotEmpty) return group?.segments ?? const [];
    return _ringSegments;
  }

  List<TaskSegmentModel> _segmentsFor(TaskModel ring) {
    final explicitSegments =
        HindranceTaskDataSource.segmentsForRing(ring, _tasks)
            .map(
              (task) => TaskSegmentModel(
                // Embedded route segments use their segment code as a local
                // model ID. Do not send that synthetic value as a task ID.
                taskId: task.id == task.taskCode ? null : task.id,
                segmentCode: _taskSegmentLabel(task),
                startNode: _providedNode(task.routeSnapshot?.startNode?.name),
                targetNode: _providedNode(task.routeSnapshot?.targetNode?.name),
                distanceKm: task.routeSnapshot?.distanceKm ?? 0,
                startLat:
                    _firstSegment(task)?.startLat ??
                    task.routeSnapshot?.startNode?.latitude,
                startLng:
                    _firstSegment(task)?.startLng ??
                    task.routeSnapshot?.startNode?.longitude,
                targetLat:
                    _firstSegment(task)?.targetLat ??
                    task.routeSnapshot?.targetNode?.latitude,
                targetLng:
                    _firstSegment(task)?.targetLng ??
                    task.routeSnapshot?.targetNode?.longitude,
                groupStart: _firstSegment(task)?.groupStart,
                groupEnd: _firstSegment(task)?.groupEnd,
                groupStartId: _firstSegment(task)?.groupStartId,
                groupEndId: _firstSegment(task)?.groupEndId,
                sequenceNo: _firstSegment(task)?.sequenceNo,
              ),
            )
            .toList();
    if (explicitSegments.isNotEmpty) return explicitSegments;

    final embedded = ring.routeSnapshot?.segments.isNotEmpty == true
        ? ring.routeSnapshot!.segments
        : ring.segmentSnapshots;
    if (embedded.isNotEmpty) {
      return embedded
          .where(
            (segment) =>
                segment.segmentCode.trim().isNotEmpty &&
                segment.segmentCode != 'SEG-01',
          )
          .toList();
    }
    return const [];
  }

  String _segmentSelectionKey(TaskSegmentModel segment) =>
      segment.segmentCode.trim().isNotEmpty
      ? segment.segmentCode.trim()
      : segment.taskId?.trim() ?? '';

  bool _isSegmentSelected(TaskSegmentModel segment) =>
      _segmentCodes.contains(_segmentSelectionKey(segment)) ||
      _segmentCodes.contains(segment.segmentCode);

  Widget _buildHierarchySelector() {
    final blocks = _visibleBlocks;
    final rings = _rings;
    final segments = _segments;
    final selectedSegments = segments.where(_isSegmentSelected).toList();
    final totalDistance = selectedSegments.fold<double>(
      0,
      (sum, segment) => sum + segment.distanceKm,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('hindrance-circle-dropdown-$_circle'),
          initialValue: _circles.contains(_circle) ? _circle : null,
          decoration: const InputDecoration(labelText: 'Circle'),
          isExpanded: true,
          hint: Text(
            _loadingBoqApprovals
                ? 'Loading approved Blocks…'
                : 'Select a Circle',
          ),
          items: _circles
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: _loadingBoqApprovals ? null : _selectCircle,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('hindrance-district-dropdown-$_circle-$_district'),
          initialValue: _districts.contains(_district) ? _district : null,
          decoration: const InputDecoration(labelText: 'District'),
          isExpanded: true,
          hint: Text(
            _circle == null
                ? 'Select a Circle first'
                : _districts.isEmpty
                ? 'No Districts available'
                : 'Select a District',
          ),
          items: _districts
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: _circle == null
              ? null
              : (value) => setState(() {
                  _district = value;
                  _blockId = null;
                  _ringId = null;
                  _routeGroupKey = null;
                  _segmentCodes.clear();
                  _queueAutosave();
                }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('hindrance-block-dropdown-$_blockId'),
          initialValue: blocks.any((block) => block.id == _blockId)
              ? _blockId
              : null,
          decoration: const InputDecoration(labelText: 'Block'),
          isExpanded: true,
          hint: Text(
            _loadingBoqApprovals
                ? 'Checking approved BoQs…'
                : _circle == null
                ? 'Select a Circle first'
                : _district == null
                ? 'Select a District first'
                : blocks.isEmpty
                ? 'No approved BoQ Blocks'
                : 'Select a Block',
          ),
          items: blocks
              .map(
                (block) => DropdownMenuItem(
                  value: block.id,
                  child: Text(
                    _displayName(block),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged:
              _loadingBoqApprovals || _circle == null || _district == null
              ? null
              : (id) {
                  final block = blocks
                      .where((item) => item.id == id)
                      .firstOrNull;
                  if (block != null) unawaited(_selectBlock(block));
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('hindrance-ring-dropdown-$_blockId-$_ringId'),
          initialValue: rings.any((ring) => ring.id == _ringId)
              ? _ringId
              : null,
          decoration: const InputDecoration(labelText: 'Ring'),
          hint: Text(
            _blockId == null ? 'Select a Block first' : 'Select a Ring',
          ),
          isExpanded: true,
          items: rings
              .map(
                (ring) => DropdownMenuItem(
                  value: ring.id,
                  child: Text(
                    _displayName(ring),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _selectedBlock == null || _loadingHierarchy
              ? null
              : (id) => setState(() {
                  _ringId = id;
                  _routeGroupKey = null;
                  _segmentCodes.clear();
                  _queueAutosave();
                }),
        ),
        if (_routeGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('hindrance-route-group-$_ringId-$_routeGroupKey'),
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
                      '${group.label} · ${group.segments.length} segments · ${group.segments.fold<double>(0, (sum, segment) => sum + segment.distanceKm).toStringAsFixed(2)} km',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (key) => setState(() {
              _routeGroupKey = key;
              _segmentCodes.clear();
              _queueAutosave();
            }),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Segments (${selectedSegments.length} selected${_routeGroupKey == null ? '' : ' of ${segments.length}'})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (segments.isNotEmpty)
              TextButton(
                onPressed: () => setState(() {
                  if (segments.every(_isSegmentSelected)) {
                    _segmentCodes.clear();
                  } else {
                    _segmentCodes.addAll(segments.map(_segmentSelectionKey));
                  }
                  _queueAutosave();
                }),
                child: Text(
                  segments.every(_isSegmentSelected)
                      ? 'Clear all'
                      : 'Select all',
                ),
              ),
          ],
        ),
        SizedBox(
          height: 240,
          child: segments.isEmpty
              ? Center(
                  child: Text(
                    _selectedRing == null
                        ? 'Select a Block and Ring to view routes.'
                        : _routeGroups.isNotEmpty && _routeGroupKey == null
                        ? 'Select a GP route to view its segments.'
                        : 'No segments are available for this route.',
                    textAlign: TextAlign.center,
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Scrollbar(
                    child: ListView.separated(
                      itemCount: segments.length + 2,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildPickerBlockDetails();
                        if (index == 1) return _buildPickerRingDetails();
                        final segment = segments[index - 2];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          value: _isSegmentSelected(segment),
                          title: Text(
                            '${segment.startNode} - ${segment.targetNode}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF17243A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _pickerNodePath(
                                  segment.startNode,
                                  segment.targetNode,
                                ),
                                _pickerMetric(
                                  Icons.swap_horiz_rounded,
                                  '${segment.distanceKm.toStringAsFixed(2)} km',
                                ),
                              ],
                            ),
                          ),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _segmentCodes.add(_segmentSelectionKey(segment));
                            } else {
                              _segmentCodes.remove(
                                _segmentSelectionKey(segment),
                              );
                            }
                            _queueAutosave();
                          }),
                        );
                      },
                    ),
                  ),
                ),
        ),
        if (selectedSegments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Selected Segment Details (${selectedSegments.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildSegmentTable(selectedSegments, totalDistance),
        ],
      ],
    );
  }

  Widget _buildPickerBlockDetails() {
    final block = _selectedBlock;
    if (block == null) return const SizedBox.shrink();
    final location = block.locationSnapshot;
    final locationLabel = [location?.state, location?.district]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'n/a')
        .join(' › ');
    final distance =
        block.calculatedTotalLength ??
        _rings.fold<double>(
          0,
          (sum, ring) => sum + (ring.routeSnapshot?.distanceKm ?? 0),
        );
    return _pickerHierarchyRow(
      title: _displayName(block),
      level: 'BLOCK',
      levelColor: const Color(0xFF2563EB),
      subtitle: locationLabel,
      markerColor: const Color(0xFF3B82F6),
      metrics: [
        _pickerMetric(Icons.account_tree_outlined, '${_rings.length} rings'),
        _pickerMetric(
          Icons.swap_horiz_rounded,
          '${distance.toStringAsFixed(2)} km',
        ),
      ],
    );
  }

  Widget _buildPickerRingDetails() {
    final ring = _selectedRing;
    if (ring == null) return const SizedBox.shrink();
    final segments = _segmentsFor(ring);
    final nodeCount = segments
        .expand((segment) => [segment.startNode, segment.targetNode])
        .map((node) => node.trim())
        .where((node) => node.isNotEmpty)
        .toSet()
        .length;
    final distance = (ring.routeSnapshot?.distanceKm ?? 0) > 0
        ? ring.routeSnapshot!.distanceKm
        : segments.fold<double>(0, (sum, item) => sum + item.distanceKm);
    return _pickerHierarchyRow(
      title: _displayName(ring),
      level: 'RING',
      levelColor: const Color(0xFF16A34A),
      markerColor: const Color(0xFF3B82F6),
      metrics: [
        _pickerMetric(Icons.hub_outlined, '$nodeCount nodes'),
        _pickerMetric(
          Icons.swap_horiz_rounded,
          '${distance.toStringAsFixed(2)} km',
        ),
      ],
    );
  }

  Widget _pickerHierarchyRow({
    required String title,
    required String level,
    required Color levelColor,
    required Color markerColor,
    required List<Widget> metrics,
    String? subtitle,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17243A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    level,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8290A5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Wrap(spacing: 6, runSpacing: 4, children: metrics),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 11, color: markerColor),
        ),
      ],
    ),
  );

  Widget _pickerMetric(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _pickerNodePath(String start, String end) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 260.0;
      // Keep the node chips within the width left after the outer padding,
      // border, arrow and spacing. A fixed minimum here made the path wider
      // than its ListTile subtitle on narrow screens.
      final nodeWidth = ((maxWidth - 40) / 2).clamp(0.0, 130.0);
      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE3EC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pickerNode(start, maxWidth: nodeWidth),
            const SizedBox(width: 5),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            _pickerNode(end, maxWidth: nodeWidth),
          ],
        ),
      );
    },
  );

  Widget _pickerNode(String value, {double maxWidth = 130}) => Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EEF5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      value.isEmpty ? '—' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
    ),
  );

  Widget _buildSegmentTable(
    List<TaskSegmentModel> segments, [
    double? suppliedTotal,
  ]) {
    final totalDistance =
        suppliedTotal ??
        segments.fold<double>(0, (sum, segment) => sum + segment.distanceKm);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 12,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          dividerThickness: 0.5,
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
          headingTextStyle: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
          dataTextStyle: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF1E293B),
          ),
          columns: const [
            DataColumn(label: Text('Start GP')),
            DataColumn(label: Text('End GP')),
            DataColumn(label: Text('Start Lat/Long')),
            DataColumn(label: Text('End Lat/Long')),
            DataColumn(label: Text('Segment Distance')),
          ],
          rows: [
            for (final segment in segments)
              DataRow(
                cells: [
                  DataCell(
                    Text(segment.startNode.isEmpty ? '—' : segment.startNode),
                  ),
                  DataCell(
                    Text(segment.targetNode.isEmpty ? '—' : segment.targetNode),
                  ),
                  DataCell(
                    Text(
                      _formatCoordinates(segment.startLat, segment.startLng),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatCoordinates(segment.targetLat, segment.targetLng),
                    ),
                  ),
                  DataCell(Text('${segment.distanceKm.toStringAsFixed(2)} km')),
                ],
              ),
            DataRow(
              color: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  Text(
                    'Total: ${totalDistance.toStringAsFixed(2)} km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return '—';
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String _taskSegmentLabel(TaskModel task) {
    final routeCode = task.routeSnapshot?.routeCode.trim() ?? '';
    if (routeCode.isNotEmpty && routeCode != 'N/A') return routeCode;
    if (task.taskCode.isNotEmpty && task.taskCode != 'TASK-2026-00000') {
      return task.taskCode;
    }
    final name = task.displayName.trim();
    if (name.isNotEmpty && name != 'Unnamed Task') return name;
    return task.id;
  }

  TaskModel? get _selectedRing {
    for (final task in _rings) {
      if (task.id == _ringId) return task;
    }
    return null;
  }

  String _displayName(TaskModel task) {
    final name = task.displayName.trim();
    if (name.isNotEmpty &&
        name.toLowerCase() != 'n/a' &&
        name != 'Unnamed Task') {
      return name;
    }
    final code = task.taskCode.trim();
    if (code.isNotEmpty &&
        code.toLowerCase() != 'n/a' &&
        code != 'TASK-2026-00000') {
      return code;
    }
    return task.id.trim();
  }

  TaskSegmentModel? _firstSegment(TaskModel task) {
    final segments = task.routeSnapshot?.segments ?? const <TaskSegmentModel>[];
    return segments.isEmpty ? null : segments.first;
  }

  String _providedNode(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    const placeholders = {'Node', 'Start Node', 'Target Node'};
    if (placeholders.contains(value.trim())) return '';
    return value.trim();
  }

  void _queueAutosave() {
    if (_draft == null || _ownerId == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 350),
      () => _persistDraft(),
    );
  }

  Timer? _saveTimer;

  Map<String, dynamic> _payload() => {
    'reportId': _draft?['reportId'],
    'recordType': _recordType,
    'hindranceId': _draft?['hindranceId'],
    'workflowStage': _workflowStage,
    'ccnRequired': _ccnRequired,
    'ccnId': _ccnId,
    'serverTaskId': _serverTaskId,
    'taskId': _selectedBlock?.id,
    'taskCode': _selectedBlock?.taskCode,
    'taskName': _selectedBlock == null ? null : _displayName(_selectedBlock!),
    'blockId': _blockId,
    'blockName': _selectedBlock == null ? null : _displayName(_selectedBlock!),
    'ringId': _ringId,
    'ringName': _selectedRing == null ? null : _displayName(_selectedRing!),
    'routeGroupKey': _routeGroupKey,
    'routeGroupName': _routeGroups
        .where((group) => group.key == _routeGroupKey)
        .firstOrNull
        ?.label,
    'affectedSegments': _segments
        .where(_isSegmentSelected)
        .map(
          (segment) => {
            if (segment.taskId != null) 'taskId': segment.taskId,
            'code': segment.segmentCode,
            'startNode': _providedNode(segment.startNode),
            'endNode': _providedNode(segment.targetNode),
            'startLatitude': segment.startLat,
            'startLongitude': segment.startLng,
            'endLatitude': segment.targetLat,
            'endLongitude': segment.targetLng,
            'distanceKm': segment.distanceKm,
          },
        )
        .toList(),
    'hindranceType': _hindranceType,
    'subHindranceType': _subHindranceType,
    'description': _descriptionController.text,
    'otnReason': _otnReasonController.text,
    'otnSubtype1': _otnSubtype1Controller.text,
    'otnSubtype2': _otnSubtype2Controller.text,
    'ieAffected': _ieAffected,
    'ieName': _ieNameController.text,
    'iePhone': _iePhoneController.text,
    'media': List<Map<String, dynamic>>.from(_media),
    'shpFiles': List<Map<String, dynamic>>.from(_shpFiles),
    'queueState': 'LOCAL_SAVED',
    'createdAt': _draft?['createdAt'],
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  String? _dropdownValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  List<DropdownMenuItem<String>> _classificationItems(
    List<String> options,
    String? currentValue,
  ) {
    final values = [...options];
    final legacyValue = currentValue?.trim();
    // Preserve draft values created by older app builds so a user can inspect
    // and correct them instead of silently losing data on resume.
    if (legacyValue != null &&
        legacyValue.isNotEmpty &&
        !values.contains(legacyValue)) {
      values.add(legacyValue);
    }
    return values
        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
        .toList();
  }

  TaskModel? get _selectedBlock {
    for (final task in _blocks) {
      if (task.id == _blockId) return task;
    }
    return null;
  }

  Future<void> _selectBlock(TaskModel? value) async {
    final hasCachedRoutes = value?.routeSnapshot?.routes.isNotEmpty == true;
    setState(() {
      _circle = value?.circle;
      _district = value?.district;
      _blockId = value?.id;
      _ringId = null;
      _routeGroupKey = null;
      _segmentCodes.clear();
      _taskPackSaved = hasCachedRoutes;
      _hierarchyLoadError = null;
      // A cached approved BoQ is immediately usable offline; keep the Ring
      // picker enabled while attempting a background refresh.
      _loadingHierarchy = value != null && !hasCachedRoutes;
      _queueAutosave();
    });
    final ownerId = _ownerId;
    if (ownerId == null || value == null) return;
    await _loadHierarchyForBlock(value);
  }

  Future<void> _loadHierarchyForBlock(TaskModel value) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final hasCachedRoutes = value.routeSnapshot?.routes.isNotEmpty == true;
    if (mounted) {
      setState(() {
        _loadingHierarchy = !hasCachedRoutes;
      });
    }
    try {
      // Refresh from the approved Dev BoQ when possible. Existing route data
      // remains selectable while the request is in flight or unavailable.
      final hierarchy = await _taskSource.loadBlockHierarchy(value);
      if (!mounted || _blockId != value.id) return;
      final availableRingIds = HindranceTaskDataSource.ringsForBlock(
        hierarchy,
        [hierarchy],
      ).map((ring) => ring.id).toSet();
      setState(() {
        _tasks = _tasks
            .map((task) => task.id == value.id ? hierarchy : task)
            .toList();
        if (_ringId != null && !availableRingIds.contains(_ringId)) {
          _ringId = null;
          _routeGroupKey = null;
          _segmentCodes.clear();
        }
        _loadingHierarchy = false;
        _hierarchyLoadError = null;
      });
      await _persistSelectedTaskPack(value.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHierarchy = false;
        _hierarchyLoadError = hasCachedRoutes
            ? null
            : _hierarchyErrorMessage(error);
      });
    }
  }

  Future<void> _persistSelectedTaskPack(String blockId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    setState(() => _savingTaskPack = true);
    try {
      await _taskSource.cacheBlockHierarchy(
        ownerId: ownerId,
        blockId: blockId,
        tasks: _tasks,
      );
      if (mounted && _blockId == blockId) {
        setState(() {
          _taskPackSaved = true;
          _savingTaskPack = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingTaskPack = false);
      _showMessage(
        'Could not save this task hierarchy for offline use: $error',
      );
    }
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
      if (!page.hasMore && _blockId != null) {
        await _persistSelectedTaskPack(_blockId!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreTasks = false);
      _showMessage('Could not load the next task page: $error');
    }
  }

  Future<void> _startNewDraft() async {
    if (_ownerId == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      final reportId = _uuid.v4();
      _draft = {
        'reportId': reportId,
        'hindranceId': '${_isOtn ? 'OTN' : 'HIN'}-${reportId.toUpperCase()}',
        'createdAt': now,
      };
      _workflowStage = 'hierarchy_selection';
      _ccnRequired = null;
      _ccnId = null;
      _serverTaskId = null;
      _queueState = 'LOCAL_SAVED';
      _circle = null;
      _district = null;
      _blockId = null;
      _ringId = null;
      _routeGroupKey = null;
      _segmentCodes.clear();
      _media.clear();
      _shpFiles.clear();
      _descriptionController.clear();
      _hindranceType = null;
      _subHindranceType = null;
      _ieNameController.clear();
      _iePhoneController.clear();
      _ieAffected = null;
    });
    await _persistDraft();
  }

  Future<void> _resumeDraft(Map<String, dynamic> saved) async {
    final savedReportId = saved['reportId']?.toString() ?? '';
    if (saved['recordType']?.toString().toUpperCase() != _recordType) return;
    if (PendingSyncManager.instance.isActive(savedReportId)) {
      _showMessage(
        'This Hindrance is syncing. Check Pending sync for progress.',
      );
      return;
    }
    setState(() {
      final reportId = savedReportId;
      _draft = {
        'reportId': reportId,
        'hindranceId':
            saved['hindranceId'] ??
            '${_isOtn ? 'OTN' : 'HIN'}-${reportId.toUpperCase()}',
        'createdAt': saved['createdAt'],
      };
      _workflowStage =
          saved['workflowStage']?.toString() ??
          (saved['serverTaskId'] == null
              ? 'hierarchy_selection'
              : 'hindrance_form');
      _ccnRequired = saved['ccnRequired'] as bool?;
      _ccnId = saved['ccnId']?.toString();
      _serverTaskId = saved['serverTaskId']?.toString();
      _queueState = saved['queueState']?.toString() ?? 'LOCAL_SAVED';
      _blockId = saved['blockId']?.toString();
      _ringId = saved['ringId']?.toString();
      _routeGroupKey = saved['routeGroupKey']?.toString();
      _segmentCodes
        ..clear()
        ..addAll(
          (saved['affectedSegments'] as List? ?? const [])
              .whereType<Map>()
              .map((segment) => segment['code']?.toString() ?? '')
              .where((code) => code.isNotEmpty),
        );
      _media
        ..clear()
        ..addAll(
          (saved['media'] as List? ?? const []).whereType<Map>().map(
            Map<String, dynamic>.from,
          ),
        );
      _shpFiles
        ..clear()
        ..addAll(
          (saved['shpFiles'] as List? ?? const []).whereType<Map>().map(
            Map<String, dynamic>.from,
          ),
        );
      _descriptionController.text = saved['description']?.toString() ?? '';
      _otnReasonController.text = saved['otnReason']?.toString() ?? '';
      _otnSubtype1Controller.text = saved['otnSubtype1']?.toString() ?? '';
      _otnSubtype2Controller.text = saved['otnSubtype2']?.toString() ?? '';
      _hindranceType = saved['hindranceType']?.toString();
      _subHindranceType = saved['subHindranceType']?.toString();
      _ieNameController.text = saved['ieName']?.toString() ?? '';
      _iePhoneController.text = saved['iePhone']?.toString() ?? '';
      _ieAffected = saved['ieAffected'] as bool?;
    });
    await _persistDraft();
    final blockId = _blockId;
    if (blockId == null) return;
    final block = _blocks.where((item) => item.id == blockId).firstOrNull;
    if (block != null) {
      await _loadHierarchyForBlock(block);
    } else {
      _showMessage(
        'The saved Block is not in the current Dev master data. Refresh the Block list and select it again.',
      );
    }
  }

  Future<bool> _persistDraft({String? state}) async {
    if (_draft == null || _ownerId == null) return false;
    if (state != null) _queueState = state;
    final payload = _payload();
    payload['queueState'] = _queueState;
    try {
      final reportId = _draft!['reportId'] as String;
      await _store.saveReport(
        reportId: reportId,
        ownerId: _ownerId!,
        state: _queueState,
        payload: payload,
        createdAt:
            DateTime.tryParse(_draft!['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
      if (mounted) {
        final existingIndex = _savedReports.indexWhere(
          (r) => r['reportId'] == reportId,
        );
        final reportRecord = {
          ...payload,
          'reportId': reportId,
          'queueState': _queueState,
          'createdAt': _draft!['createdAt'],
        };
        setState(() {
          if (existingIndex != -1) {
            _savedReports[existingIndex] = reportRecord;
          } else {
            _savedReports.insert(0, reportRecord);
          }
        });
      }
      return true;
    } catch (e) {
      _showMessage('Could not save this report locally: $e');
      return false;
    }
  }

  Future<void> _queueReport() async {
    await _submitHindrance();
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

  Future<void> _storeBackgroundReport({
    required String ownerId,
    required String reportId,
    required DateTime createdAt,
    required Map<String, dynamic> payload,
    required String state,
  }) async {
    payload['queueState'] = state;
    payload['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _store.saveReport(
      reportId: reportId,
      ownerId: ownerId,
      state: state,
      payload: payload,
      createdAt: createdAt,
    );
    if (!mounted) return;
    final record = {
      ...payload,
      'reportId': reportId,
      'createdAt': createdAt.toIso8601String(),
    };
    setState(() {
      final index = _savedReports.indexWhere(
        (item) => item['reportId'] == reportId,
      );
      if (index < 0) {
        _savedReports.insert(0, record);
      } else {
        _savedReports[index] = record;
      }
    });
  }

  Future<void> _restoreHindranceSyncRunners(
    List<Map<String, dynamic>> reports,
    List<TaskModel> tasks,
  ) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    for (final saved in reports) {
      if (saved['recordType']?.toString().toUpperCase() != _recordType) {
        continue;
      }
      final state = saved['queueState']?.toString().toUpperCase();
      if (!const {'PENDING_SYNC', 'SYNCING', 'SYNC_FAILED'}.contains(state)) {
        continue;
      }
      final reportId = saved['reportId']?.toString() ?? '';
      final block = tasks
          .where((task) => task.id == saved['blockId'])
          .firstOrNull;
      final ring = HindranceTaskDataSource.ringsForBlock(
        block,
        tasks,
      ).where((task) => task.id == saved['ringId']).firstOrNull;
      if (reportId.isEmpty || block == null || ring == null) {
        continue;
      }
      final selectedCodes = (saved['affectedSegments'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item['code']?.toString() ?? '')
          .where((code) => code.isNotEmpty)
          .toSet();
      final segments = HindranceTaskDataSource.segmentsForRing(ring, tasks)
          .map((task) => task.routeSnapshot?.segments.firstOrNull)
          .whereType<TaskSegmentModel>()
          .where((segment) => selectedCodes.contains(segment.segmentCode))
          .toList();
      if (segments.length != selectedCodes.length || segments.isEmpty) {
        continue;
      }
      final report = Map<String, dynamic>.from(saved)
        ..['media'] = (saved['media'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
        ..['shpFiles'] = (saved['shpFiles'] as List? ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      final createdAt =
          DateTime.tryParse(saved['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc();
      final totalBytes =
          [
            ...report['media'] as List,
            ...report['shpFiles'] as List,
          ].whereType<Map>().fold<int>(
            0,
            (sum, item) =>
                sum + (int.tryParse(item['sizeBytes']?.toString() ?? '') ?? 0),
          );
      Future<void> runReport(Future<void> Function(int) onBytesSent) =>
          (_isOtn ? _runOtnSync : _runHindranceSync)(
            reportId: reportId,
            ownerId: ownerId,
            createdAt: createdAt,
            report: report,
            block: block,
            ring: ring,
            segments: segments,
            totalBytes: totalBytes,
            onBytesSent: onBytesSent,
          );
      PendingSyncManager.instance.registerRunner(reportId, runReport);
      // Only replay phases that cannot have reached the final submit endpoint.
      // A restored SUBMITTING job stays available for an explicit user retry,
      // avoiding accidental duplicate task submissions.
      var syncPhase = saved['syncPhase']?.toString().toUpperCase();
      final hasTaskId = saved['serverTaskId']?.toString().isNotEmpty == true;
      final priorUploadKeys =
          [...report['media'] as List, ...report['shpFiles'] as List]
              .whereType<Map>()
              .where((item) => item['uploadKey']?.toString().isNotEmpty == true)
              .length;
      final priorBytes =
          int.tryParse(saved['syncBytesSent']?.toString() ?? '') ?? 0;
      // Legacy queue rows did not save a phase. If the task ID exists and no
      // upload key/byte checkpoint exists, the media-first flow proves the
      // final submit was not reached, so the saved upload can resume once.
      if (syncPhase == null &&
          hasTaskId &&
          priorUploadKeys == 0 &&
          priorBytes == 0) {
        report['syncPhase'] = 'UPLOADING';
        await _storeBackgroundReport(
          ownerId: ownerId,
          reportId: reportId,
          createdAt: createdAt,
          payload: report,
          state: state!,
        );
        syncPhase = 'UPLOADING';
      }
      final safeToResume = const {
        'QUEUED',
        'UPLOADING',
        'SAVING',
      }.contains(syncPhase);
      final failure = saved['syncError']?.toString().toLowerCase() ?? '';
      final retryableFailure =
          failure.isEmpty ||
          failure.contains('socketexception') ||
          failure.contains('failed host lookup') ||
          failure.contains('network is unreachable') ||
          failure.contains('connection timed out') ||
          failure.contains('handshakeexception');
      if (safeToResume &&
          retryableFailure &&
          (state == 'PENDING_SYNC' ||
              state == 'SYNCING' ||
              state == 'SYNC_FAILED')) {
        PendingSyncManager.instance.start(
          id: reportId,
          formType: _workflowLabel,
          totalBytes: totalBytes,
          files: [
            ...report['media'] as List,
            ...report['shpFiles'] as List,
          ].whereType<Map>().map(PendingSyncManager.fileLabel).toList(),
          run: runReport,
        );
      }
    }
  }

  Future<void> _retrySafelyResumableReports() async {
    if (_checkingSyncRecovery || _ownerId == null) return;
    _checkingSyncRecovery = true;
    try {
      final host = Uri.parse(AppConstants.ilyncApiBaseUrl).host;
      final socket = await Socket.connect(
        host,
        443,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      final ownerId = _ownerId!;
      final reports = await _store.loadReports(ownerId);
      final safePending = reports.any((report) {
        final state = report['queueState']?.toString().toUpperCase();
        final phase = report['syncPhase']?.toString().toUpperCase();
        return report['recordType']?.toString().toUpperCase() == _recordType &&
            const {'PENDING_SYNC', 'SYNCING', 'SYNC_FAILED'}.contains(state) &&
            const {'QUEUED', 'UPLOADING', 'SAVING'}.contains(phase);
      });
      if (!safePending) return;
      final cached = await _taskSource.loadCached(ownerId);
      PendingSyncManager.instance.restore(reports);
      await _restoreHindranceSyncRunners(reports, cached.tasks);
    } catch (_) {
      // A connectivity probe is advisory. Keep local reports queued and retry
      // on the next resume or periodic check without surfacing noisy errors.
    } finally {
      _checkingSyncRecovery = false;
    }
  }

  Future<void> _runHindranceSync({
    required String reportId,
    required String ownerId,
    required DateTime createdAt,
    required Map<String, dynamic> report,
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    required int totalBytes,
    required Future<void> Function(int) onBytesSent,
  }) async {
    var sentBytes = [...report['media'] as List, ...report['shpFiles'] as List]
        .whereType<Map>()
        .where((item) => item['uploadKey'] != null)
        .fold<int>(
          0,
          (sum, item) =>
              sum + (int.tryParse(item['sizeBytes']?.toString() ?? '') ?? 0),
        );
    var lastPersistedBytes = sentBytes;
    report['syncBytesTotal'] = totalBytes;
    report['syncBytesSent'] = sentBytes;
    Future<void> checkpoint(String state) => _storeBackgroundReport(
      ownerId: ownerId,
      reportId: reportId,
      createdAt: createdAt,
      payload: report,
      state: state,
    );
    try {
      if (report['serverTaskId'] == null ||
          report['serverTaskId'].toString().isEmpty) {
        report['syncPhase'] = 'CREATING_TASK';
        await checkpoint('SYNCING');
      } else {
        report['syncPhase'] = 'UPLOADING';
        await checkpoint('SYNCING');
      }
      if (sentBytes > 0) {
        await onBytesSent(sentBytes);
        await checkpoint('SYNCING');
      }
      final submittedTaskId = await _submissionService.submit(
        block: block,
        ring: ring,
        segments: segments,
        report: report,
        existingTaskId: report['serverTaskId']?.toString(),
        onTaskCreated: (createdTaskId) async {
          report
            ..['serverTaskId'] = createdTaskId
            ..['syncPhase'] = 'UPLOADING';
          await checkpoint('SYNCING');
        },
        onBeforeSave: () async {
          report['syncPhase'] = 'SAVING';
          await checkpoint('SYNCING');
        },
        onBeforeSubmit: () async {
          report['syncPhase'] = 'SUBMITTING';
          await checkpoint('SYNCING');
        },
        onUploadProgress: () => checkpoint('SYNCING'),
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
      report
        ..['serverTaskId'] = submittedTaskId
        ..['syncBytesSent'] = totalBytes
        ..['syncError'] = null
        ..['syncPhase'] = 'COMPLETE'
        ..['workflowStage'] = 'ccn_question';
      await checkpoint('SUBMITTED');
      if (mounted && _draft == null) {
        setState(() {
          _serverTaskId = submittedTaskId;
          _workflowStage = 'ccn_question';
          _queueState = 'SUBMITTED';
          _draft = {
            'reportId': reportId,
            'createdAt': createdAt.toIso8601String(),
          };
        });
      }
    } catch (error) {
      report['syncError'] = _errorMessage(error);
      report['syncBytesSent'] = sentBytes;
      await checkpoint('SYNC_FAILED');
      rethrow;
    }
  }

  Future<void> _runOtnSync({
    required String reportId,
    required String ownerId,
    required DateTime createdAt,
    required Map<String, dynamic> report,
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    required int totalBytes,
    required Future<void> Function(int) onBytesSent,
  }) async {
    var sentBytes = [...report['media'] as List, ...report['shpFiles'] as List]
        .whereType<Map>()
        .where((item) => item['uploadKey'] != null)
        .fold<int>(
          0,
          (sum, item) =>
              sum + (int.tryParse(item['sizeBytes']?.toString() ?? '') ?? 0),
        );
    var lastPersistedBytes = sentBytes;
    report['syncBytesTotal'] = totalBytes;
    report['syncBytesSent'] = sentBytes;
    Future<void> checkpoint(String state) => _storeBackgroundReport(
      ownerId: ownerId,
      reportId: reportId,
      createdAt: createdAt,
      payload: report,
      state: state,
    );
    try {
      report['syncPhase'] = report['serverTaskId'] == null
          ? 'CREATING_TASK'
          : 'UPLOADING';
      await checkpoint('SYNCING');
      if (sentBytes > 0) await onBytesSent(sentBytes);
      final submittedId = await _submissionService.submitOtn(
        block: block,
        ring: ring,
        segments: segments,
        report: report,
        existingTaskId: report['serverTaskId']?.toString(),
        onTaskCreated: (id) async {
          report
            ..['serverTaskId'] = id
            ..['syncPhase'] = 'UPLOADING';
          await checkpoint('SYNCING');
        },
        onBeforeSave: () async {
          report['syncPhase'] = 'SAVING';
          await checkpoint('SYNCING');
        },
        onBeforeSubmit: () async {
          report['syncPhase'] = 'SUBMITTING';
          await checkpoint('SYNCING');
        },
        onUploadProgress: () => checkpoint('SYNCING'),
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
      report
        ..['serverTaskId'] = submittedId
        ..['syncBytesSent'] = totalBytes
        ..['syncError'] = null
        ..['syncPhase'] = 'COMPLETE'
        ..['workflowStage'] = 'completed';
      await checkpoint('SUBMITTED');
      if (mounted && _draft == null) {
        setState(() {
          _serverTaskId = submittedId;
          _workflowStage = 'completed';
          _queueState = 'SUBMITTED';
          _draft = {
            'reportId': reportId,
            'createdAt': createdAt.toIso8601String(),
          };
        });
      }
    } catch (error) {
      report['syncError'] = _errorMessage(error);
      report['syncBytesSent'] = sentBytes;
      await checkpoint('SYNC_FAILED');
      rethrow;
    }
  }

  Future<void> _createTaskAndContinue() async {
    final block = _selectedBlock;
    final ring = _selectedRing;
    if (block == null || ring == null) {
      _showMessage('Select a Block and Ring first.');
      return;
    }
    if (block.routeSnapshot?.routes.isNotEmpty != true) {
      _showMessage(
        'The selected Block has no saved route data. Refresh its approved Dev BoQ before continuing.',
      );
      return;
    }
    final selectedSegments = _segments.where(_isSegmentSelected).toList();
    if (selectedSegments.isEmpty) {
      _showMessage('Select at least one segment before continuing.');
      return;
    }
    final draftSaved = await _persistDraft(state: 'PARTIALLY_SAVED');
    if (!draftSaved || !mounted) return;
    setState(() => _saving = true);
    try {
      final taskId = await _submissionService.createTask(
        block: block,
        ring: ring,
        segments: selectedSegments,
        taskType: _recordType,
        taskName: '$_recordType at ${ring.displayName}',
      );
      if (!mounted) return;
      _serverTaskId = taskId;
      setState(() => _workflowStage = 'hindrance_form');
      final saved = await _persistDraft(state: 'PARTIALLY_SAVED');
      if (!saved || !mounted) return;
      setState(() => _draft = null);
      _showMessage(
        'Task ID received: $taskId. Partially saved $_workflowLabel is on the list; tap it to complete the form.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _workflowStage = 'hindrance_form');
        final saved = await _persistDraft(state: 'PARTIALLY_SAVED');
        if (!saved || !mounted) return;
        setState(() => _draft = null);
        _showMessage(
          'Partially saved on this device. Tap the report on the Hindrance list to reopen the form and retry when connected. ${_errorMessage(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continueToCcn() async {
    final persisted = await _persistDraft(state: 'AWAITING_CCN');
    if (!persisted || !mounted) return;
    final linkedReport = _payload();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CcnWorkflowScreen(hindrance: linkedReport),
      ),
    );
    if (result == null || !mounted) return;
    if (result['queued'] == true) {
      setState(() => _draft = null);
      _showMessage('CCN saved. Upload is continuing in Pending sync.');
      return;
    }
    setState(() {
      _ccnId = result['ccnId']?.toString();
      _workflowStage = 'completed';
    });
    final saved = await _persistDraft(state: 'SUBMITTED');
    if (!saved || !mounted) return;
    setState(() => _draft = null);
    _showMessage(
      'Hindrance and CCN are submitted. Hindrance ID: ${_serverTaskId ?? 'saved'}; CCN ID: ${_ccnId ?? 'saved'}.',
    );
  }

  Future<void> _finishWithoutCcn() async {
    if (_serverTaskId == null || _serverTaskId!.isEmpty) {
      _showMessage(
        'The Hindrance has not been submitted yet. Submit it first.',
      );
      return;
    }
    setState(() => _workflowStage = 'completed');
    final saved = await _persistDraft(state: 'SUBMITTED');
    if (!saved || !mounted) return;
    setState(() => _draft = null);
    _showMessage('Hindrance saved and done. ID: $_serverTaskId');
  }

  Future<void> _submitHindrance() async {
    if (_isSubmitted) return;
    if (_isOtn) {
      final slots = _media.map((item) => item['slot']?.toString()).toSet();
      if (!slots.contains('start_point') || !slots.contains('end_point')) {
        _showMessage(
          'Capture both the OTN start and end point photos before submitting.',
        );
        return;
      }
      if (!slots.contains('walkthrough')) {
        _showMessage(
          'Capture the OTN route walkthrough video before submitting.',
        );
        return;
      }
      if (_descriptionController.text.trim().isEmpty) {
        _showMessage('Enter the OTN details before submitting.');
        return;
      }
    }
    final block = _selectedBlock;
    final ring = _selectedRing;
    final report = _payload();
    if (block == null || ring == null) {
      _showMessage('Select a Block and Ring before submitting.');
      return;
    }
    if (_ieAffected == true &&
        !_media.any((item) => item['slot'] == 'ie_photo')) {
      _showMessage('Capture the IE photo or mark IE as not affected.');
      return;
    }
    final ownerId = _ownerId;
    final draft = _draft;
    if (ownerId == null || draft == null) return;
    final reportId = draft['reportId'] as String;
    if (PendingSyncManager.instance.isActive(reportId)) return;
    final createdAt =
        DateTime.tryParse(draft['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc();
    final selectedSegments = _segments.where(_isSegmentSelected).toList();
    final media = (report['media'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final shpFiles = (report['shpFiles'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    var totalBytes = 0;
    for (final item in [...media, ...shpFiles]) {
      final size = await _savedFileSize(item);
      item['sizeBytes'] = size;
      totalBytes += size;
    }
    report['syncBytesTotal'] = totalBytes;
    report['syncBytesSent'] = 0;
    report['syncPhase'] = 'QUEUED';
    report['serverTaskId'] = _serverTaskId;
    report['syncError'] = null;
    report['createdAt'] = createdAt.toIso8601String();
    _queueState = 'PENDING_SYNC';
    try {
      await _storeBackgroundReport(
        ownerId: ownerId,
        reportId: reportId,
        createdAt: createdAt,
        payload: report,
        state: 'PENDING_SYNC',
      );
    } catch (error) {
      _showMessage('Could not queue the $_workflowLabel for sync: $error');
      return;
    }
    if (!mounted) return;

    // Close the form immediately. The captured payload, hierarchy, and files
    // remain in the account-scoped store while the upload continues.
    setState(() {
      _draft = null;
      _saving = false;
    });
    PendingSyncManager.instance.start(
      id: reportId,
      formType: _workflowLabel,
      totalBytes: totalBytes,
      files: [...media, ...shpFiles].map(PendingSyncManager.fileLabel).toList(),
      run: (onBytesSent) => (_isOtn ? _runOtnSync : _runHindranceSync)(
        reportId: reportId,
        ownerId: ownerId,
        createdAt: createdAt,
        report: report,
        block: block,
        ring: ring,
        segments: selectedSegments,
        totalBytes: totalBytes,
        onBytesSent: onBytesSent,
      ),
    );
    _showMessage(
      '$_workflowLabel saved. Upload is continuing in Pending sync.',
    );
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _hierarchyErrorMessage(Object error) {
    final message = _errorMessage(error);
    final normalized = message.toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('connection timed out')) {
      return 'No saved Ring data for this Block. Connect to the internet and select this Block to sync its approved BoQ for offline use.';
    }
    return message;
  }

  Future<void> _capturePhoto(String slot) async {
    if (_ownerId == null || _draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      final media = await _mediaService.capturePhoto(
        ownerId: _ownerId!,
        reportId: _draft!['reportId'] as String,
        slot: slot,
        recordType: _recordType,
        createdAt: DateTime.tryParse(_draft?['createdAt']?.toString() ?? ''),
      );
      if (media != null && mounted) {
        setState(() => _media.add(media));
        await _persistDraft();
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _captureVideo(String slot, Duration duration) async {
    if (_ownerId == null || _draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      final media = await _mediaService.captureVideo(
        ownerId: _ownerId!,
        reportId: _draft!['reportId'] as String,
        slot: slot,
        maxDuration: duration,
        recordType: _recordType,
        createdAt: DateTime.tryParse(_draft?['createdAt']?.toString() ?? ''),
      );
      if (media != null && mounted) {
        setState(() => _media.add(media));
        await _persistDraft();
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickShpComponents() async {
    if (_ownerId == null || _draft == null) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _isOtn
            ? const ['kml']
            : const ['shp', 'shx', 'dbf', 'prj', 'cpg'],
        allowMultiple: true,
        withReadStream: !kIsWeb,
        withData: kIsWeb,
      );
      if (result == null) return;
      final files = result.files;
      if (_isOtn &&
          !files.every((file) => file.extension?.toLowerCase() == 'kml')) {
        _showMessage('Select a .kml file for OTN.');
        return;
      }
      if (!_isOtn &&
          !files.any((file) => file.extension?.toLowerCase() == 'shp')) {
        _showMessage(
          'Select the .shp file with any related .shx, .dbf, .prj, or .cpg files.',
        );
        return;
      }
      for (final file in files) {
        if (kIsWeb && file.bytes != null) {
          final saved = await _mediaService.storePickedBytes(
            ownerId: _ownerId!,
            reportId: _draft!['reportId'] as String,
            filename: file.name,
            kind: 'shp_component',
            bytes: file.bytes!,
            recordType: _recordType,
            createdAt: DateTime.tryParse(
              _draft?['createdAt']?.toString() ?? '',
            ),
          );
          _shpFiles.removeWhere((item) => item['name'] == file.name);
          _shpFiles.add(saved);
          continue;
        }
        final stream =
            file.readStream ??
            (file.path == null ? null : File(file.path!).openRead());
        File? stored;
        if (stream != null) {
          stored = await _mediaService.storePickedStream(
            ownerId: _ownerId!,
            reportId: _draft!['reportId'] as String,
            filename: file.name,
            stream: stream,
          );
        } else if (file.bytes != null) {
          stored = await _mediaService.storePickedFile(
            ownerId: _ownerId!,
            reportId: _draft!['reportId'] as String,
            filename: file.name,
            bytes: file.bytes!,
          );
        }
        if (stored == null) continue;
        _shpFiles.removeWhere((item) => item['name'] == file.name);
        _shpFiles.add({
          'name': file.name,
          'path': stored.path,
          'sizeBytes': await stored.length(),
          'syncState': 'LOCAL_SAVED',
        });
      }
      await _persistDraft();
      if (mounted) setState(() {});
    } catch (e) {
      _showMessage('Could not save the selected SHP files: $e');
    }
  }

  Future<void> _removeMedia(Map<String, dynamic> media) async {
    final slot = media['slot']?.toString();
    final removed = <Map<String, dynamic>>[media];
    if (slot == 'start_point') {
      removed.addAll(
        _media.where(
          (item) =>
              item['slot'] == 'walkthrough' ||
              item['slot'] == 'end_point' ||
              item['slot'] == 'additional_photo' ||
              item['slot'] == 'additional_video',
        ),
      );
    } else if (slot == 'walkthrough') {
      removed.addAll(
        _media.where(
          (item) =>
              item['slot'] == 'end_point' ||
              item['slot'] == 'additional_photo' ||
              item['slot'] == 'additional_video',
        ),
      );
    } else if (slot == 'end_point') {
      removed.addAll(
        _media.where(
          (item) =>
              item['slot'] == 'additional_photo' ||
              item['slot'] == 'additional_video',
        ),
      );
    }
    for (final item in removed.toSet()) {
      await _mediaService.deleteFileManagerCopy(item);
      final path = item['path']?.toString();
      if (item['storage'] == 'indexeddb' && item['mediaId'] != null) {
        await _store.deleteMediaBytes(item['mediaId'].toString());
      } else if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    setState(() => _media.removeWhere(removed.toSet().contains));
    await _persistDraft();
  }

  Future<void> _retakeMedia(String slot, {Duration? duration}) async {
    final existingIndex = _media.indexWhere((m) => m['slot'] == slot);
    if (existingIndex != -1) {
      final oldMedia = _media[existingIndex];
      await _mediaService.deleteFileManagerCopy(oldMedia);
      final path = oldMedia['path']?.toString();
      if (oldMedia['storage'] == 'indexeddb' && oldMedia['mediaId'] != null) {
        try {
          await _store.deleteMediaBytes(oldMedia['mediaId'].toString());
        } catch (_) {}
      } else if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      setState(() {
        _media.removeAt(existingIndex);
      });
    }
    if (slot == 'walkthrough' || slot == 'additional_video') {
      await _captureVideo(slot, duration ?? const Duration(minutes: 5));
    } else {
      await _capturePhoto(slot);
    }
  }

  Future<void> _removeShp(Map<String, dynamic> item) async {
    final path = item['path']?.toString();
    if (item['storage'] == 'indexeddb' && item['mediaId'] != null) {
      await _store.deleteMediaBytes(item['mediaId'].toString());
    } else if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    setState(() => _shpFiles.remove(item));
    await _persistDraft();
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
    const radius = BorderRadius.all(Radius.circular(16));
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(borderRadius: radius),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: const RoundedRectangleBorder(borderRadius: radius),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          border: OutlineInputBorder(borderRadius: radius),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          title: Text(_workflowLabel),
          backgroundColor: AppColors.headerGreen,
          foregroundColor: Colors.white,
          actions: [
            const PendingSyncAction(),
            IconButton(
              tooltip: 'Refresh task data',
              onPressed: _loading ? null : () => _load(forceRefresh: true),
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: HindranceGlassBackdrop(
          child: _draft == null ? _buildDraftList() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildDraftList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading)
          _Notice(
            icon: Icons.storage_outlined,
            text: 'Opening saved $_workflowLabel data…',
          ),
        if (_error != null) _Notice(icon: Icons.info_outline, text: _error!),
        if (_syncingTasks)
          const _Notice(
            icon: Icons.sync,
            text:
                'Refreshing assigned tasks in the background. Saved data stays available.',
          ),
        if (_taskListHasMore)
          OutlinedButton.icon(
            onPressed: _loadingMoreTasks ? null : _loadMoreTasks,
            icon: _loadingMoreTasks
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(
              _loadingMoreTasks ? 'Loading tasks…' : 'Load more assigned tasks',
            ),
          ),
        if (_fromCache && _tasks.isNotEmpty)
          const _Notice(
            icon: Icons.cloud_off,
            text: 'This account’s saved Block hierarchy is available offline.',
          ),
        if (_fromCache && _tasks.isEmpty)
          const _Notice(
            icon: Icons.cloud_off,
            text:
                'No Block hierarchy has been saved offline for this account yet.',
          ),
        if (!_fromCache && _tasks.isEmpty)
          const _Notice(
            icon: Icons.info_outline,
            text:
                'Block, ring, and segment choices will appear when task data is synced. No sample data is shown.',
          ),
        _outlineAction(
          icon: Icons.add,
          label: 'New $_workflowLabel Report',
          onPressed: _startNewDraft,
        ),
        const SizedBox(height: 24),
        ...[
          Text(
            '$_workflowLabel tasks from Dev',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loadingServerHindrances)
            _Notice(
              icon: Icons.sync,
              text: 'Loading created $_workflowLabel tasks from Dev…',
            ),
          if (_serverHindranceLoadFailed && _serverHindranceTasks.isEmpty)
            _Notice(
              icon: Icons.cloud_off,
              text:
                  'Could not reach Dev to load $_workflowLabel tasks. Check the connection and refresh.',
            ),
          if (!_loadingServerHindrances &&
              !_serverHindranceLoadFailed &&
              _visibleServerHindrances.isEmpty)
            _Notice(
              icon: Icons.inbox_outlined,
              text:
                  'No created $_workflowLabel tasks were returned for this account.',
            ),
          for (final task in _visibleServerHindrances)
            HindranceGlassSurface(
              padding: EdgeInsets.zero,
              margin: const EdgeInsets.only(bottom: 10),
              radius: 14,
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.primaryGreen,
                ),
                title: Text(task.displayName),
                subtitle: Text(
                  '${task.taskCode} · ${task.status} · ${task.circle} / ${task.district}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.visibility_outlined),
                onTap: () => _showServerTaskPreview(task),
              ),
            ),
          if (_serverHindrancesHaveMore)
            OutlinedButton.icon(
              onPressed: _loadingServerHindrances
                  ? null
                  : () => _loadServerHindranceTasks(
                      page: _serverHindranceNextPage,
                      append: true,
                    ),
              icon: const Icon(Icons.expand_more),
              label: Text(
                _loadingServerHindrances
                    ? 'Loading…'
                    : 'Load more Dev $_workflowLabel tasks',
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Offline drafts and pending reports',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_savedReports.isEmpty)
          _Notice(
            icon: Icons.inventory_2_outlined,
            text: 'No local $_workflowLabel reports yet.',
          ),
        for (final report in _savedReports)
          HindranceGlassSurface(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.only(bottom: 10),
            radius: 14,
            child: ListTile(
              leading: const Icon(
                Icons.report_problem_outlined,
                color: AppColors.primaryGreen,
              ),
              title: Text(
                (report['taskName'] ??
                        report['blockName'] ??
                        'New ${_workflowLabel.toLowerCase()} report')
                    .toString(),
              ),
              subtitle: Text(
                '${report['queueState'] ?? 'LOCAL_SAVED'} · ${report['updatedAt'] ?? report['createdAt'] ?? ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _resumeDraft(report),
            ),
          ),
      ],
    );
  }

  void _showServerTaskPreview(TaskModel task) {
    final fieldData = task.taskExecution?.fieldData;
    final routeSegments =
        task.routeSnapshot?.routes
            .expand((route) => route.segments)
            .map((segment) => segment.segmentCode)
            .where((code) => code.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(task.displayName),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Preview from Dev task data',
                  style: TextStyle(color: Colors.black54),
                ),
                _detailRow('Task ID', task.id),
                _detailRow('Task code', task.taskCode),
                _detailRow('Status', task.status),
                _detailRow('Circle', task.circle),
                _detailRow('District', task.district),
                _detailRow('Block', task.blockName),
                _detailRow(
                  'Created',
                  task.createdAt?.toLocal().toString() ?? '',
                ),
                _detailRow(
                  'Updated',
                  task.updatedAt?.toLocal().toString() ?? '',
                ),
                _detailRow('Description', task.description ?? ''),
                if (task.remarks?.trim().isNotEmpty == true)
                  _detailRow('Remarks', task.remarks!),
                if (task.routeSnapshot?.routes.isNotEmpty == true)
                  _detailRow(
                    'Rings',
                    task.routeSnapshot!.routes
                        .map((route) => route.routeName)
                        .where((name) => name.isNotEmpty)
                        .join(', '),
                  ),
                if (task.segmentSnapshots.isNotEmpty ||
                    routeSegments.isNotEmpty)
                  _detailRow(
                    'Segments',
                    {
                      ...task.segmentSnapshots
                          .map((segment) => segment.segmentCode)
                          .where((code) => code.isNotEmpty),
                      ...routeSegments,
                    }.join(', '),
                  ),
                if (fieldData?.hindranceTypes.isNotEmpty == true)
                  _detailRow(
                    'Hindrance types',
                    fieldData!.hindranceTypes.join(', '),
                  ),
                if (fieldData?.hindranceRemarks?.trim().isNotEmpty == true)
                  _detailRow('Hindrance remarks', fieldData!.hindranceRemarks!),
                if (fieldData?.hindranceList.isNotEmpty == true)
                  for (
                    var index = 0;
                    index < fieldData!.hindranceList.length;
                    index++
                  )
                    _detailRow(
                      'Hindrance ${index + 1}',
                      fieldData.hindranceList[index].description ??
                          fieldData.hindranceList[index].type,
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionStep() => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              _isOtn
                  ? 'Choose the affected route segments. The OTN evidence form opens after you continue.'
                  : 'Choose the affected route segments. The Hindrance form opens after the task is created.',
            ),
            _section('Block → Ring → Segments', [
              _buildHierarchySelector(),
              if (_loadingBoqApprovals) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Checking approved BoQs for Circle Blocks ($_boqApprovalChecked/$_boqApprovalTotal)…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (_boqApprovalLoadError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _boqApprovalLoadError!,
                          style: const TextStyle(
                            color: Color(0xFF7C2D12),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(_preloadBoqApprovals()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (!_loadingBoqApprovals &&
                  _circle != null &&
                  _districts.isEmpty &&
                  _boqApprovalLoadError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No District in this Circle has a Block with exactly one approved BoQ revision.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (!_loadingBoqApprovals &&
                  _circle != null &&
                  _district != null &&
                  _visibleBlocks.isEmpty &&
                  _boqApprovalLoadError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No Block in this District has exactly one approved BoQ revision.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_loadingHierarchy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (_blockId != null && _hierarchyLoadError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _loadingHierarchy
                        ? 'Loading the approved BoQ hierarchy…'
                        : _savingTaskPack
                        ? 'Saving this hierarchy offline…'
                        : _taskPackSaved
                        ? 'This hierarchy is available offline.'
                        : 'This hierarchy is not saved offline yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_hierarchyLoadError != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
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
            ]),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || _loadingHierarchy
                  ? null
                  : _createTaskAndContinue,
              child: Text(_saving ? 'Preparing $_workflowLabel…' : 'Continue'),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildForm() {
    if (_workflowStage == 'hierarchy_selection') return _buildSelectionStep();
    if (_workflowStage == 'ccn_question' && !_isOtn) {
      return _buildCcnQuestion();
    }
    final start = _media
        .where((item) => item['slot'] == 'start_point')
        .firstOrNull;
    final walkthrough = _media
        .where((item) => item['slot'] == 'walkthrough')
        .firstOrNull;
    final end = _media.where((item) => item['slot'] == 'end_point').firstOrNull;
    final extraPhotos = _media
        .where(
          (item) =>
              item['slot'] == 'additional_photo' || item['slot'] == 'ie_photo',
        )
        .toList();
    final iePhoto = _media
        .where((item) => item['slot'] == 'ie_photo')
        .firstOrNull;
    final extraVideos = _media
        .where((item) => item['slot'] == 'additional_video')
        .toList();
    return Column(
      children: [
        if (_loading)
          const _Notice(
            icon: Icons.storage_outlined,
            text: 'Opening saved Hindrance data…',
          ),
        if (_error != null) _Notice(icon: Icons.info_outline, text: _error!),
        if (_syncingTasks)
          const _Notice(
            icon: Icons.sync,
            text:
                'Refreshing assigned tasks in the background. Saved data stays available.',
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _draft = null),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      _isSubmitted
                          ? '$_workflowLabel Preview'
                          : 'New $_workflowLabel',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_fromCache && _tasks.isNotEmpty)
                const _Notice(
                  icon: Icons.cloud_off,
                  text:
                      'Working from locally cached task data. The report and media stay on this device.',
                ),
              if (_queueState == 'PARTIALLY_SAVED')
                const _Notice(
                  icon: Icons.cloud_upload_outlined,
                  text:
                      'Partially saved on this device. Uploads and submission will resume when you retry with an internet connection. This stays open until the server confirms the final response.',
                ),
              if (_isSubmitted)
                const _Notice(
                  icon: Icons.verified_outlined,
                  text:
                      'This Hindrance has been submitted and is read-only while it is under review.',
                ),
              if (_fromCache && _tasks.isEmpty)
                const _Notice(
                  icon: Icons.cloud_off,
                  text: 'No task snapshot is saved for this account yet.',
                ),
              if (_taskListHasMore)
                OutlinedButton.icon(
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
              if (kIsWeb)
                const _Notice(
                  icon: Icons.info_outline,
                  text:
                      'Browser camera and file selection are available when permitted. Captured evidence is saved in this browser for offline access.',
                ),
              _section('$_workflowLabel Task Details', [
                _detailRow(
                  _isOtn ? 'Local OTN ID' : 'Hindrance ID',
                  _serverTaskId ?? _draft?['hindranceId']?.toString() ?? '—',
                ),
                _detailRow(
                  'Block',
                  _selectedBlock == null ? '—' : _displayName(_selectedBlock!),
                ),
                _detailRow(
                  'Ring',
                  _selectedRing == null ? '—' : _displayName(_selectedRing!),
                ),
                _detailRow(
                  'Segments',
                  _segments
                      .where(_isSegmentSelected)
                      .map((segment) => segment.segmentCode)
                      .join(', '),
                ),
                const SizedBox(height: 10),
                if (_segments.where(_isSegmentSelected).isNotEmpty)
                  _buildSegmentTable(
                    _segments.where(_isSegmentSelected).toList(),
                  ),
              ]),
              _section(_isOtn ? 'OTN Details' : 'Hindrance Classification', [
                if (_isOtn) ...[
                  TextField(
                    controller: _otnReasonController,
                    enabled: !_isSubmitted,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otnSubtype1Controller,
                    enabled: !_isSubmitted,
                    decoration: const InputDecoration(
                      labelText: 'Subtype 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otnSubtype2Controller,
                    enabled: !_isSubmitted,
                    decoration: const InputDecoration(
                      labelText: 'Subtype 2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_isOtn)
                  DropdownButtonFormField<String>(
                    key: ValueKey('hindrance-type-$_hindranceType'),
                    initialValue: _dropdownValue(_hindranceType),
                    decoration: const InputDecoration(
                      labelText: 'Hindrance Type',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select Hindrance Type'),
                    items: _classificationItems(
                      HindranceClassification.types,
                      _hindranceType,
                    ),
                    onChanged: _isSubmitted
                        ? null
                        : (value) {
                            setState(() => _hindranceType = value);
                            _queueAutosave();
                          },
                  ),
                if (!_isOtn) const SizedBox(height: 16),
                if (!_isOtn)
                  DropdownButtonFormField<String>(
                    key: ValueKey('sub-hindrance-type-$_subHindranceType'),
                    initialValue: _dropdownValue(_subHindranceType),
                    decoration: const InputDecoration(
                      labelText: 'Sub-Hindrance Type',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select Sub-Hindrance Type'),
                    items: _classificationItems(
                      HindranceClassification.subtypes,
                      _subHindranceType,
                    ),
                    onChanged: _isSubmitted
                        ? null
                        : (value) {
                            setState(() => _subHindranceType = value);
                            _queueAutosave();
                          },
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  enabled: !_isSubmitted,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: _isOtn
                        ? 'OTN details'
                        : 'Bottleneck Description',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _captureStep(
                  title: _isOtn ? 'OTN Start Point' : 'Hindrance Start Point',
                  slot: 'start_point',
                  record: start,
                  buttonText: 'Capture Start Photo',
                  enabled: !_saving && start == null,
                  onPressed: () => _capturePhoto('start_point'),
                ),
                const SizedBox(height: 16),
                _captureStep(
                  title: 'Walkthrough Video',
                  slot: 'walkthrough',
                  record: walkthrough,
                  buttonText: 'Capture 5 Minute Video',
                  enabled: !_saving && walkthrough == null,
                  onPressed: () =>
                      _captureVideo('walkthrough', const Duration(minutes: 5)),
                  helper: 'Capture a walkthrough video of up to 5 minutes.',
                ),
                const SizedBox(height: 16),
                _captureStep(
                  title: _isOtn ? 'OTN End Point' : 'Hindrance End Point',
                  slot: 'end_point',
                  record: end,
                  buttonText: 'Capture End Photo',
                  enabled: !_saving && end == null,
                  onPressed: () => _capturePhoto('end_point'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Additional Photos (up to 10)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _mediaGrid(
                  extraPhotos,
                  onRemove: _removeMedia,
                  readOnly: _isSubmitted,
                ),
                OutlinedButton.icon(
                  onPressed:
                      !_isSubmitted && extraPhotos.length < 10 && !_saving
                      ? () => _capturePhoto('additional_photo')
                      : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    extraPhotos.length < 10
                        ? 'Add Photo (${extraPhotos.length}/10)'
                        : 'Photo Limit Reached',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Additional Videos (up to 2, 3 minutes each)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _mediaGrid(
                  extraVideos,
                  onRemove: _removeMedia,
                  readOnly: _isSubmitted,
                ),
                OutlinedButton.icon(
                  onPressed: !_isSubmitted && extraVideos.length < 2 && !_saving
                      ? () => _captureVideo(
                          'additional_video',
                          const Duration(minutes: 3),
                        )
                      : null,
                  icon: const Icon(Icons.video_call_outlined),
                  label: Text(
                    extraVideos.length < 2
                        ? 'Add Video (${extraVideos.length}/2)'
                        : 'Video Limit Reached',
                  ),
                ),
                const SizedBox(height: 12),
                const _Notice(
                  icon: Icons.high_quality_outlined,
                  text:
                      'Videos are saved byte-for-byte with no lossy re-encode. Upload compression will be added when the S3/backend limits are known.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Independent Engineer (IE)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ieNameController,
                  enabled: !_isSubmitted,
                  decoration: const InputDecoration(
                    labelText: 'IE Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _iePhoneController,
                  enabled: !_isSubmitted,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'IE Phone Number *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'IE Photo Needed?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Yes'),
                      selected: _ieAffected == true,
                      onSelected: _isSubmitted
                          ? null
                          : (selected) => setState(() {
                              _ieAffected = selected ? true : null;
                              _queueAutosave();
                            }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('No'),
                      selected: _ieAffected == false,
                      onSelected: _isSubmitted
                          ? null
                          : (selected) => setState(() {
                              _ieAffected = selected ? false : null;
                              if (selected) {
                                _media.removeWhere(
                                  (item) => item['slot'] == 'ie_photo',
                                );
                              }
                              _queueAutosave();
                            }),
                    ),
                  ],
                ),
                if (_ieAffected == true) ...[
                  const SizedBox(height: 10),
                  _captureStep(
                    title: 'IE Photo',
                    slot: 'ie_photo',
                    record: iePhoto,
                    buttonText: 'Capture IE Photo',
                    enabled: iePhoto == null && !_saving,
                    onPressed: () => _capturePhoto('ie_photo'),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  _isOtn ? 'Upload KML File' : 'Upload SHP File',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isSubmitted || _saving
                      ? null
                      : _pickShpComponents,
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    _isOtn ? 'Select KML file' : 'Select SHP and related files',
                  ),
                ),
                for (final item in _shpFiles)
                  ListTile(
                    dense: true,
                    title: Text(item['name'].toString()),
                    subtitle: Text(
                      '${((item['sizeBytes'] as num?) ?? 0) ~/ 1024} KB · stored locally',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitted ? null : () => _removeShp(item),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              _Notice(
                icon: Icons.cloud_upload_outlined,
                text: _isOtn
                    ? 'OTN evidence uploads to the task service before the OTN form is submitted.'
                    : 'Submitting requests presigned upload URLs, uploads photos, videos, and SHP files to S3, then sends their returned keys with the report.',
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _isSubmitted ? null : _queueReport,
                child: Text(
                  _saving
                      ? 'Submitting…'
                      : _isSubmitted
                      ? 'Already submitted'
                      : _isOtn
                      ? 'Submit OTN'
                      : 'Submit Hindrance',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCcnQuestion() {
    final report = _payload();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              _section('Hindrance Submitted', [
                _detailRow(
                  'Hindrance ID',
                  report['hindranceId']?.toString() ?? '',
                ),
                _detailRow(
                  'Block',
                  report['blockName']?.toString() ?? 'Not selected',
                ),
                _detailRow(
                  'Ring',
                  report['ringName']?.toString() ?? 'Not selected',
                ),
                _detailRow(
                  'Segments',
                  (report['affectedSegments'] as List)
                      .map((segment) => (segment as Map)['code'].toString())
                      .join(', '),
                ),
                _detailRow(
                  'Description',
                  report['description']?.toString() ?? '',
                ),
                const SizedBox(height: 8),
                const _Notice(
                  icon: Icons.verified_outlined,
                  text:
                      'The Hindrance was accepted by the server. Choose whether a related CCN is required.',
                ),
              ]),
              _section('Is CCN required?', [
                RadioGroup<bool>(
                  groupValue: _ccnRequired,
                  onChanged: (value) => setState(() {
                    _ccnRequired = value;
                    _queueAutosave();
                  }),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        title: Text('Yes, create a CCN'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<bool>(
                        value: false,
                        title: Text('No, CCN is not required'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _ccnRequired == null
                  ? null
                  : _ccnRequired == true
                  ? _continueToCcn
                  : _finishWithoutCcn,
              icon: Icon(
                _ccnRequired == true
                    ? Icons.arrow_forward
                    : Icons.save_outlined,
              ),
              label: Text(
                _ccnRequired == true
                    ? 'Continue to CCN'
                    : _ccnRequired == false
                    ? 'Save and Done'
                    : 'Choose Yes or No',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => HindranceGlassSurface(
    margin: const EdgeInsets.only(top: 16),
    radius: 16,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Divider(height: 20),
        ...children,
      ],
    ),
  );

  Widget _disabledDropdown(String label, String hint) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: const [],
        onChanged: null,
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
        width: double.infinity,
        height: double.infinity,
        color: isVideo ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        child: isVideo
            ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 36)
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

  String _captureTime(Map<String, dynamic>? record) {
    final location = record?['location'];
    final raw = location is Map ? location['capturedAt']?.toString() : null;
    final capturedAt = DateTime.tryParse(raw ?? '');
    if (capturedAt == null) return 'Not recorded';
    final local = capturedAt.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _coordinateText(dynamic value) {
    if (value is num) return value.toStringAsFixed(6);
    final number = double.tryParse(value?.toString() ?? '');
    return number?.toStringAsFixed(6) ?? 'Not recorded';
  }

  Widget _mediaMetadata(Map<String, dynamic>? record) {
    final rawLocation = record?['location'];
    final location = rawLocation is Map
        ? rawLocation
        : const <String, dynamic>{};
    final lat = location['latitude'];
    final lng = location['longitude'];
    final accuracy = location['accuracyMeters'];
    final accuracyText = accuracy is num
        ? '${accuracy.toStringAsFixed(1)} m'
        : double.tryParse(accuracy?.toString() ?? '')?.toStringAsFixed(1) ??
              'Not recorded';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lat ${_coordinateText(lat)}  ·  Lon ${_coordinateText(lng)}',
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
        const SizedBox(height: 3),
        Text(
          'Captured ${_captureTime(record)}',
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
        const SizedBox(height: 3),
        Text(
          'GPS accuracy $accuracyText',
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _captureStep({
    required String title,
    required String slot,
    required Map<String, dynamic>? record,
    required String buttonText,
    required bool enabled,
    required VoidCallback onPressed,
    String? helper,
  }) {
    final filename =
        record?['filename']?.toString() ??
        record?['path']?.toString().split('/').last ??
        'Saved evidence';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (helper != null)
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
              onPressed: enabled && !_isSubmitted ? onPressed : null,
              icon: Icon(
                slot.contains('video') || slot == 'walkthrough'
                    ? Icons.videocam_outlined
                    : Icons.camera_alt_outlined,
              ),
              label: Text(buttonText),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showMediaViewer(record),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: _buildMediaThumbnail(record),
                            ),
                          ),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record['fileManagerExportError'] != null
                                ? 'File manager copy failed · ${record['fileManagerExportError']}'
                                : record['fileManagerFolder'] != null
                                ? 'Files: ${record['fileManagerFolder']}'
                                : record['kind'] == 'video'
                                ? 'Saved video · tap preview'
                                : 'Saved photo · tap to enlarge',
                            style: TextStyle(
                              fontSize: 11,
                              color: record['fileManagerExportError'] != null
                                  ? AppColors.criticalRed
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isSubmitted)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _retakeMedia(
                              slot,
                              duration: slot == 'walkthrough'
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
                            visualDensity: VisualDensity.compact,
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
                const Divider(height: 14),
                _mediaMetadata(record),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mediaGrid(
    List<Map<String, dynamic>> items, {
    required Future<void> Function(Map<String, dynamic>) onRemove,
    bool readOnly = false,
  }) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'None added',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      );
    }
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isVideo = item['kind'] == 'video';
        final labelName = isVideo
            ? 'VID_${index + 1}'
            : 'IMG_${(index + 1).toString().padLeft(2, '0')}';

        return GestureDetector(
          onTap: () => _showMediaViewer(item),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _buildMediaThumbnail(item),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$labelName · ${item['filename'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(isVideo ? 'Saved video' : 'Saved photo'),
                        ],
                      ),
                    ),
                    if (!readOnly)
                      IconButton(
                        onPressed: () => onRemove(item),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.criticalRed,
                        ),
                        tooltip: 'Remove',
                      ),
                  ],
                ),
                const Divider(height: 14),
                _mediaMetadata(item),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => HindranceGlassSurface(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    radius: 14,
    child: Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: const TextStyle(color: Colors.black54, fontSize: 12),
    ),
  );
}

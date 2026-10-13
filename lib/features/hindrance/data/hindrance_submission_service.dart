import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hero_app/core/constants/app_constants.dart';
import 'package:hero_app/features/auth/services/auth_storage_service.dart';
import 'package:hero_app/features/hindrance/data/hindrance_local_store.dart';
import 'package:hero_app/models/task_model.dart';
import 'package:hero_app/services/api/api_client.dart';

/// Creates and submits Hindrance and CCN tasks through the IlYnc UAT task service.
/// Plan metadata is read from the selected task; missing required values are
/// reported instead of guessed.
class HindranceSubmissionService {
  static const _defaultProjectPhase = 'PHASE_1';

  HindranceSubmissionService({ApiClient? api})
    : _api = api ?? ApiClient(baseUrl: AppConstants.ilyncApiBaseUrl);

  final ApiClient _api;
  final _store = HindranceLocalStore.instance;
  String? get _taskToken => AppConstants.ilyncIsDev
      ? AuthStorageService().devTaskAccessToken
      : AuthStorageService().uatTaskAccessToken;
  String get _environmentLabel => AppConstants.ilyncEnvironment.toUpperCase();

  Future<String> createTask({
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    String taskType = 'HINDRANCE',
    String? taskName,
  }) async {
    final token = _taskToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to establish $_environmentLabel task-service access.');
    }
    _api.setAuthToken(token);
    final rawPlanId =
        _findMetaValue(block.meta, const {
          'networkPlanId',
          'network_plan_id',
        }) ??
        block.routeSnapshot?.routes
            .map((route) => route.planId)
            .whereType<String>()
            .where((planId) => planId.trim().isNotEmpty)
            .firstOrNull;
    final networkPlanId = rawPlanId?.trim().isNotEmpty == true
        ? rawPlanId!.trim()
        : null;
    // The task read API currently omits projectPhase for assigned Blocks.
    // Keep the Dev task-service enum format while preferring the actual
    // project phase from location master data whenever it is present.
    final rawProjectPhase =
        block.locationSnapshot?.projectPhase ??
        _findMetaValue(block.meta, const {'projectPhase', 'project_phase'});
    final projectPhase = taskType.trim().toUpperCase() == 'OTN'
        ? 'PHASE_2'
        : rawProjectPhase?.trim().isNotEmpty == true
        ? rawProjectPhase!.trim()
        : _defaultProjectPhase;
    // Task IDs identify execution rows. BoQ is keyed by its master Block ID,
    // and the routes endpoint returns the authoritative Block and route IDs
    // used by /api/tasks.
    final knownBoqBlockId =
        block.locationSnapshot?.blockId?.trim().isNotEmpty == true
        ? block.locationSnapshot!.blockId!.trim()
        : _findMetaValue(block.meta, const {'blockId', 'block_id'});
    if (knownBoqBlockId == null || knownBoqBlockId.trim().isEmpty) {
      throw StateError(
        'Cannot create the task because the selected Block has no master-data Block ID. Refresh task data before continuing.',
      );
    }
    final boqBlockId = knownBoqBlockId.trim();
    final approvedPlan = await _findApprovedBoq(boqBlockId, networkPlanId);
    final resolvedPlanId = approvedPlan['planId']!;
    final revision = approvedPlan['revisionNo']!;
    final routeData = await _fetchPlanRoutes(
      resolvedPlanId,
      revisionNo: revision,
    );
    final resolvedBlockId = routeData['blockId']?.toString();
    if (resolvedBlockId == null || resolvedBlockId.isEmpty) {
      throw StateError(
        'The BoQ routes response is missing its master Block ID.',
      );
    }
    if (resolvedBlockId != boqBlockId) {
      throw StateError(
        'The selected Block does not match the approved BoQ plan. Refresh the task hierarchy and try again.',
      );
    }
    final routes = (routeData['routes'] as List? ?? const [])
        .whereType<Map>()
        .map((route) => Map<String, dynamic>.from(route))
        .toList();
    final selectedRoute = _matchRoute(ring, routes);
    if (selectedRoute == null) {
      throw StateError(
        'Could not match ${ring.displayName} to a route in the approved BoQ plan. Refresh task data before continuing.',
      );
    }
    final routeId = selectedRoute['id']?.toString();
    if (routeId == null || routeId.isEmpty) {
      throw StateError('The selected BoQ route has no Geo route ID.');
    }
    final routeSegments = (selectedRoute['segments'] as List? ?? const [])
        .whereType<Map>()
        .map((segment) => Map<String, dynamic>.from(segment))
        .toList();
    final missing = <String>[
      if (int.tryParse(revision) == null) 'BoQ revision number',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot create the Hindrance/CCN task yet. The selected Block is missing ${missing.join(', ')}. Refresh task data or ask the plan owner to add these fields.',
      );
    }
    if (segments.isEmpty) {
      throw StateError('Select at least one segment before continuing.');
    }
    final mergedSelections = <Map<String, dynamic>>[];
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final matchingRouteSegments = routeSegments.where((geoSegment) {
        final code =
            (geoSegment['segmentCode'] ?? geoSegment['legacySegmentCode'] ?? '')
                .toString();
        return code == segment.segmentCode;
      }).toList();
      if (matchingRouteSegments.length != 1) {
        throw StateError(
          'Segment ${segment.segmentCode} could not be matched uniquely in the approved BoQ route. Refresh task data before continuing.',
        );
      }
      final geoSegment = matchingRouteSegments.single;
      final segmentId = geoSegment['id']?.toString();
      if (segmentId == null || segmentId.isEmpty) {
        throw StateError(
          'BoQ segment ${segment.segmentCode} has no Geo segment ID.',
        );
      }
      mergedSelections.add({
        'orderIndex': index,
        'blockId': resolvedBlockId,
        'ringId': routeId,
        'ringName': (selectedRoute['routeName'] ?? ring.displayName).toString(),
        'segmentId': segmentId,
        'segmentCode': segment.segmentCode,
      });
    }
    final normalizedType = taskType.trim().toUpperCase();
    if (normalizedType != 'HINDRANCE' && normalizedType != 'CCN' && normalizedType != 'OTN') {
      throw ArgumentError.value(
        taskType,
        'taskType',
        'Must be HINDRANCE, CCN, or OTN.',
      );
    }
    final response = await _api.post(
      '${AppConstants.ilyncApiBaseUrl}/api/tasks',
      body: {
        'taskType': normalizedType,
        'structure': 'MERGED',
        'taskName': taskName?.trim().isNotEmpty == true
            ? taskName!.trim()
            : '$normalizedType at ${ring.displayName}',
        'dailyTaskTarget': 1,
        'projectPhase': projectPhase,
        'boqRevisionNo': int.parse(revision),
        'taskConfig': {
          'kind': normalizedType,
          'blockId': resolvedBlockId,
          'networkPlanId': resolvedPlanId,
        },
        'mergedSelections': mergedSelections,
      },
    );
    final rootTask = _nestedMap(response, 'data')?['rootTask'];
    final id = rootTask is Map ? rootTask['id']?.toString() : null;
    if (id == null || id.isEmpty) {
      throw StateError('Task service did not return the merged task ID.');
    }
    return id;
  }

  Future<String> submitCcn({
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    required Map<String, dynamic> report,
    String? existingTaskId,
    Future<void> Function(String taskId)? onTaskCreated,
    Future<void> Function(int bytesSent)? onUploadBytes,
  }) async {
    final token = _taskToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to establish $_environmentLabel task-service access.');
    }
    _api.setAuthToken(token);
    var taskId = existingTaskId;
    if (taskId == null || taskId.isEmpty) {
      taskId = await createTask(
        block: block,
        ring: ring,
        segments: segments,
        taskType: 'CCN',
        taskName: report['description']?.toString().trim().isNotEmpty == true
            ? report['description'].toString().trim()
            : 'CCN at ${ring.displayName}',
      );
      await onTaskCreated?.call(taskId);
    }

    final photos = await _uploadPhotos(
      taskId,
      report['media'] as List? ?? const [],
      fieldPrefix: 'ccn',
      onUploadBytes: onUploadBytes,
    );
    final selectedCodes = segments
        .map((segment) => segment.segmentCode)
        .toList();
    final category = report['category']?.toString();
    final subtype = report['subtype']?.toString();
    final reason = [
      category,
      subtype,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' - ');
    final body = {
      'taskId': taskId,
      'fieldData': {
        'surveyKind': 'CCN',
        'remarks': report['description']?.toString() ?? '',
        'proposedCcn': {
          'description': report['description']?.toString() ?? '',
          if (reason.isNotEmpty) 'reason': reason,
          'affectedScope': selectedCodes.join(', '),
          'photos': photos,
          'remarks': report['description']?.toString() ?? '',
        },
      },
      'attachmentKeys': const <String>[],
    };
    await _api.post(
      '${AppConstants.ilyncApiBaseUrl}/api/tasks/save',
      body: body,
    );
    final submitted = await _api.post(
      '${AppConstants.ilyncApiBaseUrl}/api/tasks/submit',
      body: body,
    );
    _validateSubmitStatus(submitted);
    return taskId;
  }

  /// Uploads OTN evidence with the OTN contract's single photo-upload URL
  /// endpoint, then persists and submits the same OtnTaskData payload.
  Future<String> submitOtn({
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    required Map<String, dynamic> report,
    String? existingTaskId,
    Future<void> Function(String taskId)? onTaskCreated,
    Future<void> Function()? onBeforeSave,
    Future<void> Function()? onBeforeSubmit,
    Future<void> Function()? onUploadProgress,
    Future<void> Function(int bytesSent)? onUploadBytes,
  }) async {
    final token = _taskToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to establish $_environmentLabel task-service access.');
    }
    _api.setAuthToken(token);
    var taskId = existingTaskId;
    if (taskId == null || taskId.isEmpty) {
      taskId = await createTask(
        block: block,
        ring: ring,
        segments: segments,
        taskType: 'OTN',
        taskName: 'OTN at ${ring.displayName}',
      );
      await onTaskCreated?.call(taskId);
    }

    final media = (report['media'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final shpFiles = (report['shpFiles'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final evidence = <String, dynamic>{
      'photos': <Map<String, dynamic>>[],
      'routeVideos': <Map<String, dynamic>>[],
      'endVideos': <Map<String, dynamic>>[],
      'kmlFiles': <String>[],
    };
    var index = 0;
    Future<Map<String, dynamic>> upload(Map<String, dynamic> item) async {
      final slot = item['slot']?.toString() ?? '';
      final key = item['uploadKey']?.toString();
      final photoKey = key?.isNotEmpty == true
          ? key!
          : await _uploadFile(
              taskId: taskId!,
              field: switch (slot) {
                'start_point' => 'START_PHOTO',
                'end_point' => 'END_PHOTO',
                'walkthrough' => 'ROUTE_WALK_VIDEO',
                'additional_photo' => 'ADDITIONAL_PHOTO_${++index}',
                'additional_video' => 'ADDITIONAL_ROUTE_VIDEO_${++index}',
                _ => 'OTN_EVIDENCE_${++index}',
              },
              contentType: _contentType(item),
              bytes: await _requiredBytes(item, 'OTN evidence'),
              onBytesSent: onUploadBytes,
              endpoint: '/api/survey/photo-upload-url',
              keyName: 'photoKey',
            );
      item
        ..['uploadKey'] = photoKey
        ..['syncState'] = 'UPLOADED';
      await onUploadProgress?.call();
      return _mediaPayload(item, photoKey, _displayLabel(slot));
    }

    // Contract requires photos to complete before video uploads.
    for (final item in media.where((item) => item['kind'] == 'photo')) {
      final photo = await upload(item);
      (evidence['photos'] as List<Map<String, dynamic>>).add(photo);
    }
    final start = _mediaForSlot(media, 'start_point');
    final end = _mediaForSlot(media, 'end_point');
    for (final item in media.where((item) => item['kind'] == 'video')) {
      final video = await upload(item);
      if (item['slot'] == 'walkthrough') {
        evidence['walkthroughVideo'] = video;
        (evidence['routeVideos'] as List<Map<String, dynamic>>).add(video);
      } else if (item['slot'] == 'additional_video') {
        (evidence['routeVideos'] as List<Map<String, dynamic>>).add(video);
      } else {
        (evidence['endVideos'] as List<Map<String, dynamic>>).add(video);
      }
    }
    for (final file in shpFiles) {
      final mime = 'application/vnd.google-earth.kml+xml';
      final key = file['uploadKey']?.toString().isNotEmpty == true
          ? file['uploadKey'].toString()
          : await _uploadFile(
              taskId: taskId,
              field: 'KML_${++index}',
              contentType: mime,
              bytes: await _requiredBytes(file, 'OTN KML file'),
              onBytesSent: onUploadBytes,
              endpoint: '/api/survey/photo-upload-url',
              keyName: 'photoKey',
            );
      file
        ..['uploadKey'] = key
        ..['syncState'] = 'UPLOADED';
      (evidence['kmlFiles'] as List<String>).add(key);
      await onUploadProgress?.call();
    }
    final startLocation = _locationOf(start);
    final endLocation = _locationOf(end);
    final description = report['description']?.toString() ?? '';
    final otnId = report['otnId']?.toString().trim();
    final selectedCodes = segments.map((segment) => segment.segmentCode).join(', ');
    final startPhoto = start == null ? null : _mediaPayload(start, start['uploadKey'].toString(), 'Start Photo');
    final endPhoto = end == null ? null : _mediaPayload(end, end['uploadKey'].toString(), 'End Photo');
    final routeVideos = evidence['routeVideos'] as List<Map<String, dynamic>>;
    final endVideos = evidence['endVideos'] as List<Map<String, dynamic>>;
    final additionalStartPhotos = (evidence['photos'] as List<Map<String, dynamic>>)
        .where((photo) => photo['label'] == 'Additional Photo').toList();
    final fieldData = <String, dynamic>{
      'surveyKind': 'OTN',
      if (otnId?.isNotEmpty == true) 'otnId': otnId,
      'currentStep': 1,
      'remarks': description,
      'proposedOtn': {
        if (otnId?.isNotEmpty == true) 'otnId': otnId,
        'otnDetails': description,
        'description': description,
        'reason': report['otnReason']?.toString() ?? '',
        'affectedScope': report['affectedScope']?.toString().trim().isNotEmpty == true
            ? report['affectedScope']
            : selectedCodes,
        'subtype1': report['otnSubtype1']?.toString() ?? '',
        'subtype2': report['otnSubtype2']?.toString() ?? '',
        if (startLocation['latitude'] != null) 'sLatitude': startLocation['latitude'],
        if (startLocation['longitude'] != null) 'sLongitude': startLocation['longitude'],
        if (endLocation['latitude'] != null) 'eLatitude': endLocation['latitude'],
        if (endLocation['longitude'] != null) 'eLongitude': endLocation['longitude'],
        if (startPhoto != null) 'startPhoto': startPhoto,
        if (endPhoto != null) 'endPhoto': endPhoto,
        'additionalStartPhotos': additionalStartPhotos,
        'additionalEndPhotos': <dynamic>[],
        'additionalRouteVideos': routeVideos,
        'additionalEndVideos': endVideos,
        if ((evidence['kmlFiles'] as List).isNotEmpty) 'kmlFiles': evidence['kmlFiles'],
      },
    };
    final body = {'taskId': taskId, 'fieldData': fieldData, 'attachmentKeys': const <String>[]};
    await onBeforeSave?.call();
    await _api.post('${AppConstants.ilyncApiBaseUrl}/api/tasks/save', body: body);
    await onBeforeSubmit?.call();
    final submitted = await _api.post('${AppConstants.ilyncApiBaseUrl}/api/tasks/submit', body: body);
    _validateSubmitStatus(submitted);
    final submittedId = _nestedMap(submitted, 'data')?['id']?.toString();
    return submittedId?.isNotEmpty == true ? submittedId! : taskId;
  }

  Future<String> submit({
    required TaskModel block,
    required TaskModel ring,
    required List<TaskSegmentModel> segments,
    required Map<String, dynamic> report,
    String? existingTaskId,
    Future<void> Function(String taskId)? onTaskCreated,
    Future<void> Function()? onBeforeSave,
    Future<void> Function()? onBeforeSubmit,
    Future<void> Function()? onUploadProgress,
    Future<void> Function(int bytesSent)? onUploadBytes,
  }) async {
    final token = _taskToken;
    if (token == null || token.isEmpty) {
      throw StateError('Sign in again to establish $_environmentLabel task-service access.');
    }
    _api.setAuthToken(token);
    var taskId = existingTaskId;
    if (taskId == null || taskId.isEmpty) {
      // Share the same validated create path used by the selection screen.
      // Save/submit only need the merged ID; revalidating plan and segment
      // metadata here rejected otherwise valid already-created tasks.
      taskId = await createTask(
        block: block,
        ring: ring,
        segments: segments,
        taskType: 'HINDRANCE',
        taskName: 'Hindrance at ${ring.displayName}',
      );
      await onTaskCreated?.call(taskId);
    }
    final mergedTaskId = taskId;

    final media = (report['media'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final uploaded = await _uploadHindranceEvidence(
      mergedTaskId,
      media,
      (report['shpFiles'] as List? ?? const []).whereType<Map>().toList(),
      onUploadProgress: onUploadProgress,
      onUploadBytes: onUploadBytes,
    );
    final start = _mediaForSlot(media, 'start_point');
    final end = _mediaForSlot(media, 'end_point');
    final startLocation = _locationOf(start);
    final endLocation = _locationOf(end);
    final hindranceId = report['hindranceId']?.toString().trim();
    final description = report['description']?.toString() ?? '';
    final iePhotoNeeded = report['ieAffected'] == true;
    final fieldData = <String, dynamic>{
      'surveyKind': 'HINDRANCE',
      if (hindranceId != null && hindranceId.isNotEmpty)
        'hindranceId': hindranceId,
      'currentStep': 1,
      'remarks': description,
      'proposedHindrance': {
        if (hindranceId != null && hindranceId.isNotEmpty)
          'hindranceId': hindranceId,
        if (report['hindranceType'] != null)
          'hindranceType': report['hindranceType'],
        if (report['subHindranceType'] != null)
          'subHindranceType': report['subHindranceType'],
        'description': description,
        'status': 'OPEN',
        if (startLocation['latitude'] != null)
          'latitude': startLocation['latitude'],
        if (startLocation['longitude'] != null)
          'longitude': startLocation['longitude'],
        if (startLocation['latitude'] != null)
          'sLatitude': startLocation['latitude'],
        if (startLocation['longitude'] != null)
          'sLongitude': startLocation['longitude'],
        if (endLocation['latitude'] != null)
          'eLatitude': endLocation['latitude'],
        if (endLocation['longitude'] != null)
          'eLongitude': endLocation['longitude'],
        if (uploaded['startPhoto'] != null)
          'startPhoto': uploaded['startPhoto'],
        if (uploaded['endPhoto'] != null) 'endPhoto': uploaded['endPhoto'],
        if (uploaded['walkthroughVideo'] != null)
          'walkthroughVideo': uploaded['walkthroughVideo'],
        'photos': uploaded['photos'],
        'additionalPhotos': uploaded['additionalPhotos'],
        'additionalVideos': uploaded['additionalVideos'],
        'ieName': report['ieName']?.toString() ?? '',
        'iePhoneNumber': report['iePhone']?.toString() ?? '',
        'iePhotoNeeded': iePhotoNeeded,
        if (uploaded['iePhoto'] != null) 'iePhoto': uploaded['iePhoto'],
        'shpFiles': uploaded['shpFiles'],
        'remarks': description,
      },
    };
    final body = {
      'taskId': mergedTaskId,
      'fieldData': fieldData,
      'attachmentKeys': const <String>[],
    };
    await onBeforeSave?.call();
    await _api.post(
      '${AppConstants.ilyncApiBaseUrl}/api/tasks/save',
      body: body,
    );
    await onBeforeSubmit?.call();
    final submitted = await _api.post(
      '${AppConstants.ilyncApiBaseUrl}/api/tasks/submit',
      body: body,
    );
    _validateSubmitStatus(submitted);
    final submittedId = _nestedMap(submitted, 'data')?['id']?.toString();
    if (submittedId == null || submittedId.isEmpty) {
      throw StateError(
        'Hindrance was submitted, but the task service did not return the submission ID.',
      );
    }
    return submittedId;
  }

  Future<Map<String, dynamic>> _uploadHindranceEvidence(
    String taskId,
    List<Map<String, dynamic>> media,
    List<Map> shpFiles, {
    Future<void> Function()? onUploadProgress,
    Future<void> Function(int bytesSent)? onUploadBytes,
  }) async {
    final result = <String, dynamic>{
      'photos': <Map<String, dynamic>>[],
      'additionalPhotos': <Map<String, dynamic>>[],
      'additionalVideos': <Map<String, dynamic>>[],
      'shpFiles': <String>[],
    };
    var index = 0;
    Future<void> uploadMedia(Map<String, dynamic> item) async {
      final kind = item['kind']?.toString();
      if (kind != 'photo' && kind != 'video') return;
      final slot = item['slot']?.toString() ?? '';
      final mime = _contentType(item);
      var key = item['uploadKey']?.toString() ?? '';
      if (key.isEmpty) {
        key = await _uploadFile(
          taskId: taskId,
          field: 'hindrance-${slot.isEmpty ? 'evidence' : slot}-${++index}',
          contentType: mime,
          bytes: await _requiredBytes(item, 'Hindrance evidence'),
          onBytesSent: onUploadBytes,
          endpoint: kind == 'video'
              ? '/api/survey/v2/video-upload-url'
              : '/api/survey/v2/photo-upload-url',
          keyName: kind == 'video' ? 'videoKey' : 'photoKey',
        );
        item['uploadKey'] = key;
        item['syncState'] = 'UPLOADED';
        await onUploadProgress?.call();
      }
      final photo = _mediaPayload(item, key, _displayLabel(slot));
      switch (slot) {
        case 'start_point':
          result['startPhoto'] = photo;
          (result['photos'] as List<Map<String, dynamic>>).add(photo);
        case 'end_point':
          result['endPhoto'] = photo;
          (result['photos'] as List<Map<String, dynamic>>).add(photo);
        case 'walkthrough':
          result['walkthroughVideo'] = photo;
        case 'additional_photo':
          (result['additionalPhotos'] as List<Map<String, dynamic>>).add(photo);
        case 'additional_video':
          (result['additionalVideos'] as List<Map<String, dynamic>>).add(photo);
        case 'ie_photo':
          result['iePhoto'] = photo;
        default:
          if (kind == 'photo') {
            (result['photos'] as List<Map<String, dynamic>>).add(photo);
          } else {
            (result['additionalVideos'] as List<Map<String, dynamic>>).add(
              photo,
            );
          }
      }
    }

    // Upload all photos first. The report payload is sent only after every
    // photo, SHP file, and video has a confirmed S3 key.
    for (final item in media.where((item) => item['kind'] == 'photo')) {
      await uploadMedia(item);
    }
    for (final file in shpFiles) {
      final name = file['name']?.toString() ?? 'shp-file';
      var key = file['uploadKey']?.toString() ?? '';
      if (key.isEmpty) {
        key = await _uploadFile(
          taskId: taskId,
          field: 'hindrance-shp-${++index}',
          contentType: 'application/octet-stream',
          bytes: await _requiredBytes(file, 'SHP component $name'),
          onBytesSent: onUploadBytes,
          endpoint: '/api/survey/v2/photo-upload-url',
          keyName: 'photoKey',
        );
        file['uploadKey'] = key;
        file['syncState'] = 'UPLOADED';
        await onUploadProgress?.call();
      }
      (result['shpFiles'] as List<String>).add(key);
    }
    for (final item in media.where((item) => item['kind'] == 'video')) {
      await uploadMedia(item);
    }
    return result;
  }

  Future<String> _uploadFile({
    required String taskId,
    required String field,
    required String contentType,
    required List<int> bytes,
    required String endpoint,
    required String keyName,
    Future<void> Function(int bytesSent)? onBytesSent,
  }) async {
    final upload = await _api.get(
      '$endpoint?taskId=${Uri.encodeQueryComponent(taskId)}&'
      'field=${Uri.encodeQueryComponent(field)}&'
      'contentType=${Uri.encodeQueryComponent(contentType)}',
    );
    final data = _nestedMap(upload, 'data') ?? <String, dynamic>{};
    final url = data['uploadUrl']?.toString();
    final key = data[keyName]?.toString();
    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      throw StateError('Upload service returned an incomplete URL for $field.');
    }
    await _api.putRawBytes(
      url,
      bytes,
      contentType: contentType,
      onBytesSent: onBytesSent,
    );
    return key;
  }

  Future<List<int>> _requiredBytes(Map item, String label) async {
    final bytes = await _readMedia(item);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Saved $label could not be read from this device.');
    }
    return bytes;
  }

  Map<String, dynamic>? _mediaForSlot(
    List<Map<String, dynamic>> media,
    String slot,
  ) => media.where((item) => item['slot'] == slot).firstOrNull;

  Map<String, dynamic> _locationOf(Map<String, dynamic>? media) {
    final location = media?['location'];
    return location is Map ? Map<String, dynamic>.from(location) : {};
  }

  Map<String, dynamic> _mediaPayload(
    Map<String, dynamic> item,
    String key,
    String label,
  ) {
    final location = _locationOf(item);
    final capturedAt = DateTime.tryParse(
      location['capturedAt']?.toString() ?? '',
    );
    return {
      'label': label,
      'photoUrl': key,
      'remarks': location['remarks']?.toString() ?? label,
      if (capturedAt != null) 'capturedAt': capturedAt.millisecondsSinceEpoch,
      if (location['latitude'] != null) 'latitude': location['latitude'],
      if (location['longitude'] != null) 'longitude': location['longitude'],
    };
  }

  String _displayLabel(String slot) => switch (slot) {
    'start_point' => 'Start Photo',
    'end_point' => 'End Photo',
    'walkthrough' => 'Walkthrough Video',
    'additional_photo' => 'Additional Photo',
    'additional_video' => 'Additional Video',
    'ie_photo' => 'IE Photo',
    _ => slot.isEmpty ? 'Hindrance Evidence' : slot,
  };

  String _contentType(Map item) {
    final path = item['path']?.toString() ?? item['filename']?.toString() ?? '';
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'webm' => 'video/webm',
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => item['kind'] == 'video' ? 'video/mp4' : 'image/jpeg',
    };
  }

  Future<List<Map<String, dynamic>>> _uploadPhotos(
    String taskId,
    List<dynamic> media, {
    required String fieldPrefix,
    Future<void> Function(int bytesSent)? onUploadBytes,
  }) async {
    final photos = <Map<String, dynamic>>[];
    for (final item in media) {
      if (item is! Map ||
          (item['kind'] != 'photo' && item['kind'] != 'video')) {
        continue;
      }
      final bytes = await _readMedia(item);
      if (bytes == null) {
        throw StateError('A saved $fieldPrefix evidence file could not be read.');
      }
      final contentType = _contentType(item);
      final upload = await _api.get(
        '/api/survey/photo-upload-url?'
        'taskId=${Uri.encodeQueryComponent(taskId)}&'
        'field=${Uri.encodeQueryComponent('$fieldPrefix-${item['slot'] ?? photos.length + 1}')}'
        '&contentType=${Uri.encodeQueryComponent(contentType)}',
      );
      final uploadData = _nestedMap(upload, 'data') ?? <String, dynamic>{};
      final uploadUrl = uploadData['uploadUrl']?.toString();
      final photoKey = uploadData['photoKey']?.toString();
      if (uploadUrl == null || photoKey == null) {
        throw StateError('Photo service returned an incomplete upload URL.');
      }
      await _api.putRawBytes(
        uploadUrl,
        bytes,
        contentType: contentType,
        onBytesSent: onUploadBytes,
      );
      final location = item['location'] is Map
          ? Map<String, dynamic>.from(item['location'] as Map)
          : <String, dynamic>{};
      final capturedAt = DateTime.tryParse(
        location['capturedAt']?.toString() ?? '',
      );
      photos.add({
        'label': item['slot']?.toString() ?? '$fieldPrefix photo',
        'photoUrl': photoKey,
        if (capturedAt != null) 'capturedAt': capturedAt.millisecondsSinceEpoch,
        if (location['latitude'] != null) 'latitude': location['latitude'],
        if (location['longitude'] != null) 'longitude': location['longitude'],
      });
    }
    return photos;
  }

  void _validateSubmitStatus(dynamic response) {
    final data =
        _nestedMap(response, 'data') ??
        (response is Map ? Map<String, dynamic>.from(response) : null);
    final status = data?['status']?.toString().toUpperCase();
    if (status != null && status.isNotEmpty && status != 'UNDER_REVIEW') {
      throw StateError(
        'The server accepted the submit request but returned status $status instead of UNDER_REVIEW.',
      );
    }
  }

  Future<Map<String, dynamic>> _fetchPlanRoutes(
    String planId, {
    String? revisionNo,
  }) async {
    final revisionQuery = revisionNo == null
        ? ''
        : '?source=BOQ_IMPORT&revisionNo=${Uri.encodeQueryComponent(revisionNo)}';
    final response = await _api.get(
      '${AppConstants.ilyncApiBaseUrl}/geo/api/boq/routes/by-block/'
      '${Uri.encodeComponent(planId)}$revisionQuery',
    );
    final data = _nestedMap(response, 'data');
    if (response is! Map || response['success'] != true || data == null) {
      throw StateError('Dev did not return the approved BoQ route data.');
    }
    final responsePlanId = data['planId']?.toString();
    if (responsePlanId != null && responsePlanId != planId) {
      throw StateError('Dev returned route data for a different BoQ plan.');
    }
    return data;
  }

  Map<String, dynamic>? _matchRoute(
    TaskModel ring,
    List<Map<String, dynamic>> routes,
  ) {
    String normalize(String value) =>
        value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final candidates = <String>{
      ring.displayName,
      ring.taskCode,
      ring.routeSnapshot?.routeCode ?? '',
      ring.routeSnapshot?.routeName ?? '',
    }.where((value) => value.trim().isNotEmpty).map(normalize).toSet();
    final matches = routes.where((route) {
      final routeValues = <String>{
        route['routeName']?.toString() ?? '',
        route['routeCode']?.toString() ?? '',
      }.map(normalize);
      return routeValues.any(candidates.contains);
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }

  String? _findMetaValue(Map<String, dynamic>? data, Set<String> keys) {
    if (data == null) return null;
    for (final entry in data.entries) {
      if (keys.contains(entry.key) && entry.value != null) {
        return entry.value.toString();
      }
    }
    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        final found = _findMetaValue(value, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  Map<String, dynamic>? _nestedMap(dynamic response, String key) {
    if (response is Map<String, dynamic> && response[key] is Map) {
      return Map<String, dynamic>.from(response[key] as Map);
    }
    return null;
  }

  Future<Map<String, String>> _findApprovedBoq(
    String blockId,
    String? preferredPlanId,
  ) async {
    final plansResponse = await _api.get(
      '${AppConstants.ilyncApiBaseUrl}/geo/api/boq/plans?'
      'blockId=${Uri.encodeQueryComponent(blockId)}&size=50',
    );
    final plansData = _nestedMap(plansResponse, 'data') ?? <String, dynamic>{};
    final plans = (plansData['content'] as List? ?? const [])
        .whereType<Map>()
        .map((plan) => Map<String, dynamic>.from(plan))
        .where((plan) => plan['id'] != null || plan['planId'] != null)
        .toList();
    if (plans.isEmpty) {
      throw StateError(
        'The selected Block has no BoQ plans in Dev. An approved BoQ plan is required to create the Hindrance task.',
      );
    }

    final approvedByPlan = await Future.wait(
      plans.map((plan) async {
        final planId = (plan['id'] ?? plan['planId']).toString();
        final response = await _api.get(
          '${AppConstants.ilyncApiBaseUrl}/geo/api/boq/plans/'
          '${Uri.encodeComponent(planId)}/revisions',
        );
        final data = response is Map ? response['data'] : null;
        final revisions =
            (data is Map
                    ? (data['content'] as List? ??
                          data['revisions'] as List? ??
                          const [])
                    : data is List
                    ? data
                    : const <dynamic>[])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where(
                  (item) =>
                      item['status']?.toString().toUpperCase() == 'APPROVED',
                )
                .toList();
        revisions.sort(
          (a, b) => (int.tryParse(b['revisionNo']?.toString() ?? '') ?? -1)
              .compareTo(int.tryParse(a['revisionNo']?.toString() ?? '') ?? -1),
        );
        if (revisions.isEmpty) return null;
        final revisionNo = int.tryParse(
          revisions.first['revisionNo']?.toString() ?? '',
        );
        if (revisionNo == null) return null;
        return <String, String>{
          'planId': planId,
          'revisionNo': revisionNo.toString(),
        };
      }),
    );
    final approved = approvedByPlan.whereType<Map<String, String>>().toList();
    if (preferredPlanId != null) {
      for (final plan in approved) {
        if (plan['planId'] == preferredPlanId) return plan;
      }
    }
    if (approved.length == 1) return approved.single;
    if (approved.isEmpty) {
      throw StateError(
        'The selected Block has no approved BoQ revision in Dev. Approve a BoQ revision before creating the Hindrance task.',
      );
    }
    throw StateError(
      'The selected Block has multiple approved BoQ plans. Choose the intended plan before creating the Hindrance task.',
    );
  }

  Future<List<int>?> _readMedia(Map item) async {
    final path = item['path']?.toString();
    if (item['storage'] == 'indexeddb' && item['mediaId'] != null) {
      return _store.loadMediaBytes(item['mediaId'].toString());
    }
    if (item['storage'] == 'database' && item['mediaId'] != null) {
      return _store.loadMediaBytes(item['mediaId'].toString());
    }
    if (path == null || path.isEmpty || kIsWeb) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

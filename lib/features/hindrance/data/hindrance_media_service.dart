import 'dart:io';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'hindrance_local_store.dart';
import 'hindrance_storage_platform.dart';
import 'hindrance_video_duration.dart';

class CapturedLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };
}

/// Captures geotagged media and moves it out of picker cache into app storage.
/// Video is preserved byte-for-byte; no lossy transcode or unverified compressor
/// is used while the server's media constraints are still unknown.
class HindranceMediaService {
  HindranceMediaService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static const _uuid = Uuid();
  static const _evidenceChannel = MethodChannel(
    'com.infocrats.hero/evidence_export',
  );

  Future<CapturedLocation> getFreshLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on device location to capture geotagged evidence.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for evidence capture.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.isMocked) {
      throw Exception(
        'The device reported a mock location. Evidence was not captured.',
      );
    }
    return CapturedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  Future<Map<String, dynamic>?> capturePhoto({
    required String ownerId,
    required String reportId,
    required String slot,
    String recordType = 'HINDRANCE',
    DateTime? createdAt,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final photoCapturedAt = DateTime.now().toUtc();
    final location = await getFreshLocation();
    final photoLocation = CapturedLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: location.accuracyMeters,
      capturedAt: photoCapturedAt,
    );
    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('The captured photo could not be decoded.');
    }

    final overlay = [
      'LAT ${photoLocation.latitude.toStringAsFixed(6)}  LNG ${photoLocation.longitude.toStringAsFixed(6)}',
      'DATE/TIME ${photoLocation.capturedAt.toIso8601String()}',
      'GPS ACCURACY ${photoLocation.accuracyMeters.toStringAsFixed(0)} M',
    ];
    final lineHeight = 34;
    final overlayHeight = (lineHeight * overlay.length) + 24;
    final y = decoded.height - overlayHeight;
    img.fillRect(
      decoded,
      x1: 0,
      y1: y < 0 ? 0 : y,
      x2: decoded.width - 1,
      y2: decoded.height - 1,
      color: img.ColorRgba8(0, 0, 0, 190),
    );
    for (var i = 0; i < overlay.length; i++) {
      img.drawString(
        decoded,
        overlay[i],
        font: img.arial24,
        x: 18,
        y: (y < 0 ? 0 : y) + 12 + (i * lineHeight),
        color: img.ColorRgb8(255, 255, 255),
      );
    }

    final filename = '${slot}_${_uuid.v4()}.jpg';
    final outputBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
    final mediaId = _uuid.v4();
    String path;
    if (kIsWeb) {
      await HindranceLocalStore.instance.saveMediaBytes(
        mediaId: mediaId,
        ownerId: ownerId,
        reportId: reportId,
        filename: filename,
        bytes: outputBytes,
      );
      path = 'indexeddb:$mediaId';
    } else {
      final directory = await _mediaDirectory(ownerId, reportId);
      final output = File('${directory.path}/$filename');
      await output.writeAsBytes(outputBytes, flush: true);
      path = output.path;
    }
    final publicCopy = kIsWeb
        ? null
        : await _exportFile(
            sourcePath: path,
            filename: filename,
            mimeType: 'image/jpeg',
            recordType: recordType,
            reportId: reportId,
            createdAt: createdAt,
          );
    final record = _mediaRecord(
      mediaId: mediaId,
      ownerId: ownerId,
      reportId: reportId,
      path: path,
      kind: 'photo',
      slot: slot,
      location: photoLocation,
      storage: kIsWeb ? 'indexeddb' : 'file',
    );
    record['filename'] = filename;
    record['sizeBytes'] = outputBytes.length;
    if (publicCopy != null) record.addAll(publicCopy);
    return record;
  }

  Future<Map<String, dynamic>?> captureVideo({
    required String ownerId,
    required String reportId,
    required String slot,
    required Duration maxDuration,
    String recordType = 'HINDRANCE',
    DateTime? createdAt,
  }) async {
    final location = await getFreshLocation();
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration,
    );
    if (picked == null) return null;
    final Uint8List? webBytes = kIsWeb ? await picked.readAsBytes() : null;
    Duration? recordedDuration;
    if (webBytes != null) {
      recordedDuration = await readHindranceVideoDuration(webBytes);
      if (recordedDuration == null) {
        throw Exception(
          'Could not verify this video duration in the browser. Choose a supported video file and try again.',
        );
      }
      if (recordedDuration > maxDuration) {
        throw Exception(
          'This video is longer than ${maxDuration.inMinutes} minutes. Choose a shorter video.',
        );
      }
    }
    final mimeType = picked.mimeType?.toLowerCase() ?? '';
    final extension = kIsWeb
        ? (mimeType.contains('webm') ? '.webm' : '.mp4')
        : picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.mp4';
    final mediaId = _uuid.v4();
    final filename = '${slot}_$mediaId$extension';
    String path;
    if (kIsWeb) {
      await HindranceLocalStore.instance.saveMediaBytes(
        mediaId: mediaId,
        ownerId: ownerId,
        reportId: reportId,
        filename: filename,
        bytes: webBytes!,
      );
      path = 'indexeddb:$mediaId';
    } else {
      final directory = await _mediaDirectory(ownerId, reportId);
      final output = File('${directory.path}/$filename');
      await File(picked.path).copy(output.path);
      path = output.path;
    }
    final publicCopy = kIsWeb
        ? null
        : await _exportFile(
            sourcePath: path,
            filename: filename,
            mimeType: extension == '.webm' ? 'video/webm' : 'video/mp4',
            recordType: recordType,
            reportId: reportId,
            createdAt: createdAt,
          );
    final record = _mediaRecord(
      mediaId: mediaId,
      ownerId: ownerId,
      reportId: reportId,
      path: path,
      kind: 'video',
      slot: slot,
      location: location,
      durationLimitSeconds: maxDuration.inSeconds,
      compression: 'original_preserved_no_transcode',
      storage: kIsWeb ? 'indexeddb' : 'file',
    );
    if (recordedDuration != null) {
      record['durationSeconds'] = recordedDuration.inSeconds;
    }
    record['sizeBytes'] = kIsWeb ? webBytes!.length : await File(path).length();
    if (publicCopy != null) record.addAll(publicCopy);
    return record;
  }

  Future<Map<String, dynamic>> storeRecordedVideo({
    required XFile picked,
    required CapturedLocation location,
    required String ownerId,
    required String reportId,
    required String slot,
    required Duration duration,
    required Duration maxDuration,
    String recordType = 'CCN',
    DateTime? createdAt,
  }) async {
    if (duration > maxDuration) {
      throw Exception(
        'The recording exceeded the ${maxDuration.inMinutes} minute limit.',
      );
    }
    final mediaId = _uuid.v4();
    final mimeType = picked.mimeType?.toLowerCase() ?? '';
    final extension = kIsWeb
        ? (mimeType.contains('webm') ? '.webm' : '.mp4')
        : picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.mp4';
    final filename = '${slot}_$mediaId$extension';
    String path;
    final Uint8List? bytes = kIsWeb ? await picked.readAsBytes() : null;
    if (bytes != null) {
      final metadataDuration = await readHindranceVideoDuration(bytes);
      if (metadataDuration == null || metadataDuration > maxDuration) {
        throw Exception(
          'The browser video duration could not be confirmed within the limit.',
        );
      }
      await HindranceLocalStore.instance.saveMediaBytes(
        mediaId: mediaId,
        ownerId: ownerId,
        reportId: reportId,
        filename: filename,
        bytes: bytes,
      );
      path = 'indexeddb:$mediaId';
    } else {
      final directory = await _mediaDirectory(ownerId, reportId);
      final output = File('${directory.path}/$filename');
      await File(picked.path).copy(output.path);
      path = output.path;
    }
    final publicCopy = kIsWeb
        ? null
        : await _exportFile(
            sourcePath: path,
            filename: filename,
            mimeType: extension == '.webm' ? 'video/webm' : 'video/mp4',
            recordType: recordType,
            reportId: reportId,
            createdAt: createdAt,
          );
    final record = _mediaRecord(
      mediaId: mediaId,
      ownerId: ownerId,
      reportId: reportId,
      path: path,
      kind: 'video',
      slot: slot,
      location: location,
      durationLimitSeconds: maxDuration.inSeconds,
      compression: 'camera_capture_preserved_no_transcode',
      storage: kIsWeb ? 'indexeddb' : 'file',
    );
    record['filename'] = filename;
    record['durationSeconds'] = duration.inSeconds;
    record['sizeBytes'] = bytes?.length ?? await File(path).length();
    if (publicCopy != null) record.addAll(publicCopy);
    return record;
  }

  Future<Map<String, dynamic>> storePickedBytes({
    required String ownerId,
    required String reportId,
    required String filename,
    required String kind,
    required Uint8List bytes,
    String recordType = 'CCN',
    DateTime? createdAt,
  }) async {
    final mediaId = _uuid.v4();
    await HindranceLocalStore.instance.saveMediaBytes(
      mediaId: mediaId,
      ownerId: ownerId,
      reportId: reportId,
      filename: filename,
      bytes: bytes,
    );
    final record = <String, dynamic>{
      'mediaId': mediaId,
      'ownerId': ownerId,
      'reportId': reportId,
      'kind': kind,
      'path': 'indexeddb:$mediaId',
      'filename': filename,
      'sizeBytes': bytes.length,
      'storage': kIsWeb ? 'indexeddb' : 'database',
      'syncState': 'LOCAL_SAVED',
    };
    final extension = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.') + 1).toLowerCase()
        : '';
    final mimeType = switch (extension) {
      'kml' => 'application/vnd.google-earth.kml+xml',
      'shp' => 'application/octet-stream',
      _ => 'application/octet-stream',
    };
    final publicCopy = await _exportBytes(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      recordType: recordType,
      reportId: reportId,
      createdAt: createdAt,
    );
    if (publicCopy != null) record.addAll(publicCopy);
    return record;
  }

  Future<Map<String, dynamic>?> _exportFile({
    required String sourcePath,
    required String filename,
    required String mimeType,
    required String recordType,
    required String reportId,
    DateTime? createdAt,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final relativePath = _publicRelativePath(recordType, reportId, createdAt);
    try {
      final result = await _evidenceChannel
          .invokeMapMethod<String, dynamic>('exportFile', {
            'sourcePath': sourcePath,
            'relativePath': relativePath,
            'fileName': filename,
            'mimeType': mimeType,
          });
      return {
        'fileManagerUri': result?['uri'],
        'fileManagerFolder': 'Download/$relativePath',
      };
    } catch (error) {
      return {
        'fileManagerFolder': 'Download/$relativePath',
        'fileManagerExportError': error.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> _exportBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String recordType,
    required String reportId,
    DateTime? createdAt,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final relativePath = _publicRelativePath(recordType, reportId, createdAt);
    try {
      final result = await _evidenceChannel
          .invokeMapMethod<String, dynamic>('exportBytes', {
            'bytes': bytes,
            'relativePath': relativePath,
            'fileName': filename,
            'mimeType': mimeType,
          });
      return {
        'fileManagerUri': result?['uri'],
        'fileManagerFolder': 'Download/$relativePath',
      };
    } catch (error) {
      return {
        'fileManagerFolder': 'Download/$relativePath',
        'fileManagerExportError': error.toString(),
      };
    }
  }

  String _publicRelativePath(
    String recordType,
    String reportId,
    DateTime? createdAt,
  ) {
    final safeType = switch (recordType.trim().toUpperCase()) {
      'CCN' => 'CCN',
      'OTN' => 'OTN',
      _ => 'Hindrance',
    };
    final date = (createdAt ?? DateTime.now()).toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final timeFolder =
        '${date.year}${twoDigits(date.month)}${twoDigits(date.day)}_${twoDigits(date.hour)}${twoDigits(date.minute)}${twoDigits(date.second)}';
    final cleanId = reportId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final safeId = cleanId.substring(
      0,
      cleanId.length < 8 ? cleanId.length : 8,
    );
    return 'HERO APP/$safeType/${timeFolder}_${safeId.isEmpty ? 'report' : safeId}';
  }

  Future<void> deleteFileManagerCopy(Map<dynamic, dynamic> record) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final uri = record['fileManagerUri']?.toString();
    if (uri == null || uri.isEmpty) return;
    try {
      await _evidenceChannel.invokeMethod<bool>('deleteExport', {'uri': uri});
    } catch (_) {
      // App-private deletion must still proceed if public deletion is denied.
    }
  }

  Future<File> storePickedFile({
    required String ownerId,
    required String reportId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final directory = await _mediaDirectory(ownerId, reportId);
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final output = File('${directory.path}/${_uuid.v4()}_$safeName');
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Future<File> storePickedStream({
    required String ownerId,
    required String reportId,
    required String filename,
    required Stream<List<int>> stream,
  }) async {
    final directory = await _mediaDirectory(ownerId, reportId);
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final output = File('${directory.path}/${_uuid.v4()}_$safeName');
    final sink = output.openWrite();
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return output;
    } catch (_) {
      await sink.close();
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  Future<Directory> _mediaDirectory(String ownerId, String reportId) async {
    final path = await prepareHindranceMediaDirectory(
      ownerId: ownerId,
      reportId: reportId,
    );
    return Directory(path);
  }

  Map<String, dynamic> _mediaRecord({
    required String ownerId,
    required String reportId,
    required String path,
    required String kind,
    required String slot,
    required CapturedLocation location,
    int? durationLimitSeconds,
    String? compression,
    String? storage,
    String? mediaId,
  }) => {
    'mediaId': mediaId ?? _uuid.v4(),
    'ownerId': ownerId,
    'reportId': reportId,
    'kind': kind,
    'slot': slot,
    'path': path,
    'storage': storage ?? 'file',
    'location': location.toJson(),
    'durationLimitSeconds': ?durationLimitSeconds,
    'videoHandling': ?compression,
    'syncState': 'LOCAL_SAVED',
  };
}

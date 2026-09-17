import 'dart:convert';
import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_model.dart';

/// Local Storage Service persisting Attendance Records and Photos locally with Web safety
class AttendanceStorageService {
  static final AttendanceStorageService _instance = AttendanceStorageService._internal();
  factory AttendanceStorageService() => _instance;
  AttendanceStorageService._internal();

  // In-memory cache fallback for web or when file storage is unavailable
  List<AttendanceModel>? _memoryRecords;

  Directory? _documentsDir;

  static List<AttendanceModel> _getInitialSeedRecords() {
    return [];
  }

  Future<Directory?> _getAppDir() async {
    if (kIsWeb) return null;
    if (_documentsDir != null) return _documentsDir;
    try {
      _documentsDir = await getApplicationDocumentsDirectory();
      return _documentsDir;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceStorageService] Documents dir error: $e');
      }
      return null;
    }
  }

  Future<File?> _getRecordsFile() async {
    final dir = await _getAppDir();
    if (dir == null) return null;
    return File('${dir.path}/attendance_records.json');
  }

  Future<Directory?> _getImagesDir() async {
    final dir = await _getAppDir();
    if (dir == null) return null;
    final imgDir = Directory('${dir.path}/attendance/images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir;
  }

  /// Save photo bytes locally and return the local file path or data URL
  Future<String> savePhotoLocally({
    required String attendanceId,
    required List<int> photoBytes,
    String prefix = 'check_in',
  }) async {
    if (kIsWeb) {
      final base64Str = base64Encode(photoBytes);
      return 'data:image/jpeg;base64,$base64Str';
    }

    try {
      final imgDir = await _getImagesDir();
      if (imgDir != null) {
        final filePath = '${imgDir.path}/${prefix}_$attendanceId.jpg';
        final file = File(filePath);
        await file.writeAsBytes(photoBytes);
        if (kDebugMode) {
          print('[AttendanceStorageService] Photo saved locally at: $filePath');
        }
        return filePath;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceStorageService] Save photo error: $e');
      }
    }

    final base64Str = base64Encode(photoBytes);
    return 'data:image/jpeg;base64,$base64Str';
  }

  /// Load all saved attendance records
  Future<List<AttendanceModel>> getAllRecords() async {
    _memoryRecords ??= _getInitialSeedRecords();

    if (kIsWeb) {
      return List.from(_memoryRecords!);
    }

    try {
      final file = await _getRecordsFile();
      if (file == null || !await file.exists()) {
        return List.from(_memoryRecords!);
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return List.from(_memoryRecords!);

      final List<dynamic> jsonList = jsonDecode(content);
      final records = jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => AttendanceModel.fromJson(item))
          .toList();

      if (records.isEmpty) {
        return List.from(_memoryRecords!);
      }

      records.sort((a, b) {
        final aTime = a.checkInTime ?? a.createdAt ?? DateTime.now();
        final bTime = b.checkInTime ?? b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      return records;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceStorageService] Read records error: $e');
      }
      return List.from(_memoryRecords!);
    }
  }

  /// Get today's attendance record for user
  Future<AttendanceModel?> getTodayRecord(String userId) async {
    final all = await getAllRecords();
    final now = DateTime.now();
    for (final item in all) {
      final itemDate = item.checkInTime ?? item.createdAt;
      if (itemDate != null &&
          itemDate.year == now.year &&
          itemDate.month == now.month &&
          itemDate.day == now.day &&
          (userId.isEmpty || item.userId == userId || item.employeeId == userId)) {
        return item;
      }
    }
    return null;
  }

  /// Save or update an attendance record locally
  Future<void> saveRecord(AttendanceModel record) async {
    _memoryRecords ??= _getInitialSeedRecords();

    final index = _memoryRecords!.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      _memoryRecords![index] = record;
    } else {
      _memoryRecords!.insert(0, record);
    }

    if (kIsWeb) return;

    try {
      final file = await _getRecordsFile();
      if (file != null) {
        final all = await getAllRecords();
        final jsonList = all.map((r) => r.toJson()).toList();
        await file.writeAsString(jsonEncode(jsonList));
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceStorageService] Save record error: $e');
      }
    }
  }

  /// Clear records
  Future<void> clearAll() async {
    _memoryRecords = _getInitialSeedRecords();
    if (kIsWeb) return;
    try {
      final file = await _getRecordsFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Clear all stored attendance records for testing
  Future<void> clearAllRecords() async {
    _memoryRecords = [];
    if (kIsWeb) return;
    try {
      final file = await _getRecordsFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

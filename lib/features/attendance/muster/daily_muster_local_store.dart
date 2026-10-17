import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, user-scoped backup for a partially completed daily muster.
class DailyMusterLocalStore {
  String _key(String ownerId, String taskId) =>
      'daily_muster_${ownerId}_$taskId';

  Future<Map<String, dynamic>?> read(String ownerId, String taskId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _key(ownerId, taskId),
    );
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String ownerId,
    String taskId,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(ownerId, taskId), jsonEncode(value));
  }

  Future<void> remove(String ownerId, String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(ownerId, taskId));
  }

  Future<String> persistPhoto(
    String sourcePath,
    String taskId,
    String slot,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/daily_muster/$taskId');
    await directory.create(recursive: true);
    final target =
        '${directory.path}/${slot}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    return (await File(sourcePath).copy(target)).path;
  }
}

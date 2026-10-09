import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<String> prepareHindranceDatabasePath() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  return '${await getDatabasesPath()}/hindrance_offline.db';
}

Future<String> prepareHindranceMediaDirectory({
  required String ownerId,
  required String reportId,
}) async {
  final root = await getDatabasesPath();
  final safeOwnerId = ownerId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final safeReportId = reportId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final directory = Directory('$root/hindrance/$safeOwnerId/$safeReportId');
  await directory.create(recursive: true);
  return directory.path;
}

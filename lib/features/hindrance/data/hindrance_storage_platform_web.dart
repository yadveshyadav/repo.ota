import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<String> prepareHindranceDatabasePath() async {
  sqflite.databaseFactory = databaseFactoryFfiWeb;
  // The Web factory persists this database name in IndexedDB.
  return 'hindrance_offline.db';
}

Future<String> prepareHindranceMediaDirectory({
  required String ownerId,
  required String reportId,
}) async => throw UnsupportedError(
  'Photo, video, and SHP evidence capture is available in the Android/iOS app.',
);

import 'hindrance_storage_platform_stub.dart'
    if (dart.library.io) 'hindrance_storage_platform_io.dart'
    if (dart.library.js_interop) 'hindrance_storage_platform_web.dart'
    as impl;

Future<String> prepareHindranceDatabasePath() =>
    impl.prepareHindranceDatabasePath();

Future<String> prepareHindranceMediaDirectory({
  required String ownerId,
  required String reportId,
}) => impl.prepareHindranceMediaDirectory(ownerId: ownerId, reportId: reportId);

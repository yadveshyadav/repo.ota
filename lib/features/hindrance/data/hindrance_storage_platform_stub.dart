Future<String> prepareHindranceDatabasePath() async => throw UnsupportedError(
  'Hindrance local storage is unavailable on this platform.',
);

Future<String> prepareHindranceMediaDirectory({
  required String ownerId,
  required String reportId,
}) async => throw UnsupportedError(
  'Hindrance evidence capture requires the mobile app.',
);

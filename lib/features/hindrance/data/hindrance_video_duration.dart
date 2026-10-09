import 'dart:typed_data';

import 'hindrance_video_duration_stub.dart'
    if (dart.library.html) 'hindrance_video_duration_web.dart'
    as impl;

Future<Duration?> readHindranceVideoDuration(Uint8List bytes) =>
    impl.readHindranceVideoDuration(bytes);

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Duration?> readHindranceVideoDuration(Uint8List bytes) async {
  final completer = Completer<Duration?>();
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final video = web.HTMLVideoElement()
    ..preload = 'metadata'
    ..src = url;
  video.onLoadedMetadata.listen((_) {
    if (!completer.isCompleted && video.duration.isFinite) {
      completer.complete(
        Duration(milliseconds: (video.duration * 1000).round()),
      );
    }
  });
  video.onError.listen((_) {
    if (!completer.isCompleted) completer.complete(null);
  });
  try {
    return await completer.future.timeout(const Duration(seconds: 20));
  } on TimeoutException {
    return null;
  } finally {
    video.src = '';
    web.URL.revokeObjectURL(url);
  }
}

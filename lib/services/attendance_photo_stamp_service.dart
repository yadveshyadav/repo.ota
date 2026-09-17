import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Burns a small GPS + phone proof stamp into the bottom-right of an attendance photo.
class AttendancePhotoStampService {
  /// Returns stamped JPEG/PNG bytes. Falls back to [imageBytes] if stamping fails.
  Future<Uint8List> stampProof({
    required Uint8List imageBytes,
    required double latitude,
    required double longitude,
    required String phoneNumber,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final source = frame.image;

      final width = source.width;
      final height = source.height;
      if (width <= 0 || height <= 0) {
        source.dispose();
        return imageBytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawImage(source, ui.Offset.zero, ui.Paint());

      final latLng =
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      final phone = phoneNumber.trim().isEmpty ? 'Phone: N/A' : phoneNumber.trim();
      final line1 = latLng;
      final line2 = phone;

      // Scale stamp with image size so it stays readable but compact.
      final fontSize = (width * 0.028).clamp(11.0, 22.0);
      final pad = (width * 0.018).clamp(8.0, 16.0);
      final radius = (width * 0.012).clamp(4.0, 10.0);

      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: ui.TextAlign.right,
          maxLines: 3,
        ),
      )
        ..pushStyle(
          ui.TextStyle(
            color: const ui.Color(0xFFFFFFFF),
            fontSize: fontSize,
            fontWeight: ui.FontWeight.w600,
            height: 1.25,
          ),
        )
        ..addText('$line1\n$line2');

      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: width * 0.62));

      final boxWidth = paragraph.maxIntrinsicWidth + pad * 2;
      final boxHeight = paragraph.height + pad * 2;
      final left = width - boxWidth - pad;
      final top = height - boxHeight - pad;

      final bgRect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(left, top, boxWidth, boxHeight),
        ui.Radius.circular(radius),
      );

      canvas.drawRRect(
        bgRect,
        ui.Paint()..color = const ui.Color(0xCC0B1F17),
      );
      canvas.drawRRect(
        bgRect,
        ui.Paint()
          ..color = const ui.Color(0x99FFFFFF)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      canvas.drawParagraph(
        paragraph,
        ui.Offset(left + pad, top + pad),
      );

      final picture = recorder.endRecording();
      final stamped = await picture.toImage(width, height);
      final byteData =
          await stamped.toByteData(format: ui.ImageByteFormat.png);

      source.dispose();
      stamped.dispose();
      picture.dispose();

      if (byteData == null) return imageBytes;
      return byteData.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) {
        print('[AttendancePhotoStampService] Stamp failed: $e');
      }
      return imageBytes;
    }
  }
}

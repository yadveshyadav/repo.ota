import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Result of attendance selfie face validation.
class FaceValidationResult {
  final bool isValid;
  final String? message;
  final int faceCount;

  const FaceValidationResult._({
    required this.isValid,
    this.message,
    this.faceCount = 0,
  });

  factory FaceValidationResult.valid({int faceCount = 1}) {
    return FaceValidationResult._(isValid: true, faceCount: faceCount);
  }

  factory FaceValidationResult.invalid(String message, {int faceCount = 0}) {
    return FaceValidationResult._(
      isValid: false,
      message: message,
      faceCount: faceCount,
    );
  }
}

/// Validates that an attendance selfie contains one clear, forward-facing face.
///
/// On iOS, camera JPEGs often store portrait orientation only in EXIF. ML Kit
/// does not apply that tag when loading from a file path, so faces appear
/// sideways and detection returns empty. We bake EXIF into pixel data first.
class AttendanceFaceDetectionService {
  FaceDetector? _detector;

  /// Max absolute head rotation (degrees) allowed for a usable selfie.
  static const double maxHeadYawDegrees = 35;
  static const double maxHeadPitchDegrees = 35;
  static const double maxHeadRollDegrees = 35;

  /// Face must cover at least this fraction of the shorter image side (post-check).
  static const double minFaceSizeRatio = 0.12;

  /// ML Kit early filter — keep loose; we enforce size ourselves after detection.
  static const double mlKitMinFaceSize = 0.1;

  FaceDetector get _faceDetector {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: mlKitMinFaceSize,
      ),
    );
  }

  /// Runs ML Kit face detection and applies attendance-specific quality rules.
  Future<FaceValidationResult> validateAttendanceSelfie(String imagePath) async {
    if (kIsWeb) {
      return FaceValidationResult.invalid(
        'Face verification is only available on mobile devices.',
      );
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      return FaceValidationResult.invalid(
        'Captured photo could not be read. Please retake your selfie.',
      );
    }

    File? normalizedFile;
    try {
      // Critical for iOS: bake EXIF orientation into pixels before ML Kit.
      normalizedFile = await _normalizeImageForMlKit(imagePath);
      final processPath = normalizedFile?.path ?? imagePath;

      var faces = await _faceDetector.processImage(
        InputImage.fromFilePath(processPath),
      );

      // If still empty (rare EXIF / crop edge cases), try rotated copies.
      if (faces.isEmpty) {
        faces = await _detectWithRotationFallbacks(processPath);
      }

      if (kDebugMode) {
        print(
          '[AttendanceFaceDetectionService] faces=${faces.length} '
          'path=$processPath platform=${Platform.operatingSystem}',
        );
      }

      if (faces.isEmpty) {
        return FaceValidationResult.invalid(
          'No face detected. Please look at the camera and capture a clear selfie of your face.',
        );
      }

      if (faces.length > 1) {
        return FaceValidationResult.invalid(
          'Multiple faces detected. Only one person should appear in the attendance photo.',
          faceCount: faces.length,
        );
      }

      final face = faces.first;
      final poseError = _validateHeadPose(face);
      if (poseError != null) {
        return FaceValidationResult.invalid(poseError, faceCount: 1);
      }

      final eyeError = _validateEyesOpen(face);
      if (eyeError != null) {
        return FaceValidationResult.invalid(eyeError, faceCount: 1);
      }

      final landmarkError = _validateLandmarks(face);
      if (landmarkError != null) {
        return FaceValidationResult.invalid(landmarkError, faceCount: 1);
      }

      final sizeError = await _validateFaceSize(processPath, face.boundingBox);
      if (sizeError != null) {
        return FaceValidationResult.invalid(sizeError, faceCount: 1);
      }

      return FaceValidationResult.valid(faceCount: 1);
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceFaceDetectionService] Validation error: $e');
      }
      final msg = e.toString().toLowerCase();
      if (msg.contains('simulator') ||
          msg.contains('arm64') ||
          msg.contains('missingplugin') ||
          msg.contains('not implemented')) {
        return FaceValidationResult.invalid(
          'Face detection is not available on this simulator. Please test team attendance face verification on a real iPhone.',
        );
      }
      return FaceValidationResult.invalid(
        'Unable to verify your face. Please retake a clear selfie with good lighting.',
      );
    } finally {
      try {
        await normalizedFile?.delete();
      } catch (_) {}
    }
  }

  /// Decodes the capture, applies EXIF orientation, writes upright JPEG for ML Kit.
  Future<File?> _normalizeImageForMlKit(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);

      // Cap long side so face detection stays fast on high-res iPhone photos.
      img.Image ready = oriented;
      const maxSide = 1280;
      if (ready.width > maxSide || ready.height > maxSide) {
        ready = ready.width >= ready.height
            ? img.copyResize(ready, width: maxSide)
            : img.copyResize(ready, height: maxSide);
      }

      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/face_norm_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(img.encodeJpg(ready, quality: 92));
      return out;
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceFaceDetectionService] normalize failed: $e');
      }
      return null;
    }
  }

  /// When EXIF bake still leaves an empty result, try 90° rotations.
  Future<List<Face>> _detectWithRotationFallbacks(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const [];

      for (final angle in [90, 180, 270]) {
        final rotated = img.copyRotate(decoded, angle: angle);
        final dir = await getTemporaryDirectory();
        final out = File(
          '${dir.path}/face_rot_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await out.writeAsBytes(img.encodeJpg(rotated, quality: 90));
        try {
          final faces = await _faceDetector.processImage(
            InputImage.fromFilePath(out.path),
          );
          if (faces.isNotEmpty) {
            if (kDebugMode) {
              print(
                '[AttendanceFaceDetectionService] faces found after $angle° rotate',
              );
            }
            return faces;
          }
        } finally {
          try {
            await out.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AttendanceFaceDetectionService] rotation fallback failed: $e');
      }
    }
    return const [];
  }

  String? _validateHeadPose(Face face) {
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    final roll = face.headEulerAngleZ;

    if (yaw != null && yaw.abs() > maxHeadYawDegrees) {
      return 'Please face the camera directly. Turn your head toward the camera and retake.';
    }
    if (pitch != null && pitch.abs() > maxHeadPitchDegrees) {
      return 'Please look straight at the camera. Avoid tilting your head up or down.';
    }
    if (roll != null && roll.abs() > maxHeadRollDegrees) {
      return 'Please keep your head upright while capturing the selfie.';
    }
    return null;
  }

  String? _validateEyesOpen(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    // Classification can be unavailable on some iOS paths — skip if null.
    if (left == null || right == null) return null;

    if (left < 0.15 && right < 0.15) {
      return 'Please keep your eyes open and look at the camera.';
    }
    return null;
  }

  String? _validateLandmarks(Face face) {
    final hasNose = face.landmarks[FaceLandmarkType.noseBase] != null;
    final hasLeftEye = face.landmarks[FaceLandmarkType.leftEye] != null;
    final hasRightEye = face.landmarks[FaceLandmarkType.rightEye] != null;

    // Require at least one reliable landmark set; don't fail if iOS omits some.
    if (!hasNose && !(hasLeftEye || hasRightEye)) {
      return 'Face is not clear enough. Move closer, improve lighting, and retake.';
    }
    return null;
  }

  /// Extra size check using decoded image dimensions (covers odd aspect ratios).
  Future<String?> _validateFaceSize(String imagePath, Rect boundingBox) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final shorterSide = image.width < image.height ? image.width : image.height;
      image.dispose();

      if (shorterSide <= 0) return null;

      final faceWidth = boundingBox.width.abs();
      final faceHeight = boundingBox.height.abs();
      final faceSpan = faceWidth > faceHeight ? faceWidth : faceHeight;
      final ratio = faceSpan / shorterSide;

      if (ratio < minFaceSizeRatio) {
        return 'Face is too small or too far. Move closer to the camera and retake.';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}

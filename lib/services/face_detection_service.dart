import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
class AttendanceFaceDetectionService {
  FaceDetector? _detector;

  /// Max absolute head rotation (degrees) allowed for a usable selfie.
  static const double maxHeadYawDegrees = 25;
  static const double maxHeadPitchDegrees = 25;
  static const double maxHeadRollDegrees = 25;

  /// Face must cover at least this fraction of the shorter image side.
  static const double minFaceSizeRatio = 0.18;

  FaceDetector get _faceDetector {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        performanceMode: FaceDetectorMode.accurate,
        // Ignore tiny / distant faces early in the ML pipeline.
        minFaceSize: minFaceSizeRatio,
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

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

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

      final sizeError = await _validateFaceSize(imagePath, face.boundingBox);
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
    }
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
    if (left == null || right == null) return null;

    // Both eyes clearly closed → likely not a live selfie check.
    if (left < 0.2 && right < 0.2) {
      return 'Please keep your eyes open and look at the camera.';
    }
    return null;
  }

  String? _validateLandmarks(Face face) {
    final hasNose = face.landmarks[FaceLandmarkType.noseBase] != null;
    final hasLeftEye = face.landmarks[FaceLandmarkType.leftEye] != null;
    final hasRightEye = face.landmarks[FaceLandmarkType.rightEye] != null;

    if (!hasNose && !(hasLeftEye && hasRightEye)) {
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
      // If size decode fails, rely on ML Kit minFaceSize + other checks.
      return null;
    }
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}

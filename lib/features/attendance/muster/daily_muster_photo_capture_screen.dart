import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../services/location_service.dart';

class MusterPhotoCapture {
  const MusterPhotoCapture({
    required this.path,
    required this.photoCapturedAt,
    required this.location,
  });
  final String path;
  final DateTime photoCapturedAt;
  final LocationResult location;
}

/// Live-camera-only capture; it never routes through the gallery picker.
class DailyMusterPhotoCaptureScreen extends StatefulWidget {
  const DailyMusterPhotoCaptureScreen({super.key, required this.title});
  final String title;

  @override
  State<DailyMusterPhotoCaptureScreen> createState() =>
      _DailyMusterPhotoCaptureScreenState();
}

class _DailyMusterPhotoCaptureScreenState
    extends State<DailyMusterPhotoCaptureScreen> {
  CameraController? _camera;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final camera = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera could not start: $e');
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final capturedAt = DateTime.now().toUtc();
      // Start the GPS fix and shutter action together so neither operation
      // needlessly makes the evidence timestamp stale.
      final imageFuture = camera.takePicture();
      final locationFuture = AppLocationService.instance
          .getAccurateLocationForAttendance();
      final image = await imageFuture;
      final location = await locationFuture;
      if (!mounted) return;
      Navigator.of(context).pop(
        MusterPhotoCapture(
          path: image.path,
          photoCapturedAt: capturedAt,
          location: location,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Photo/GPS capture failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      )
                    : camera == null || !camera.value.isInitialized
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: camera.value.aspectRatio,
                        child: CameraPreview(camera),
                      ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Capture a live photo at the work location. GPS is recorded immediately after capture.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || camera == null ? null : _capture,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_busy ? 'Capturing…' : 'Take Photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

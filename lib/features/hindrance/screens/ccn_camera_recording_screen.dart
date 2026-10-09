import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hero_app/core/theme/app_colors.dart';

class RecordedCcnVideo {
  const RecordedCcnVideo({required this.file, required this.duration});

  final XFile file;
  final Duration duration;
}

/// Records in-app so the parent screen can keep the GPS trace active alongside
/// the camera. The recording is returned as captured; it is not transcoded.
class CcnCameraRecordingScreen extends StatefulWidget {
  const CcnCameraRecordingScreen({super.key, required this.maxDuration});

  final Duration maxDuration;

  @override
  State<CcnCameraRecordingScreen> createState() =>
      _CcnCameraRecordingScreenState();
}

class _CcnCameraRecordingScreenState extends State<CcnCameraRecordingScreen> {
  CameraController? _controller;
  Timer? _ticker;
  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  String? _error;
  bool _busy = false;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      await controller.startVideoRecording();
      _recordingStartedAt = DateTime.now();
      setState(() {
        _recording = true;
        _busy = false;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final started = _recordingStartedAt;
        if (started == null || !mounted) return;
        final elapsed = DateTime.now().difference(started);
        setState(() => _elapsed = elapsed);
        if (elapsed >= widget.maxDuration) {
          unawaited(_stopRecording(save: true));
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not start video recording: $error';
        });
      }
    }
  }

  Future<void> _stopRecording({required bool save}) async {
    final controller = _controller;
    if (controller == null || !_recording || _busy) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    _ticker = null;
    try {
      final file = await controller.stopVideoRecording();
      final elapsed = _recordingStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(_recordingStartedAt!);
      if (!mounted) return;
      if (save) {
        Navigator.of(
          context,
        ).pop(RecordedCcnVideo(file: file, duration: elapsed));
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not finish video recording: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('CCN Walkthrough Video'),
        backgroundColor: AppColors.headerGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Cancel video',
          onPressed: _busy
              ? null
              : () => _recording
                    ? _stopRecording(save: false)
                    : Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : controller == null || !controller.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.white)
                  : AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Text(
                  _recording
                      ? '${_formatDuration(_elapsed)} / ${_formatDuration(widget.maxDuration)}'
                      : 'Maximum ${widget.maxDuration.inMinutes} minutes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _busy ||
                            controller == null ||
                            !controller.value.isInitialized
                        ? null
                        : _recording
                        ? () => _stopRecording(save: true)
                        : _startRecording,
                    icon: Icon(
                      _recording
                          ? Icons.stop_circle_outlined
                          : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      _busy
                          ? 'Please wait…'
                          : _recording
                          ? 'Stop and Save'
                          : 'Start Recording',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'GPS sampling continues while this camera screen is open.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

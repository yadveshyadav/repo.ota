import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hero_app/core/theme/app_colors.dart';

class RecordedCcnVideo {
  const RecordedCcnVideo({required this.file, required this.duration});

  final XFile file;
  final Duration duration;
}

/// Records in-app so the parent screen can keep the GPS trace active alongside
/// the camera. It requests 1080p/90 fps when supported and falls back to the
/// camera's supported frame rate while keeping the 1080p quality preset.
class CcnCameraRecordingScreen extends StatefulWidget {
  const CcnCameraRecordingScreen({super.key, required this.maxDuration});

  final Duration maxDuration;

  @override
  State<CcnCameraRecordingScreen> createState() =>
      _CcnCameraRecordingScreenState();
}

class _CcnCameraRecordingScreenState extends State<CcnCameraRecordingScreen> {
  static const _videoChannel = MethodChannel(
    'com.infocrats.hero/video_compression',
  );

  CameraController? _controller;
  Timer? _ticker;
  DateTime? _recordingStartedAt;
  Duration _elapsed = Duration.zero;
  String? _error;
  bool _busy = false;
  bool _recording = false;
  List<int> _fpsCandidates = const [];
  int? _activeFps;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera({List<int>? fpsCandidates}) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final candidates = fpsCandidates ?? await _supportedFpsCandidates(camera);
      _fpsCandidates = candidates;
      final attempts = <int?>[...candidates, null];
      Object? lastError;
      for (final fps in attempts) {
        try {
          controller = CameraController(
            camera,
            ResolutionPreset.veryHigh,
            enableAudio: true,
            fps: fps,
            videoBitrate: 10000000,
            audioBitrate: 128000,
          );
          await controller.initialize();
          if (!mounted) {
            await controller.dispose();
            return;
          }
          setState(() {
            _controller = controller;
            _activeFps = fps;
            _error = null;
          });
          return;
        } catch (error) {
          lastError = error;
          await controller?.dispose();
          controller = null;
        }
      }
      throw lastError ?? Exception('Could not initialize the camera.');
    } catch (error) {
      if (controller != null) await controller.dispose();
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<List<int>> _supportedFpsCandidates(CameraDescription camera) async {
    try {
      final ranges = await _videoChannel.invokeListMethod<dynamic>(
        'supportedFpsRanges',
        {'cameraId': camera.name},
      );
      final candidates = <int>{};
      for (final range in ranges ?? const []) {
        if (range is! List || range.length < 2) continue;
        final lower = (range[0] as num).toInt();
        final upper = (range[1] as num).toInt();
        final target = upper > 90 ? 90 : upper;
        if (target >= lower && target > 0) candidates.add(target);
      }
      return candidates.toList()..sort((a, b) => b.compareTo(a));
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
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
      if (_activeFps != null) {
        final failedFps = _activeFps!;
        await controller.dispose();
        if (mounted) setState(() => _controller = null);
        final lowerCandidates = _fpsCandidates
            .where((fps) => fps < failedFps)
            .toList();
        await _initializeCamera(fpsCandidates: lowerCandidates);
        if (mounted) {
          setState(() {
            _busy = false;
            _error =
                'Could not start at $failedFps fps. Trying a lower supported rate; tap Record to start.';
          });
        }
        return;
      }
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

import 'dart:async';
import 'dart:io';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// CamerAwesome adapter — not imported by shell.
class LocalCapturePort implements CapturePort {
  LocalCapturePort({Duration maxDuration = const Duration(seconds: 60)})
    : _maxDuration = maxDuration;

  Duration _maxDuration;
  final _progressController = StreamController<Duration>.broadcast();
  final _finishedController = StreamController<CapturedMedia>.broadcast();
  CameraState? _state;
  bool _recording = false;
  bool _stopping = false;
  bool _ready = false;
  DateTime? _recordStartedAt;
  Timer? _progressTimer;
  String? _liveFilterId;
  CaptureFlashMode _flash = CaptureFlashMode.off;

  @override
  Stream<Duration> get recordingProgress => _progressController.stream;

  @override
  Stream<CapturedMedia> get recordingFinished => _finishedController.stream;

  @override
  bool get isRecording => _recording;

  @override
  bool get isReady => _ready;

  @override
  Duration get maxDuration => _maxDuration;

  @override
  Future<CapturePermissionStatus> ensurePermissions() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (cam.isGranted && mic.isGranted) {
      return CapturePermissionStatus.granted;
    }
    if (cam.isPermanentlyDenied || mic.isPermanentlyDenied) {
      return CapturePermissionStatus.permanentlyDenied;
    }
    if (cam.isRestricted || mic.isRestricted) {
      return CapturePermissionStatus.restricted;
    }
    return CapturePermissionStatus.denied;
  }

  @override
  Widget buildPreview({Key? key}) {
    return CameraAwesomeBuilder.custom(
      saveConfig: SaveConfig.video(
        pathBuilder: (sensors) async {
          final dir = await getTemporaryDirectory();
          final file = File(
            p.join(
              dir.path,
              'reel_${DateTime.now().millisecondsSinceEpoch}.mp4',
            ),
          );
          return SingleCaptureRequest(file.path, sensors.first);
        },
      ),
      sensorConfig: SensorConfig.single(
        sensor: Sensor.position(SensorPosition.back),
        aspectRatio: CameraAspectRatios.ratio_16_9,
        flashMode: _mapFlash(_flash),
      ),
      previewFit: CameraPreviewFit.cover,
      builder: (state, preview) {
        _state = state;
        final ready = state is! PreparingCameraState;
        if (ready != _ready) {
          _ready = ready;
        }
        return const SizedBox.expand();
      },
    );
  }

  FlashMode _mapFlash(CaptureFlashMode mode) {
    switch (mode) {
      case CaptureFlashMode.off:
        return FlashMode.none;
      case CaptureFlashMode.on:
        return FlashMode.on;
      case CaptureFlashMode.auto:
        return FlashMode.auto;
    }
  }

  @override
  Future<bool> startRecording() async {
    final state = _state;
    if (state == null || _recording || _stopping || !_ready) return false;

    var started = false;

    Future<void> begin(VideoCameraState s) async {
      await s.startRecording();
      _recording = true;
      started = true;
      _recordStartedAt = DateTime.now();
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final recordStarted = _recordStartedAt;
        if (recordStarted == null || _stopping) return;
        final elapsed = DateTime.now().difference(recordStarted);
        if (!_progressController.isClosed) {
          _progressController.add(elapsed);
        }
        if (elapsed >= _maxDuration) {
          unawaited(stopRecording());
        }
      });
    }

    await state.when(
      onVideoMode: begin,
      onPreparingCamera: (_) async {},
      onPhotoMode: (s) async {
        s.setState(CaptureMode.video);
      },
      onVideoRecordingMode: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );
    return started;
  }

  @override
  Future<CapturedMedia?> stopRecording() async {
    final state = _state;
    if (state == null || !_recording || _stopping) return null;
    _stopping = true;
    _progressTimer?.cancel();
    final started = _recordStartedAt;
    _recordStartedAt = null;
    final elapsed = started == null
        ? Duration.zero
        : DateTime.now().difference(started);

    CapturedMedia? result;
    try {
      await state.when(
        onVideoRecordingMode: (s) async {
          final completer = Completer<CapturedMedia?>();
          await s.stopRecording(
            onVideo: (captureRequest) {
              captureRequest.when(
                single: (single) {
                  final path = single.file?.path;
                  if (path == null) {
                    completer.complete(null);
                  } else {
                    completer.complete(
                      CapturedMedia(path: path, duration: elapsed),
                    );
                  }
                },
                multiple: (_) => completer.complete(null),
              );
            },
            onVideoFailed: (_) {
              if (!completer.isCompleted) completer.complete(null);
            },
          );
          result = await completer.future.timeout(
            const Duration(seconds: 15),
            onTimeout: () => null,
          );
        },
        onPreparingCamera: (_) async {},
        onPhotoMode: (_) async {},
        onVideoMode: (_) async {},
        onPreviewMode: (_) async {},
        onAnalysisOnlyMode: (_) async {},
      );
    } finally {
      _recording = false;
      _stopping = false;
    }

    if (result != null && !_finishedController.isClosed) {
      _finishedController.add(result!);
    }
    return result;
  }

  @override
  Future<void> flipCamera() async {
    final state = _state;
    if (state == null || _recording) return;
    await state.switchCameraSensor();
  }

  @override
  Future<void> setFlash(CaptureFlashMode mode) async {
    _flash = mode;
    final state = _state;
    if (state == null) return;
    await state.sensorConfig.setFlashMode(_mapFlash(mode));
  }

  @override
  Future<void> setZoom(double zoom) async {
    final state = _state;
    if (state == null) return;
    await state.sensorConfig.setZoom(zoom.clamp(0.0, 1.0));
  }

  @override
  Future<void> setMaxDuration(Duration duration) async {
    _maxDuration = duration;
  }

  @override
  Future<void> setLiveFilter(String? filterId) async {
    _liveFilterId = filterId;
  }

  String? get liveFilterId => _liveFilterId;

  @override
  Future<void> dispose() async {
    _progressTimer?.cancel();
    if (_recording && !_stopping) {
      try {
        await stopRecording();
      } catch (_) {}
    }
    await _progressController.close();
    await _finishedController.close();
    _state = null;
    _ready = false;
  }
}

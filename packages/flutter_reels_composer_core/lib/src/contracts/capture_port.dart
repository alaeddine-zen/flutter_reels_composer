import 'dart:typed_data';

import 'package:flutter/widgets.dart';

enum CaptureFlashMode { off, on, auto }

enum CapturePermissionStatus { granted, denied, permanentlyDenied, restricted }

abstract class CapturePort {
  Stream<Duration> get recordingProgress;
  Stream<CapturedMedia> get recordingFinished;
  bool get isRecording;
  bool get isReady;
  Duration get maxDuration;

  Future<CapturePermissionStatus> ensurePermissions();
  Widget buildPreview({Key? key});
  Future<bool> startRecording();
  Future<CapturedMedia?> stopRecording();
  Future<void> flipCamera();
  Future<void> setFlash(CaptureFlashMode mode);
  Future<void> setZoom(double zoom);
  Future<void> setMaxDuration(Duration duration);
  Future<void> setLiveFilter(String? filterId);
  Future<void> dispose();
}

class CapturedMedia {
  const CapturedMedia({
    required this.path,
    required this.duration,
    this.isVideo = true,
  });

  final String path;
  final Duration duration;
  final bool isVideo;
}

abstract class MediaPickerPort {
  bool get permissionDenied;

  Future<List<GalleryAsset>> listVideos({int page = 0, int pageSize = 60});
  Future<List<GalleryAsset>> listPhotos({int page = 0, int pageSize = 60});
  Future<CapturedMedia?> importAsset(GalleryAsset asset);
  Future<PickedAudio?> pickAudio();
  Future<void> dispose();
}

class PickedAudio {
  const PickedAudio({
    required this.path,
    required this.title,
    this.duration = Duration.zero,
  });

  final String path;
  final String title;
  final Duration duration;
}

class GalleryAsset {
  const GalleryAsset({
    required this.id,
    required this.thumbnailBytes,
    required this.duration,
    required this.isVideo,
    this.width,
    this.height,
  });

  final String id;
  final Uint8List? thumbnailBytes;
  final Duration duration;
  final bool isVideo;
  final int? width;
  final int? height;
}

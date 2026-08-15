import 'dart:io';

import 'capture_port.dart';

abstract interface class StillImageEncoderPort {
  Future<CapturedMedia?> encodeStillImage(File image, Directory directory);
}

/// Extracts preview frames without coupling the UI package to FFmpeg.
abstract interface class FrameExtractorPort {
  const FrameExtractorPort();

  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  });

  Future<File?> extractOne({
    required String sourcePath,
    Duration at = Duration.zero,
    int height = 72,
  });
}

class NoopFrameExtractor implements FrameExtractorPort {
  const NoopFrameExtractor();

  @override
  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) async => const [];

  @override
  Future<File?> extractOne({
    required String sourcePath,
    Duration at = Duration.zero,
    int height = 72,
  }) async => null;
}

/// Legacy global adapter kept for source compatibility.
@Deprecated('Inject FrameExtractorPort through ComposerConfig instead.')
class VideoFrameStrip {
  VideoFrameStrip._();

  static Future<List<File>> Function({
    required String sourcePath,
    Duration start,
    Duration? end,
    int count,
    int height,
  })
  extractImpl = _emptyList;

  static Future<File?> Function({
    required String sourcePath,
    Duration? at,
    int height,
  })
  extractOneImpl = _emptyOne;

  static Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) {
    return extractImpl(
      sourcePath: sourcePath,
      start: start,
      end: end,
      count: count,
      height: height,
    );
  }

  static Future<File?> extractOne({
    required String sourcePath,
    Duration? at,
    int height = 72,
  }) {
    return extractOneImpl(sourcePath: sourcePath, at: at, height: height);
  }

  static Future<List<File>> _emptyList({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) async => const [];

  static Future<File?> _emptyOne({
    required String sourcePath,
    Duration? at,
    int height = 72,
  }) async => null;
}

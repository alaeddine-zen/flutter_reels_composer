import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Sparse, cached frame extraction backed by the LGPL FFmpeg build.
class FfmpegLgplFrameExtractor implements FrameExtractorPort {
  FfmpegLgplFrameExtractor();

  final Map<String, Future<List<File>>> _inFlight = {};

  @override
  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) {
    final key =
        '$sourcePath|${start.inMilliseconds}|${end?.inMilliseconds}|$count|$height';
    return _inFlight.putIfAbsent(key, () async {
      try {
        return await _extractUnlocked(
          sourcePath: sourcePath,
          start: start,
          end: end,
          count: count,
          height: height,
        );
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  @override
  Future<File?> extractOne({
    required String sourcePath,
    Duration at = Duration.zero,
    int height = 72,
  }) async {
    final frames = await extract(
      sourcePath: sourcePath,
      start: at,
      end: at + const Duration(milliseconds: 40),
      count: 1,
      height: height,
    );
    return frames.firstOrNull;
  }

  Future<List<File>> _extractUnlocked({
    required String sourcePath,
    required Duration start,
    required Duration? end,
    required int count,
    required int height,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync() || count <= 0) return const [];

    final span = end == null
        ? const Duration(seconds: 1)
        : (end - start).isNegative
        ? Duration.zero
        : end - start;
    final safeCount = count.clamp(1, 16);
    final temp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        temp.path,
        'flutter_reels_composer_frames',
        '${sourcePath.hashCode.abs()}_${start.inMilliseconds}_'
            '${span.inMilliseconds}_$safeCount',
      ),
    );

    if (dir.existsSync()) {
      final existing =
          dir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.jpg'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      if (existing.length >= safeCount) {
        return existing.take(safeCount).toList();
      }
    } else {
      await dir.create(recursive: true);
    }

    final frames = <File>[];
    for (var index = 0; index < safeCount; index++) {
      final timestamp = safeCount == 1
          ? start
          : start +
                Duration(
                  milliseconds: (span.inMilliseconds * index / (safeCount - 1))
                      .round(),
                );
      final frame = File(
        p.join(dir.path, 'f_${index.toString().padLeft(2, '0')}.jpg'),
      );
      if (frame.existsSync() && frame.lengthSync() > 0) {
        frames.add(frame);
        continue;
      }
      final seconds = (timestamp.inMilliseconds / 1000).clamp(0.0, 86400.0);
      final command =
          '-y -ss $seconds -i "${_escape(sourcePath)}" -frames:v 1 '
          '-vf "scale=-2:$height" -q:v 5 "${_escape(frame.path)}"';
      try {
        final session = await FFmpegKit.execute(command);
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code) && frame.existsSync()) {
          frames.add(frame);
        }
      } catch (_) {
        // Frame previews are optional; the UI renders placeholders on failure.
      }
    }
    return frames;
  }

  String _escape(String value) => value.replaceAll('"', r'\"');
}

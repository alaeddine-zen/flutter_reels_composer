import 'dart:io';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('musicSeekTarget', () {
    test('adds startOffset to the timeline playhead', () {
      expect(
        musicSeekTarget(const Duration(seconds: 2), const Duration(seconds: 5)),
        const Duration(seconds: 7),
      );
    });

    test('clamps a negative sum', () {
      expect(
        musicSeekTarget(const Duration(milliseconds: -20), Duration.zero),
        Duration.zero,
      );
    });
  });

  group('shouldCorrectClock', () {
    test('ignores drift under the threshold', () {
      expect(
        shouldCorrectClock(
          expected: const Duration(milliseconds: 1000),
          actual: const Duration(milliseconds: 1080),
          threshold: kPreviewAudioDriftThreshold,
        ),
        isFalse,
      );
    });

    test('corrects drift at or above the threshold', () {
      expect(
        shouldCorrectClock(
          expected: const Duration(milliseconds: 1000),
          actual: const Duration(milliseconds: 1120),
          threshold: kPreviewAudioDriftThreshold,
        ),
        isTrue,
      );
    });
  });

  group('duetSeekFromNotify', () {
    test('ignores 50 ms playback ticks', () {
      expect(
        duetSeekFromNotify(
          previous: const Duration(milliseconds: 200),
          next: const Duration(milliseconds: 250),
        ),
        isFalse,
      );
    });

    test('seeks on scrub jumps', () {
      expect(
        duetSeekFromNotify(
          previous: const Duration(seconds: 1),
          next: const Duration(seconds: 4),
        ),
        isTrue,
      );
    });
  });

  group('wrapLoopingClock', () {
    test('wraps past the parent duration', () {
      expect(
        wrapLoopingClock(
          const Duration(milliseconds: 2500),
          const Duration(seconds: 2),
        ),
        const Duration(milliseconds: 500),
      );
    });

    test('passes through in-range positions', () {
      expect(
        wrapLoopingClock(
          const Duration(milliseconds: 400),
          const Duration(seconds: 2),
        ),
        const Duration(milliseconds: 400),
      );
    });
  });

  test('prefetchTimelineThumbs skips images and uses stable keys', () async {
    final inner = _RecordingExtractor();
    await prefetchTimelineThumbs(inner, const [
      TimelineClip(
        id: 'v',
        sourcePath: '/tmp/a.mp4',
        sourceDuration: Duration(seconds: 4),
      ),
      TimelineClip(
        id: 'p',
        sourcePath: '/tmp/b.jpg',
        sourceDuration: Duration(seconds: 3),
        kind: TimelineClipKind.image,
      ),
    ]);
    expect(inner.calls, 1);
    expect(inner.lastStart, Duration.zero);
    expect(inner.lastEnd, const Duration(seconds: 4));
    expect(inner.lastCount, kTimelineThumbCount);
    expect(inner.lastHeight, kTimelineThumbHeight);
  });
}

class _RecordingExtractor implements FrameExtractorPort {
  int calls = 0;
  Duration? lastStart;
  Duration? lastEnd;
  int? lastCount;
  int? lastHeight;

  @override
  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) async {
    calls++;
    lastStart = start;
    lastEnd = end;
    lastCount = count;
    lastHeight = height;
    return const [];
  }

  @override
  Future<File?> extractOne({
    required String sourcePath,
    Duration at = Duration.zero,
    int height = 72,
  }) async => null;
}

import 'dart:io';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingExtractor implements FrameExtractorPort {
  int calls = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) async {
    calls++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    inFlight--;
    return [File('/tmp/$sourcePath.jpg')];
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
}

void main() {
  test('CachedFrameExtractor returns LRU hits without calling inner', () async {
    final inner = _CountingExtractor();
    final cached = CachedFrameExtractor(inner, maxEntries: 4);
    final first = await cached.extract(sourcePath: 'a.mp4', count: 8);
    final second = await cached.extract(sourcePath: 'a.mp4', count: 8);
    expect(inner.calls, 1);
    expect(first, same(second));
  });

  test('CachedFrameExtractor serializes distinct keys', () async {
    final inner = _CountingExtractor();
    final cached = CachedFrameExtractor(inner, maxEntries: 8);
    await Future.wait([
      cached.extract(sourcePath: 'a.mp4'),
      cached.extract(sourcePath: 'b.mp4'),
      cached.extract(sourcePath: 'c.mp4'),
    ]);
    expect(inner.calls, 3);
    expect(inner.maxInFlight, 1);
  });

  test('CachedFrameExtractor coalesces in-flight identical keys', () async {
    final inner = _CountingExtractor();
    final cached = CachedFrameExtractor(inner, maxEntries: 4);
    await Future.wait([
      cached.extract(sourcePath: 'a.mp4'),
      cached.extract(sourcePath: 'a.mp4'),
    ]);
    expect(inner.calls, 1);
  });
}

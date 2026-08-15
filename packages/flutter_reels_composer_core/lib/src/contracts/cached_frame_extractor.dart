import 'dart:async';
import 'dart:io';

import 'frame_extractor.dart';

/// In-memory LRU + single-flight queue in front of a [FrameExtractorPort].
///
/// FFmpeg frame extraction is expensive. Timeline zoom/trim used to spawn
/// overlapping jobs for nearly identical keys. This wrapper:
///
/// * returns a completed result from a small LRU (default 48 keys)
/// * coalesces in-flight requests with the same key
/// * serializes inner `extract` calls so only one FFmpeg job runs at a time
class CachedFrameExtractor implements FrameExtractorPort {
  CachedFrameExtractor(this.inner, {this.maxEntries = 48})
    : assert(maxEntries > 0, 'maxEntries must be positive');

  final FrameExtractorPort inner;
  final int maxEntries;

  final Map<String, List<File>> _lru = {};
  final List<String> _order = [];
  final Map<String, Future<List<File>>> _inFlight = {};
  Future<void> _gate = Future<void>.value();

  static String cacheKey({
    required String sourcePath,
    required Duration start,
    required Duration? end,
    required int count,
    required int height,
  }) {
    return '$sourcePath|${start.inMilliseconds}|${end?.inMilliseconds}|'
        '$count|$height';
  }

  @override
  Future<List<File>> extract({
    required String sourcePath,
    Duration start = Duration.zero,
    Duration? end,
    int count = 8,
    int height = 72,
  }) {
    final key = cacheKey(
      sourcePath: sourcePath,
      start: start,
      end: end,
      count: count,
      height: height,
    );
    final cached = _lru[key];
    if (cached != null) {
      _touch(key);
      return Future<List<File>>.value(cached);
    }
    return _inFlight.putIfAbsent(key, () async {
      try {
        final files = await _serialized(
          () => inner.extract(
            sourcePath: sourcePath,
            start: start,
            end: end,
            count: count,
            height: height,
          ),
        );
        _store(key, files);
        return files;
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

  Future<T> _serialized<T>(Future<T> Function() job) {
    final previous = _gate;
    final released = Completer<void>();
    _gate = released.future;
    return previous
        .then<void>((_) {}, onError: (_) {})
        .then((_) => job())
        .whenComplete(() {
          if (!released.isCompleted) released.complete();
        });
  }

  void _store(String key, List<File> files) {
    _lru[key] = files;
    _touch(key);
    while (_order.length > maxEntries) {
      final evicted = _order.removeAt(0);
      if (evicted != key) _lru.remove(evicted);
    }
  }

  void _touch(String key) {
    _order.remove(key);
    _order.add(key);
  }
}

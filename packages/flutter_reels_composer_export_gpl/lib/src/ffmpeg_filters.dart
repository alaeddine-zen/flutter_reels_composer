/// FFmpeg filter-graph helpers. Kept out of `flutter_reels_composer_core`.
class FfmpegFilters {
  const FfmpegFilters._();

  static String atempoChain(double speed) {
    var remaining = speed;
    if (remaining <= 0) remaining = 1;
    final parts = <String>[];
    while (remaining > 2.0 + 1e-6) {
      parts.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5 - 1e-6) {
      parts.add('atempo=0.5');
      remaining /= 0.5;
    }
    if ((remaining - 1.0).abs() > 0.001) {
      parts.add('atempo=${remaining.toStringAsFixed(4)}');
    }
    return parts.join(',');
  }

  static String setpts(double speed) {
    if ((speed - 1.0).abs() < 0.001) return '';
    return 'setpts=PTS/$speed';
  }

  static String overlayEnable(Duration start, Duration end) {
    final a = (start.inMilliseconds / 1000.0).toStringAsFixed(3);
    final b = (end.inMilliseconds / 1000.0).toStringAsFixed(3);
    return "enable='between(t,$a,$b)'";
  }

  /// Canvas cover matching preview `BoxFit.cover`: scale-up then center-crop.
  static String canvasCover({
    required int width,
    required int height,
    required int fps,
  }) {
    final w = width.clamp(16, 7680);
    final h = height.clamp(16, 7680);
    final r = fps.clamp(1, 120);
    return 'scale=$w:$h:force_original_aspect_ratio=increase,'
        'crop=$w:$h,fps=$r,format=yuv420p';
  }

  /// Sequential dip-to-black. Times are on the **output** timeline (after setpts).
  static String dipToBlack({
    required double durationSec,
    double fadeInSec = 0,
    double fadeOutSec = 0,
  }) {
    final parts = <String>[];
    if (fadeInSec > 0.001) {
      parts.add('fade=t=in:st=0:d=${fadeInSec.toStringAsFixed(3)}');
    }
    if (fadeOutSec > 0.001) {
      final start = (durationSec - fadeOutSec).clamp(0.0, durationSec);
      parts.add(
        'fade=t=out:st=${start.toStringAsFixed(3)}:d=${fadeOutSec.toStringAsFixed(3)}',
      );
    }
    return parts.join(',');
  }

  static String join(Iterable<String> parts) =>
      parts.where((p) => p.isNotEmpty).join(',');
}

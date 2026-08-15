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
}

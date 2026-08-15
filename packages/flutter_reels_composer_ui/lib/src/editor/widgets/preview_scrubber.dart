import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// TikTok-style timeline scrubber under the preview.
class PreviewScrubber extends StatelessWidget {
  const PreviewScrubber({
    super.key,
    required this.theme,
    required this.preview,
    this.bottomInset = 12,
  });

  final ComposerTheme theme;
  final PreviewPort preview;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final totalMs = preview.duration.inMilliseconds.clamp(1, 600000);
    final posMs = preview.position.inMilliseconds.clamp(0, totalMs);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 88, bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _fmt(Duration(milliseconds: posMs)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
              const Spacer(),
              Text(
                _fmt(Duration(milliseconds: totalMs)),
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: theme.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: posMs.toDouble(),
              min: 0,
              max: totalMs.toDouble(),
              onChangeStart: (_) {
                HapticFeedback.selectionClick();
                preview.pause();
              },
              onChanged: (v) {
                preview.seek(Duration(milliseconds: v.round()));
              },
              onChangeEnd: (_) {
                HapticFeedback.selectionClick();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

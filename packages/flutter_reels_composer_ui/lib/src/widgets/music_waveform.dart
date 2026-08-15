import 'package:flutter/material.dart';

/// Start-offset meter for the music tool (not PCM / not a decoded waveform).
///
/// [progress] 0–1 is the selected [AudioTrack.startOffset] relative to the
/// allowed window. Bar heights are equal so the chrome cannot be mistaken
/// for audio analysis.
class MusicWaveform extends StatelessWidget {
  const MusicWaveform({
    super.key,
    required this.seed,
    this.progress = 0,
    this.height = 36,
    this.accent = const Color(0xFFFF2D55),
    this.barCount = 48,
  });

  /// Kept for call-site compatibility; not used for bar heights.
  final String seed;
  final double progress;
  final double height;
  final Color accent;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final barHeight = height * 0.55;

    return SizedBox(
      key: ValueKey<String>(seed),
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < barCount; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: (i / barCount) <= p ? accent : Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

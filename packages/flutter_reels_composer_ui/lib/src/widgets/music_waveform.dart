import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Deterministic faux waveform (TikTok look) keyed by [seed].
/// [progress] 0–1 highlights the played / selected start region.
class MusicWaveform extends StatelessWidget {
  const MusicWaveform({
    super.key,
    required this.seed,
    this.progress = 0,
    this.height = 36,
    this.accent = const Color(0xFFFF2D55),
    this.barCount = 48,
  });

  final String seed;
  final double progress;
  final double height;
  final Color accent;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed.hashCode);
    final bars = List<double>.generate(
      barCount,
      (_) => 0.25 + rng.nextDouble() * 0.75,
    );
    final p = progress.clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.8),
                child: Align(
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    height: height * bars[i],
                    decoration: BoxDecoration(
                      color: (i / bars.length) <= p ? accent : Colors.white24,
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

import 'package:flutter/material.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../widgets/filmstrip.dart';

/// Picks the cover frame on the composition timeline.
class CoverToolPanel extends StatelessWidget {
  const CoverToolPanel({
    super.key,
    required this.theme,
    required this.engine,
    required this.project,
    required this.preview,
    this.frameExtractor = const NoopFrameExtractor(),
  });

  final ComposerTheme theme;
  final ComposerEngine engine;
  final ProjectDocument project;
  final PreviewPort preview;
  final FrameExtractorPort frameExtractor;

  ({TimelineClip clip, Duration sourceAt}) _sourceFor(Duration timeline) {
    var remaining = timeline.isNegative ? Duration.zero : timeline;
    for (final clip in project.clips) {
      if (remaining <= clip.trimmedDuration) {
        final sourceAt =
            clip.trimStart +
            Duration(
              microseconds: (remaining.inMicroseconds * clip.speed).round(),
            );
        return (clip: clip, sourceAt: sourceAt);
      }
      remaining -= clip.trimmedDuration;
    }
    final clip = project.clips.last;
    return (clip: clip, sourceAt: clip.trimEnd);
  }

  @override
  Widget build(BuildContext context) {
    if (project.clips.isEmpty) return const SizedBox.shrink();
    final totalMs = project.duration.inMilliseconds.clamp(1, 600000).toDouble();
    final currentMs = project.cover.timeOffset.inMilliseconds.toDouble().clamp(
      0.0,
      totalMs,
    );
    final mapped = _sourceFor(Duration(milliseconds: currentMs.round()));
    final spanMs = mapped.clip.sourceSpan.inMilliseconds.clamp(1, 600000);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cover · ${_fmt(Duration(milliseconds: currentMs.round()))}',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              VideoFrameThumb(
                sourcePath: mapped.clip.sourcePath,
                at: mapped.sourceAt,
                frameExtractor: frameExtractor,
                size: 64,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Filmstrip(
                  sourcePath: mapped.clip.sourcePath,
                  frameExtractor: frameExtractor,
                  start: mapped.clip.trimStart,
                  end: mapped.clip.trimEnd,
                  height: 56,
                  count: 10,
                  accent: theme.accent,
                  range: RangeValues(
                    ((mapped.sourceAt - mapped.clip.trimStart).inMilliseconds /
                            spanMs)
                        .clamp(0.0, 1.0),
                    (((mapped.sourceAt - mapped.clip.trimStart).inMilliseconds +
                                1) /
                            spanMs)
                        .clamp(0.0, 1.0),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: currentMs,
            min: 0,
            max: totalMs,
            activeColor: theme.accent,
            inactiveColor: Colors.white24,
            onChangeStart: (_) => preview.pause(),
            onChanged: (v) {
              final offset = Duration(milliseconds: v.round());
              engine.applyMutation(
                SetCoverMutation(CoverChoice(timeOffset: offset)),
              );
              preview.seek(offset);
            },
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () {
                final offset = preview.position;
                engine.applyMutation(
                  SetCoverMutation(CoverChoice(timeOffset: offset)),
                );
              },
              icon: const Icon(Icons.image_outlined, color: Colors.white),
              label: Text(
                'Utiliser la frame actuelle',
                style: TextStyle(color: theme.foreground),
              ),
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

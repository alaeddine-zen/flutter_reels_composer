import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'filmstrip.dart';

/// Multi-clip timeline with thumbs + playhead (TikTok-style junctions).
class ClipTimeline extends StatelessWidget {
  const ClipTimeline({
    super.key,
    required this.theme,
    required this.project,
    required this.position,
    this.frameExtractor = const NoopFrameExtractor(),
    this.onSeek,
    this.onSelectClip,
    this.selectedClipIndex,
  });

  final ComposerTheme theme;
  final ProjectDocument project;
  final Duration position;
  final FrameExtractorPort frameExtractor;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<int>? onSelectClip;
  final int? selectedClipIndex;

  @override
  Widget build(BuildContext context) {
    if (project.clips.isEmpty) return const SizedBox.shrink();
    final totalMs = project.duration.inMilliseconds.clamp(1, 600000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final t = Duration(
                    milliseconds: ((d.localPosition.dx / w) * totalMs)
                        .round()
                        .clamp(0, totalMs),
                  );
                  HapticFeedback.selectionClick();
                  onSeek?.call(t);
                },
                onHorizontalDragUpdate: (d) {
                  final t = Duration(
                    milliseconds: ((d.localPosition.dx / w) * totalMs)
                        .round()
                        .clamp(0, totalMs),
                  );
                  onSeek?.call(t);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < project.clips.length; i++) ...[
                          if (i > 0) Container(width: 2, color: Colors.white54),
                          Expanded(
                            flex: project
                                .clips[i]
                                .trimmedDuration
                                .inMilliseconds
                                .clamp(1, totalMs),
                            child: GestureDetector(
                              onTap: () => onSelectClip?.call(i),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: selectedClipIndex == i
                                      ? Border.all(
                                          color: theme.accent,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: VideoFrameThumb(
                                  sourcePath: project.clips[i].sourcePath,
                                  frameExtractor: frameExtractor,
                                  at:
                                      project.clips[i].trimStart +
                                      Duration(
                                        milliseconds:
                                            (project
                                                        .clips[i]
                                                        .trimmedDuration
                                                        .inMilliseconds *
                                                    0.3)
                                                .round(),
                                      ),
                                  size: 52,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Positioned(
                      left: (position.inMilliseconds / totalMs) * w - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          project.clips.length == 1
              ? '1 clip'
              : '${project.clips.length} clips · jonctions visibles',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.muted, fontSize: 11),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';
import '../../widgets/filmstrip.dart';

class TrimToolPanel extends StatefulWidget {
  const TrimToolPanel({
    super.key,
    required this.theme,
    required this.controller,
    required this.project,
    required this.preview,
    this.frameExtractor = const NoopFrameExtractor(),
    this.maxDuration = const Duration(seconds: 60),
  });

  final ComposerTheme theme;
  final ComposerController controller;
  final ProjectDocument project;
  final PreviewPort preview;
  final FrameExtractorPort frameExtractor;
  final Duration maxDuration;

  ComposerEngine get engine => controller.engine;

  @override
  State<TrimToolPanel> createState() => _TrimToolPanelState();
}

class _TrimToolPanelState extends State<TrimToolPanel> {
  late RangeValues _range;
  int _clipIndex = 0;
  bool _scrubbing = false;

  @override
  void initState() {
    super.initState();
    _clipIndex = 0;
    _sync();
  }

  @override
  void didUpdateWidget(covariant TrimToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project && !_scrubbing) {
      if (_clipIndex >= widget.project.clips.length) {
        _clipIndex = widget.project.clips.isEmpty
            ? 0
            : widget.project.clips.length - 1;
      }
      _sync();
    }
  }

  Duration get _otherClipsDuration {
    var sum = Duration.zero;
    for (var i = 0; i < widget.project.clips.length; i++) {
      if (i == _clipIndex) continue;
      sum += widget.project.clips[i].trimmedDuration;
    }
    return sum;
  }

  double get _maxSpanMs {
    final remaining = widget.maxDuration - _otherClipsDuration;
    final clipped = remaining.isNegative ? Duration.zero : remaining;
    final clip = widget.project.clips[_clipIndex];
    final bySource = clip.sourceDuration.inMilliseconds.toDouble();
    return clipped.inMilliseconds.toDouble().clamp(1.0, bySource).toDouble();
  }

  Duration _prefixBeforeClip(ProjectDocument project, int index) {
    var sum = Duration.zero;
    for (var i = 0; i < index && i < project.clips.length; i++) {
      sum += project.clips[i].trimmedDuration;
    }
    return sum;
  }

  void _sync() {
    if (widget.project.clips.isEmpty) {
      _range = const RangeValues(0, 1);
      return;
    }
    final clip = widget.project.clips[_clipIndex];
    final total = clip.sourceDuration.inMilliseconds
        .toDouble()
        .clamp(1.0, double.infinity)
        .toDouble();
    var start = clip.trimStart.inMilliseconds.toDouble().clamp(0.0, total);
    var end = clip.trimEnd.inMilliseconds.toDouble().clamp(0.0, total);
    final maxSpan = _maxSpanMs;
    if (end - start > maxSpan) {
      end = start + maxSpan;
      if (end > total) {
        end = total;
        start = (end - maxSpan).clamp(0.0, total);
      }
    }
    _range = RangeValues(start, end);
  }

  Future<void> _commit(RangeValues v, {required bool previewStart}) async {
    final clip = widget.project.clips[_clipIndex];
    await widget.controller.applyLive(
      UpdateClipTrimMutation(
        clipId: clip.id,
        trimStart: Duration(milliseconds: v.start.round()),
        trimEnd: Duration(milliseconds: v.end.round()),
      ),
    );
    final project = widget.controller.project;
    final prefix = _prefixBeforeClip(project, _clipIndex);
    final span = Duration(milliseconds: (v.end - v.start).round());
    final global = previewStart ? prefix : prefix + span;
    await widget.preview.pause();
    await widget.preview.seek(global);
  }

  Future<void> _onChanged(RangeValues v) async {
    var start = v.start;
    var end = v.end;
    final maxSpan = _maxSpanMs;
    if (end - start > maxSpan) {
      if ((v.start - _range.start).abs() > (v.end - _range.end).abs()) {
        start = end - maxSpan;
      } else {
        end = start + maxSpan;
      }
    }
    final next = RangeValues(start, end);
    final movedStart =
        (next.start - _range.start).abs() >= (next.end - _range.end).abs();
    setState(() {
      _scrubbing = true;
      _range = next;
    });
    await _commit(next, previewStart: movedStart);
  }

  Future<void> _onChangeEnd(RangeValues _) async {
    HapticFeedback.selectionClick();
    widget.controller.endLive();
    if (!mounted) return;
    setState(() => _scrubbing = false);
    // Resume from trim start so user sees the kept segment.
    unawaited(widget.preview.play());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.project.clips.isEmpty) {
      return const SizedBox.shrink();
    }
    final clips = widget.project.clips;
    final clip = clips[_clipIndex];
    final total = clip.sourceDuration.inMilliseconds
        .toDouble()
        .clamp(1.0, double.infinity)
        .toDouble();
    final maxSpan = _maxSpanMs;
    final kept = Duration(milliseconds: (_range.end - _range.start).round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (clips.length > 1)
            Row(
              children: [
                IconButton(
                  onPressed: _clipIndex > 0
                      ? () => setState(() {
                          _clipIndex--;
                          _sync();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Clip ${_clipIndex + 1}/${clips.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.theme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _clipIndex < clips.length - 1
                      ? () => setState(() {
                          _clipIndex++;
                          _sync();
                        })
                      : null,
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ],
            ),
          Text(
            '${_fmt(Duration(milliseconds: _range.start.round()))} → '
            '${_fmt(Duration(milliseconds: _range.end.round()))}'
            '  · ${_fmt(kept)} ${context.composerL10n.text('kept')}'
            '  · max ${_fmt(Duration(milliseconds: maxSpan.round()))}',
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.theme.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Filmstrip(
            sourcePath: clip.sourcePath,
            frameExtractor: widget.frameExtractor,
            start: Duration.zero,
            end: clip.sourceDuration,
            height: 56,
            count: 10,
            accent: widget.theme.accent,
            range: RangeValues(
              (_range.start / total).clamp(0.0, 1.0),
              (_range.end / total).clamp(0.0, 1.0),
            ),
          ),
          RangeSlider(
            values: _range,
            min: 0,
            max: total,
            activeColor: widget.theme.accent,
            inactiveColor: Colors.white24,
            onChanged: (v) => unawaited(_onChanged(v)),
            onChangeEnd: (v) => unawaited(_onChangeEnd(v)),
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

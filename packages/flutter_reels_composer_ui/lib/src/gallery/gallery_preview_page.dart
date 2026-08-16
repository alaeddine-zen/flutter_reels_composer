import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../widgets/composer_next_button.dart';
import '../widgets/filmstrip.dart';
import '../l10n/composer_l10n.dart';

/// TikTok-style gallery confirm step: play + trim + Suivant.
class GalleryPreviewPage extends StatefulWidget {
  const GalleryPreviewPage({
    super.key,
    required this.config,
    required this.media,
    required this.fromPhoto,
    required this.onConfirm,
    required this.onBack,
  });

  final ComposerConfig config;
  final CapturedMedia media;
  final bool fromPhoto;
  final ValueChanged<ProjectDocument> onConfirm;
  final VoidCallback onBack;

  @override
  State<GalleryPreviewPage> createState() => _GalleryPreviewPageState();
}

class _GalleryPreviewPageState extends State<GalleryPreviewPage> {
  VideoPlayerController? _controller;
  late RangeValues _range;
  bool _ready = false;
  String? _error;
  VoidCallback? _loopListener;

  Duration get _sourceDuration => widget.media.duration;

  Duration get _maxTrim {
    final cap = widget.config.maxDuration;
    return _sourceDuration > cap ? cap : _sourceDuration;
  }

  @override
  void initState() {
    super.initState();
    final totalMs = _sourceDuration.inMilliseconds.clamp(1, 600000).toDouble();
    final maxMs = _maxTrim.inMilliseconds
        .toDouble()
        .clamp(1.0, totalMs)
        .toDouble();
    _range = RangeValues(0, maxMs);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.fromPhoto || !widget.media.isVideo) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    setState(() {
      _error = null;
      _ready = false;
    });
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      if (_loopListener != null) previous.removeListener(_loopListener!);
      await previous.dispose();
    }
    try {
      final next = VideoPlayerController.file(File(widget.media.path));
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      await next.setLooping(false);
      await next.setVolume(1);
      _attachTrimLoop(next);
      _controller = next;
      await _seekToRangeStart();
      await next.play();
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = context.composerL10n.text('mediaReadError'));
    }
  }

  void _attachTrimLoop(VideoPlayerController controller) {
    if (_loopListener != null) {
      controller.removeListener(_loopListener!);
    }
    _loopListener = () {
      if (!controller.value.isInitialized) return;
      final start = Duration(milliseconds: _range.start.round());
      final end = Duration(milliseconds: _range.end.round());
      final pos = controller.value.position;
      if (pos < start || pos >= end) {
        controller.seekTo(start);
        if (controller.value.isPlaying) controller.play();
      }
    };
    controller.addListener(_loopListener!);
  }

  Future<void> _seekToRangeStart() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(Duration(milliseconds: _range.start.round()));
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null && _loopListener != null) {
      c.removeListener(_loopListener!);
    }
    c?.dispose();
    super.dispose();
  }

  void _confirm() {
    final trimStart = Duration(milliseconds: _range.start.round());
    final trimEnd = Duration(milliseconds: _range.end.round());
    final clip = TimelineClip(
      id: const Uuid().v4(),
      sourcePath: widget.media.path,
      sourceDuration: _sourceDuration,
      trimStart: trimStart,
      trimEnd: trimEnd,
      kind: widget.fromPhoto || !widget.media.isVideo
          ? TimelineClipKind.image
          : TimelineClipKind.video,
    );
    widget.onConfirm(ProjectDocument.fromClip(clip: clip));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.config.theme;
    final totalMs = _sourceDuration.inMilliseconds.clamp(1, 600000).toDouble();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        context.composerL10n.text('preview'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    ComposerNextButton(
                      label: context.composerL10n.text('next'),
                      onPressed: _ready ? _confirm : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _error != null
                        ? ColoredBox(
                            color: Colors.white10,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _initPlayer,
                                    child: Text(
                                      context.composerL10n.text('retry'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : widget.fromPhoto || !widget.media.isVideo
                        ? SizedBox.expand(
                            child: Image.file(
                              File(widget.media.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Colors.white10),
                            ),
                          )
                        : _ready && _controller != null
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.size.width,
                              height: _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          )
                        : const ColoredBox(
                            color: Colors.white10,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                ),
              ),
              if (!widget.fromPhoto) ...[
                Text(
                  '${_fmt(Duration(milliseconds: _range.start.round()))} → '
                  '${_fmt(Duration(milliseconds: _range.end.round()))}',
                  style: TextStyle(color: theme.muted, fontSize: 12),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Filmstrip(
                    sourcePath: widget.media.path,
                    frameExtractor: widget.config.frameExtractor,
                    start: Duration.zero,
                    end: _sourceDuration,
                    height: 52,
                    count: 10,
                    accent: theme.accent,
                    range: RangeValues(
                      (_range.start / totalMs).clamp(0.0, 1.0),
                      (_range.end / totalMs).clamp(0.0, 1.0),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RangeSlider(
                    values: _range,
                    min: 0,
                    max: totalMs,
                    activeColor: theme.accent,
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      final maxSpan = _maxTrim.inMilliseconds.toDouble();
                      var start = v.start;
                      var end = v.end;
                      if (end - start > maxSpan) {
                        if ((v.start - _range.start).abs() >
                            (v.end - _range.end).abs()) {
                          start = end - maxSpan;
                        } else {
                          end = start + maxSpan;
                        }
                      }
                      setState(() => _range = RangeValues(start, end));
                    },
                    onChangeEnd: (_) => _seekToRangeStart(),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.composerL10n.textWith('photoClip', {
                      'seconds': _sourceDuration.inSeconds,
                    }),
                    style: TextStyle(color: theme.muted),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

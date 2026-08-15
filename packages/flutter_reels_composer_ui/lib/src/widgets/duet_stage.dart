import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// Frames [child] (user camera / preview) with the parent reel.
///
/// Keep this file in sync with
/// `packages/flutter_reels_composer_local/lib/src/preview/duet_stage.dart`
/// (UI cannot depend on local; local cannot depend on UI). Clock policy lives
/// in core (`duetSeekFromNotify`, `wrapLoopingClock`, `shouldCorrectClock`).
class DuetStage extends StatefulWidget {
  const DuetStage({
    super.key,
    required this.layout,
    required this.child,
    this.parentVideoPath,
    this.playParent = true,
    this.seekTo,
  });

  final DuetLayout layout;
  final Widget child;
  final String? parentVideoPath;
  final bool playParent;

  /// Keep the parent playhead aligned with the user timeline (editor).
  final Duration? seekTo;

  @override
  State<DuetStage> createState() => _DuetStageState();
}

class _DuetStageState extends State<DuetStage> {
  VideoPlayerController? _parent;
  bool _ready = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DuetStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentVideoPath != widget.parentVideoPath) {
      _load();
      return;
    }
    if (oldWidget.playParent != widget.playParent) {
      unawaited(_syncPlay());
    }
    if (duetSeekFromNotify(previous: oldWidget.seekTo, next: widget.seekTo)) {
      unawaited(_syncSeek());
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final previous = _parent;
    _parent = null;
    _ready = false;
    if (previous != null) {
      unawaited(previous.dispose());
    }
    final path = widget.parentVideoPath;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      if (mounted && generation == _loadGeneration) setState(() {});
      return;
    }
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize();
      if (!mounted || generation != _loadGeneration) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0.35);
      _parent = c;
      _ready = true;
      await _syncSeek(force: true);
      await _syncPlay();
    } catch (_) {
      await c.dispose();
      if (generation == _loadGeneration) {
        _parent = null;
        _ready = false;
      }
    }
    if (mounted && generation == _loadGeneration) setState(() {});
  }

  Future<void> _syncPlay() async {
    final c = _parent;
    if (c == null || !_ready) return;
    if (widget.playParent) {
      await c.play();
    } else {
      await c.pause();
    }
  }

  Future<void> _syncSeek({bool force = false}) async {
    final c = _parent;
    final raw = widget.seekTo;
    if (c == null || !_ready || raw == null) return;
    final target = wrapLoopingClock(raw, c.value.duration);
    if (!force &&
        !shouldCorrectClock(
          expected: target,
          actual: c.value.position,
          threshold: kDuetParentDriftThreshold,
        )) {
      return;
    }
    try {
      await c.seekTo(target);
    } catch (_) {}
  }

  @override
  void dispose() {
    _loadGeneration++;
    _parent?.dispose();
    super.dispose();
  }

  Widget _parentView() {
    final c = _parent;
    if (!_ready || c == null) {
      return const ColoredBox(color: Color(0xFF111111));
    }
    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.layout.isActive ||
        widget.parentVideoPath == null ||
        widget.parentVideoPath!.isEmpty) {
      return widget.child;
    }

    if (widget.layout == DuetLayout.pip) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            top: 72,
            right: 12,
            width: 110,
            height: 196,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _parentView(),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: ClipRect(child: _parentView())),
        Expanded(child: ClipRect(child: widget.child)),
      ],
    );
  }
}

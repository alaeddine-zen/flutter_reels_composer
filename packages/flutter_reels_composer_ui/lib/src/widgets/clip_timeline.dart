import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'filmstrip.dart';

/// Multi-clip timeline: playhead, trim/roll handles, split, snap, zoom.
class ClipTimeline extends StatefulWidget {
  const ClipTimeline({
    super.key,
    required this.theme,
    required this.project,
    required this.position,
    this.frameExtractor = const NoopFrameExtractor(),
    this.onSeek,
    this.onSelectClip,
    this.selectedClipIndex,
    this.controller,
    this.maxDuration = const Duration(seconds: 60),
    this.canSplit = true,
    this.canDelete = true,
    this.l10n,
    this.onSplit,
  });

  final ComposerTheme theme;
  final ProjectDocument project;
  final Duration position;
  final FrameExtractorPort frameExtractor;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<int>? onSelectClip;
  final int? selectedClipIndex;
  final ComposerController? controller;
  final Duration maxDuration;
  final bool canSplit;
  final bool canDelete;
  final ComposerToolL10n? l10n;
  final VoidCallback? onSplit;

  @override
  State<ClipTimeline> createState() => _ClipTimelineState();
}

class _ClipTimelineState extends State<ClipTimeline> {
  static const _minPps = 16.0;
  static const _maxPps = 280.0;
  static const _trackHeight = 56.0;

  final _scroll = ScrollController();
  double _zoom = 1;
  int? _localSelected;

  List<TimelineClip> get _clips => widget.project.clips;

  int? get _selectedIndex => widget.selectedClipIndex ?? _localSelected;

  ComposerToolL10n get _l10n => widget.l10n ?? const _FallbackL10n();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Duration _snap(Duration value, {Iterable<Duration> extra = const []}) {
    return snapDuration(value, targets: [...clipJunctions(_clips), ...extra]);
  }

  void _seek(Duration t, {bool snap = false}) {
    final total = widget.project.duration;
    var next = t;
    if (next.isNegative) next = Duration.zero;
    if (next > total) next = total;
    if (snap) next = _snap(next);
    HapticFeedback.selectionClick();
    widget.onSeek?.call(next);
  }

  Future<void> _split() async {
    final controller = widget.controller;
    if (controller == null || !widget.canSplit) return;
    final index = clipIndexAt(_clips, widget.position);
    if (index == null) return;
    final clip = _clips[index];
    await controller.apply(
      SplitClipMutation(
        clipId: clip.id,
        at: widget.position,
        newClipId: const Uuid().v4(),
      ),
    );
    widget.onSplit?.call();
  }

  Future<void> _deleteSelected() async {
    final controller = widget.controller;
    final index = _selectedIndex;
    if (controller == null ||
        !widget.canDelete ||
        index == null ||
        _clips.length < 2) {
      return;
    }
    await controller.apply(RemoveClipMutation(_clips[index].id));
    setState(() => _localSelected = null);
  }

  Future<void> _trimClip({
    required int index,
    required bool start,
    required double deltaPx,
    required double pps,
  }) async {
    final controller = widget.controller;
    if (controller == null) return;
    final clip = _clips[index];
    final dt = Duration(microseconds: (deltaPx / pps * 1e6).round());
    final sourceDelta = Duration(
      microseconds: (dt.inMicroseconds * clip.speed).round(),
    );
    var trimStart = clip.trimStart;
    var trimEnd = clip.trimEnd;
    if (start) {
      trimStart += sourceDelta;
    } else {
      trimEnd += sourceDelta;
    }
    final minSource = Duration(
      microseconds: (kMinClipPiece.inMicroseconds * clip.speed).round(),
    );
    if (trimStart < Duration.zero) trimStart = Duration.zero;
    if (trimEnd > clip.sourceDuration) trimEnd = clip.sourceDuration;
    if (trimEnd - trimStart < minSource) return;
    final others = widget.project.duration - clip.trimmedDuration;
    final nextSpan = Duration(
      microseconds: ((trimEnd - trimStart).inMicroseconds / clip.speed).round(),
    );
    if (others + nextSpan > widget.maxDuration) return;
    await controller.applyLive(
      UpdateClipTrimMutation(
        clipId: clip.id,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
    final prefix = prefixBeforeClip(controller.project.clips, index);
    _seek(
      start ? prefix : prefix + controller.project.clips[index].trimmedDuration,
    );
  }

  Future<void> _roll({
    required int leftIndex,
    required double deltaPx,
    required double pps,
  }) async {
    final controller = widget.controller;
    if (controller == null) return;
    final prefix = prefixBeforeClip(_clips, leftIndex);
    final current = prefix + _clips[leftIndex].trimmedDuration;
    var junction =
        current + Duration(microseconds: (deltaPx / pps * 1e6).round());
    junction = _snap(junction, extra: [widget.position]);
    final rolled = rollJunction(
      clips: _clips,
      leftIndex: leftIndex,
      junction: junction,
    );
    if (rolled == null) return;
    await controller.applyLive(SetClipsMutation(rolled));
    _seek(prefixBeforeClip(rolled, leftIndex + 1));
  }

  @override
  Widget build(BuildContext context) {
    if (_clips.isEmpty) return const SizedBox.shrink();
    final total = widget.project.duration;
    final totalMs = total.inMilliseconds.clamp(1, 600000);
    final editable = widget.controller != null;
    final splitEnabled =
        editable &&
        widget.canSplit &&
        splitLegacyClip(
              clip: _clips[clipIndexAt(_clips, widget.position) ?? 0],
              prefix: prefixBeforeClip(
                _clips,
                clipIndexAt(_clips, widget.position) ?? 0,
              ),
              at: widget.position,
              newClipId: 'preview',
            ) !=
            null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          theme: widget.theme,
          l10n: _l10n,
          position: widget.position,
          duration: total,
          canSplit: splitEnabled,
          canDelete:
              editable &&
              widget.canDelete &&
              _clips.length > 1 &&
              _selectedIndex != null,
          onSplit: () => unawaited(_split()),
          onDelete: () => unawaited(_deleteSelected()),
          onZoomIn: () => setState(() => _zoom = (_zoom * 1.35).clamp(0.4, 8)),
          onZoomOut: () => setState(() => _zoom = (_zoom / 1.35).clamp(0.4, 8)),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final viewW = constraints.maxWidth;
            final fitted = viewW / math.max(totalMs / 1000.0, 0.5);
            final pps = (fitted * _zoom).clamp(_minPps, _maxPps);
            final trackW = math.max(viewW, (totalMs / 1000.0) * pps);
            return SizedBox(
              height: _trackHeight + 18,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: trackW,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 16,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _seek(
                            Duration(
                              milliseconds: (d.localPosition.dx / pps * 1000)
                                  .round(),
                            ),
                            snap: true,
                          ),
                          onHorizontalDragUpdate: (d) => _seek(
                            Duration(
                              milliseconds: (d.localPosition.dx / pps * 1000)
                                  .round(),
                            ),
                          ),
                          child: CustomPaint(
                            painter: _RulerPainter(
                              pps: pps,
                              duration: total,
                              muted: widget.theme.muted,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 16,
                        height: _trackHeight,
                        width: trackW,
                        child: _ClipRow(
                          theme: widget.theme,
                          clips: _clips,
                          pps: pps,
                          selectedIndex: _selectedIndex,
                          frameExtractor: widget.frameExtractor,
                          editable: editable,
                          onSelect: (i) {
                            setState(() => _localSelected = i);
                            widget.onSelectClip?.call(i);
                          },
                          onTrim: (index, start, dx) => unawaited(
                            _trimClip(
                              index: index,
                              start: start,
                              deltaPx: dx,
                              pps: pps,
                            ),
                          ),
                          onRoll: (left, dx) => unawaited(
                            _roll(leftIndex: left, deltaPx: dx, pps: pps),
                          ),
                          onTrimEnd: () => widget.controller?.endLive(),
                        ),
                      ),
                      Positioned(
                        left:
                            (widget.position.inMilliseconds / 1000.0) * pps - 1,
                        top: 12,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(width: 2, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.theme,
    required this.l10n,
    required this.position,
    required this.duration,
    required this.canSplit,
    required this.canDelete,
    required this.onSplit,
    required this.onDelete,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final ComposerTheme theme;
  final ComposerToolL10n l10n;
  final Duration position;
  final Duration duration;
  final bool canSplit;
  final bool canDelete;
  final VoidCallback onSplit;
  final VoidCallback onDelete;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          IconButton(
            key: const Key('timeline-split'),
            tooltip: l10n.text('splitClip'),
            onPressed: canSplit ? onSplit : null,
            icon: Icon(
              Icons.content_cut,
              size: 18,
              color: canSplit ? Colors.white : Colors.white24,
            ),
          ),
          IconButton(
            key: const Key('timeline-delete'),
            tooltip: l10n.text('deleteClip'),
            onPressed: canDelete ? onDelete : null,
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: canDelete ? Colors.white : Colors.white24,
            ),
          ),
          const Spacer(),
          Text(
            '${_fmt(position)} / ${_fmt(duration)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            key: const Key('timeline-zoom-out'),
            tooltip: l10n.text('zoomOut'),
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, size: 18, color: Colors.white70),
          ),
          IconButton(
            key: const Key('timeline-zoom-in'),
            tooltip: l10n.text('zoomIn'),
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, size: 18, color: Colors.white70),
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

class _ClipRow extends StatelessWidget {
  const _ClipRow({
    required this.theme,
    required this.clips,
    required this.pps,
    required this.selectedIndex,
    required this.frameExtractor,
    required this.editable,
    required this.onSelect,
    required this.onTrim,
    required this.onRoll,
    required this.onTrimEnd,
  });

  final ComposerTheme theme;
  final List<TimelineClip> clips;
  final double pps;
  final int? selectedIndex;
  final FrameExtractorPort frameExtractor;
  final bool editable;
  final ValueChanged<int> onSelect;
  final void Function(int index, bool start, double deltaPx) onTrim;
  final void Function(int leftIndex, double deltaPx) onRoll;
  final VoidCallback onTrimEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < clips.length; i++)
          _ClipCell(
            theme: theme,
            clip: clips[i],
            width: math.max(
              8,
              clips[i].trimmedDuration.inMilliseconds / 1000.0 * pps,
            ),
            selected: selectedIndex == i,
            frameExtractor: frameExtractor,
            showLeft: editable && i == 0,
            showRight: editable && i == clips.length - 1,
            showJunction: editable && i < clips.length - 1,
            onSelect: () => onSelect(i),
            onTrimStart: (dx) => onTrim(i, true, dx),
            onTrimEndHandle: (dx) => onTrim(i, false, dx),
            onRoll: (dx) => onRoll(i, dx),
            onDragEnd: onTrimEnd,
          ),
      ],
    );
  }
}

class _ClipCell extends StatelessWidget {
  const _ClipCell({
    required this.theme,
    required this.clip,
    required this.width,
    required this.selected,
    required this.frameExtractor,
    required this.showLeft,
    required this.showRight,
    required this.showJunction,
    required this.onSelect,
    required this.onTrimStart,
    required this.onTrimEndHandle,
    required this.onRoll,
    required this.onDragEnd,
  });

  final ComposerTheme theme;
  final TimelineClip clip;
  final double width;
  final bool selected;
  final FrameExtractorPort frameExtractor;
  final bool showLeft;
  final bool showRight;
  final bool showJunction;
  final VoidCallback onSelect;
  final ValueChanged<double> onTrimStart;
  final ValueChanged<double> onTrimEndHandle;
  final ValueChanged<double> onRoll;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final count = (width / 28).round().clamp(2, 16);
    return SizedBox(
      width: width,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onSelect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? theme.accent : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Filmstrip(
                  sourcePath: clip.sourcePath,
                  frameExtractor: frameExtractor,
                  start: clip.trimStart,
                  end: clip.trimEnd,
                  height: 56,
                  count: count,
                  accent: theme.accent,
                ),
              ),
            ),
          ),
          if (showLeft)
            _Handle(
              alignment: Alignment.centerLeft,
              color: theme.accent,
              onUpdate: onTrimStart,
              onEnd: onDragEnd,
            ),
          if (showRight)
            _Handle(
              alignment: Alignment.centerRight,
              color: theme.accent,
              onUpdate: onTrimEndHandle,
              onEnd: onDragEnd,
            ),
          if (showJunction)
            _Handle(
              alignment: Alignment.centerRight,
              color: Colors.white,
              onUpdate: onRoll,
              onEnd: onDragEnd,
            ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.alignment,
    required this.color,
    required this.onUpdate,
    required this.onEnd,
  });

  final Alignment alignment;
  final Color color;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onUpdate(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        child: Container(
          width: 16,
          height: 56,
          alignment: Alignment.center,
          child: Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.pps,
    required this.duration,
    required this.muted,
  });

  final double pps;
  final Duration duration;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = muted.withValues(alpha: 0.7);
    final seconds = duration.inMilliseconds / 1000.0;
    final step = seconds > 20 ? 5 : 1;
    for (var s = 0; s <= seconds.ceil(); s += step) {
      final x = s * pps;
      canvas.drawLine(Offset(x, 10), Offset(x, 16), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.pps != pps || old.duration != duration;
}

class _FallbackL10n implements ComposerToolL10n {
  const _FallbackL10n();

  @override
  String text(String key) => key;

  @override
  String toolLabel(ComposerFeature feature) => feature.name;
}

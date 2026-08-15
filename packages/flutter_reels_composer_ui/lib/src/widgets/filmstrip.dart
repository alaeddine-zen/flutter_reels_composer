import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// Horizontal strip of extracted video frames (TikTok-style trim/cover).
class Filmstrip extends StatefulWidget {
  const Filmstrip({
    super.key,
    required this.sourcePath,
    this.start = Duration.zero,
    this.end,
    this.height = 56,
    this.count = 10,
    this.range,
    this.accent,
    this.frameExtractor = const NoopFrameExtractor(),
    this.stillImage = false,
  });

  final String sourcePath;
  final Duration start;
  final Duration? end;
  final double height;
  final int count;

  /// Optional selected trim range highlighted over the strip (0–1 relative).
  final RangeValues? range;
  final Color? accent;
  final FrameExtractorPort frameExtractor;

  /// Tile [sourcePath] itself (photo clips) instead of extracting video frames.
  final bool stillImage;

  @override
  State<Filmstrip> createState() => _FilmstripState();
}

class _FilmstripState extends State<Filmstrip> {
  List<File> _frames = const [];
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant Filmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourcePath != widget.sourcePath ||
        oldWidget.start != widget.start ||
        oldWidget.end != widget.end ||
        oldWidget.count != widget.count ||
        oldWidget.frameExtractor != widget.frameExtractor ||
        oldWidget.stillImage != widget.stillImage) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (widget.stillImage) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _frames = const [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final frames = await widget.frameExtractor.extract(
      sourcePath: widget.sourcePath,
      start: widget.start,
      end: widget.end,
      count: widget.count,
      height: widget.height.round(),
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _frames = frames;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? const Color(0xFFFF2D55);
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading && _frames.isEmpty)
              const ColoredBox(
                color: Colors.white10,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (widget.stillImage)
              Image.file(
                File(widget.sourcePath),
                fit: BoxFit.cover,
                height: widget.height,
                width: double.infinity,
                cacheHeight: (widget.height * 2).round(),
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.white12),
              )
            else if (_frames.isEmpty)
              ColoredBox(
                color: Colors.white10,
                child: Row(
                  children: List.generate(
                    widget.count,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        color: Colors.white.withValues(
                          alpha: 0.06 + (i % 3) * 0.03,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  for (final f in _frames)
                    Expanded(
                      child: Image.file(
                        f,
                        fit: BoxFit.cover,
                        height: widget.height,
                        cacheHeight: (widget.height * 2).round(),
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Colors.white12),
                      ),
                    ),
                ],
              ),
            if (widget.range != null)
              _RangeOverlay(range: widget.range!, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _RangeOverlay extends StatelessWidget {
  const _RangeOverlay({required this.range, required this.accent});

  final RangeValues range;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final left = (range.start.clamp(0.0, 1.0)) * w;
        final right = (range.end.clamp(0.0, 1.0)) * w;
        return Stack(
          children: [
            Positioned(
              left: 0,
              width: left,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
            Positioned(
              left: right,
              right: 0,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
            Positioned(
              left: left,
              width: (right - left).clamp(2.0, w),
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: accent, width: 3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Single cached frame thumbnail.
class VideoFrameThumb extends StatefulWidget {
  const VideoFrameThumb({
    super.key,
    required this.sourcePath,
    this.at = Duration.zero,
    this.size = 48,
    this.borderRadius = 8,
    this.frameExtractor = const NoopFrameExtractor(),
  });

  final String sourcePath;
  final Duration at;
  final double size;
  final double borderRadius;
  final FrameExtractorPort frameExtractor;

  @override
  State<VideoFrameThumb> createState() => _VideoFrameThumbState();
}

class _VideoFrameThumbState extends State<VideoFrameThumb> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoFrameThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourcePath != widget.sourcePath ||
        oldWidget.at != widget.at ||
        oldWidget.frameExtractor != widget.frameExtractor) {
      _load();
    }
  }

  Future<void> _load() async {
    final f = await widget.frameExtractor.extractOne(
      sourcePath: widget.sourcePath,
      at: widget.at,
      height: (widget.size * 2).round(),
    );
    if (!mounted) return;
    setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _file == null
            ? const ColoredBox(color: Colors.white12)
            : Image.file(_file!, fit: BoxFit.cover),
      ),
    );
  }
}

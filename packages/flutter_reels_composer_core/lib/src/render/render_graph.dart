import 'package:equatable/equatable.dart';

import '../domain/effects/effect_registry.dart';
import '../domain/project/audio_track.dart';
import '../domain/project/duet_layout.dart';
import '../domain/project/project_document.dart';
import '../domain/project/visual_layer.dart';
import '../domain/timeline/clip.dart';
import '../domain/timeline/timeline.dart';
import 'color_grade.dart';

/// One evaluated clip on the composed timeline.
class RenderVideoSegment extends Equatable {
  const RenderVideoSegment({
    required this.clipId,
    required this.sourcePath,
    required this.sourceDuration,
    required this.trimStart,
    required this.trimEnd,
    required this.speed,
    required this.timelineStart,
    required this.timelineDuration,
    this.isImage = false,
  });

  final String clipId;
  final String sourcePath;
  final Duration sourceDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final double speed;
  final Duration timelineStart;
  final Duration timelineDuration;
  final bool isImage;

  Duration get sourceSpan {
    final raw = trimEnd - trimStart;
    if (raw.isNegative) return Duration.zero;
    return raw;
  }

  bool get isTrimmed => trimStart > Duration.zero || trimEnd < sourceDuration;

  bool contains(Duration position) {
    final end = timelineStart + timelineDuration;
    if (position < timelineStart) return false;
    if (position < end) return true;
    return false;
  }

  @override
  List<Object?> get props => [
    clipId,
    sourcePath,
    sourceDuration,
    trimStart,
    trimEnd,
    speed,
    timelineStart,
    timelineDuration,
    isImage,
  ];
}

class RenderDuet extends Equatable {
  const RenderDuet({required this.layout, required this.parentVideoPath});

  final DuetLayout layout;
  final String parentVideoPath;

  @override
  List<Object?> get props => [layout, parentVideoPath];
}

/// Backend-agnostic evaluation of a [ProjectDocument] at any playhead `t`.
///
/// Preview and export must consume the same graph. FFmpeg-specific commands
/// do **not** belong here.
class RenderGraph extends Equatable {
  const RenderGraph({
    required this.segments,
    required this.duration,
    required this.colorGrade,
    this.textOverlays = const [],
    this.stickerOverlays = const [],
    this.audioTracks = const [],
    this.duet,
  });

  final List<RenderVideoSegment> segments;
  final Duration duration;
  final ColorGrade colorGrade;
  final List<VisualLayer> textOverlays;
  final List<VisualLayer> stickerOverlays;
  final List<AudioTrack> audioTracks;
  final RenderDuet? duet;

  AudioTrack? get originalAudio {
    for (final t in audioTracks) {
      if (t.kind == AudioTrackKind.original) return t;
    }
    return null;
  }

  AudioTrack? get music {
    for (final t in audioTracks) {
      if (t.kind == AudioTrackKind.music) return t;
    }
    return null;
  }

  List<AudioTrack> get voiceovers => audioTracks
      .where(
        (t) =>
            t.kind == AudioTrackKind.voiceover &&
            (t.sourcePath?.isNotEmpty ?? false),
      )
      .toList();

  factory RenderGraph.fromProject(
    ProjectDocument project, {
    EffectRegistry? registry,
  }) {
    final timeline = Timeline.fromDocument(project);
    final segments = <RenderVideoSegment>[];
    var cursor = Duration.zero;
    for (final clip in timeline.mediaClips) {
      final segment = switch (clip) {
        VideoClip() => RenderVideoSegment(
          clipId: clip.id,
          sourcePath: clip.media.path,
          sourceDuration: clip.media.duration,
          trimStart: clip.trimStart,
          trimEnd: clip.trimEnd,
          speed: clip.speed,
          timelineStart: cursor,
          timelineDuration: clip.trimmedDuration,
        ),
        ImageClip() => RenderVideoSegment(
          clipId: clip.id,
          sourcePath: clip.media.path,
          sourceDuration: clip.displayDuration,
          trimStart: Duration.zero,
          trimEnd: clip.displayDuration,
          speed: clip.speed,
          timelineStart: cursor,
          timelineDuration: clip.trimmedDuration,
          isImage: true,
        ),
      };
      segments.add(segment);
      cursor += segment.timelineDuration;
    }

    RenderDuet? duet;
    final parent = project.parentVideoPath;
    if (project.duetLayout.isActive && parent != null && parent.isNotEmpty) {
      duet = RenderDuet(layout: project.duetLayout, parentVideoPath: parent);
    }

    final text = <VisualLayer>[];
    final stickers = <VisualLayer>[];
    for (final layer in project.layers) {
      switch (layer.type) {
        case VisualLayerType.text:
          if (layer.text?.isNotEmpty ?? false) text.add(layer);
        case VisualLayerType.sticker:
          stickers.add(layer);
        case VisualLayerType.drawing:
          stickers.add(layer);
      }
    }

    return RenderGraph(
      segments: segments,
      duration: cursor,
      colorGrade: ColorGrade.fromProject(project, registry: registry),
      textOverlays: text,
      stickerOverlays: stickers,
      audioTracks: project.audioTracks,
      duet: duet,
    );
  }

  /// Clip covering [position]. If [position] is exactly [duration], returns
  /// the last segment.
  RenderVideoSegment? segmentAt(Duration position) {
    if (segments.isEmpty) return null;
    if (position < Duration.zero) return segments.first;
    for (final segment in segments) {
      if (segment.contains(position)) return segment;
    }
    if (position >= duration) return segments.last;
    return null;
  }

  List<VisualLayer> overlaysAt(Duration position) {
    return [
      for (final layer in textOverlays)
        if (layer.visibleAt(position)) layer,
      for (final layer in stickerOverlays)
        if (layer.visibleAt(position)) layer,
    ];
  }

  @override
  List<Object?> get props => [
    segments,
    duration,
    colorGrade,
    textOverlays,
    stickerOverlays,
    audioTracks,
    duet,
  ];
}

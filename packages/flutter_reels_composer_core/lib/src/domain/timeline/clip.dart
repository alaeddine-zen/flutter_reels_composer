import 'package:equatable/equatable.dart';

import '../media/media_ref.dart';
import '../project/timeline_clip.dart';

/// Default on-timeline length for a still image that has no explicit duration.
const Duration kDefaultImageClipDuration = Duration(seconds: 3);

/// A clip on the video track: either a trimmed video or a timed still image.
sealed class TimelineMediaClip extends Equatable {
  const TimelineMediaClip();

  String get id;
  MediaRef get media;
  double get speed;
  Duration get trimmedDuration;

  TimelineClip toLegacyClip();
  Map<String, dynamic> toJson();

  factory TimelineMediaClip.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'video';
    if (type == 'image') return ImageClip.fromJson(json);
    return VideoClip.fromJson(json);
  }

  factory TimelineMediaClip.fromLegacy(TimelineClip clip) {
    if (clip.kind == TimelineClipKind.image) {
      return ImageClip.fromLegacy(clip);
    }
    return VideoClip.fromLegacy(clip);
  }
}

class VideoClip extends TimelineMediaClip {
  VideoClip({
    required this.id,
    required this.media,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.speed = 1.0,
  }) : trimEnd = trimEnd ?? media.duration;

  @override
  final String id;
  @override
  final MediaRef media;
  final Duration trimStart;
  final Duration trimEnd;
  @override
  final double speed;

  Duration get sourceSpan {
    final raw = trimEnd - trimStart;
    if (raw.isNegative) return Duration.zero;
    return raw;
  }

  @override
  Duration get trimmedDuration {
    final raw = sourceSpan;
    if (raw == Duration.zero) return Duration.zero;
    return Duration(microseconds: (raw.inMicroseconds / speed).round());
  }

  factory VideoClip.fromLegacy(TimelineClip clip) {
    return VideoClip(
      id: clip.id,
      media: MediaRef(
        path: clip.sourcePath,
        kind: MediaKind.video,
        duration: clip.sourceDuration,
      ),
      trimStart: clip.trimStart,
      trimEnd: clip.trimEnd,
      speed: clip.speed,
    );
  }

  @override
  TimelineClip toLegacyClip() {
    return TimelineClip(
      id: id,
      sourcePath: media.path,
      sourceDuration: media.duration,
      trimStart: trimStart,
      trimEnd: trimEnd,
      speed: speed,
      kind: TimelineClipKind.video,
    );
  }

  VideoClip copyWith({
    String? id,
    MediaRef? media,
    Duration? trimStart,
    Duration? trimEnd,
    double? speed,
  }) {
    return VideoClip(
      id: id ?? this.id,
      media: media ?? this.media,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'video',
    'id': id,
    'media': media.toJson(),
    'trimStartMs': trimStart.inMilliseconds,
    'trimEndMs': trimEnd.inMilliseconds,
    'speed': speed,
  };

  factory VideoClip.fromJson(Map<String, dynamic> json) {
    final media = MediaRef.fromJson(
      Map<String, dynamic>.from(json['media'] as Map),
    );
    return VideoClip(
      id: json['id'] as String,
      media: media.copyWith(kind: MediaKind.video),
      trimStart: Duration(milliseconds: json['trimStartMs'] as int? ?? 0),
      trimEnd: Duration(
        milliseconds:
            json['trimEndMs'] as int? ?? media.duration.inMilliseconds,
      ),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [id, media, trimStart, trimEnd, speed];
}

class ImageClip extends TimelineMediaClip {
  const ImageClip({
    required this.id,
    required this.media,
    this.displayDuration = kDefaultImageClipDuration,
    this.speed = 1.0,
  });

  @override
  final String id;
  @override
  final MediaRef media;
  final Duration displayDuration;
  @override
  final double speed;

  @override
  Duration get trimmedDuration {
    if (displayDuration == Duration.zero) return Duration.zero;
    return Duration(
      microseconds: (displayDuration.inMicroseconds / speed).round(),
    );
  }

  factory ImageClip.fromLegacy(TimelineClip clip) {
    final span = clip.sourceSpan;
    return ImageClip(
      id: clip.id,
      media: MediaRef(
        path: clip.sourcePath,
        kind: MediaKind.image,
        duration: clip.sourceDuration,
      ),
      displayDuration: span == Duration.zero ? kDefaultImageClipDuration : span,
      speed: clip.speed,
    );
  }

  @override
  TimelineClip toLegacyClip() {
    return TimelineClip(
      id: id,
      sourcePath: media.path,
      sourceDuration: displayDuration,
      trimStart: Duration.zero,
      trimEnd: displayDuration,
      speed: speed,
      kind: TimelineClipKind.image,
    );
  }

  ImageClip copyWith({
    String? id,
    MediaRef? media,
    Duration? displayDuration,
    double? speed,
  }) {
    return ImageClip(
      id: id ?? this.id,
      media: media ?? this.media,
      displayDuration: displayDuration ?? this.displayDuration,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'id': id,
    'media': media.toJson(),
    'displayDurationMs': displayDuration.inMilliseconds,
    'speed': speed,
  };

  factory ImageClip.fromJson(Map<String, dynamic> json) {
    final media = MediaRef.fromJson(
      Map<String, dynamic>.from(json['media'] as Map),
    );
    return ImageClip(
      id: json['id'] as String,
      media: media.copyWith(kind: MediaKind.image),
      displayDuration: Duration(
        milliseconds:
            json['displayDurationMs'] as int? ??
            kDefaultImageClipDuration.inMilliseconds,
      ),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [id, media, displayDuration, speed];
}

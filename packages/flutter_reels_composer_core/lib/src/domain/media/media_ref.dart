import 'package:equatable/equatable.dart';

/// Kind of a referenced media file. Paths only — never embed bytes in JSON.
enum MediaKind { video, image, audio }

/// Pointer to a local media file. Drafts persist this, not the file contents.
class MediaRef extends Equatable {
  const MediaRef({
    required this.path,
    required this.kind,
    this.duration = Duration.zero,
    this.width,
    this.height,
  });

  final String path;
  final MediaKind kind;
  final Duration duration;
  final int? width;
  final int? height;

  MediaRef copyWith({
    String? path,
    MediaKind? kind,
    Duration? duration,
    int? width,
    int? height,
  }) {
    return MediaRef(
      path: path ?? this.path,
      kind: kind ?? this.kind,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'kind': kind.name,
    'durationMs': duration.inMilliseconds,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };

  factory MediaRef.fromJson(Map<String, dynamic> json) {
    return MediaRef(
      path: json['path'] as String,
      kind: MediaKind.values.byName(json['kind'] as String? ?? 'video'),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  @override
  List<Object?> get props => [path, kind, duration, width, height];
}

import 'package:equatable/equatable.dart';

class TimelineClip extends Equatable {
  const TimelineClip({
    required this.id,
    required this.sourcePath,
    required this.sourceDuration,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.speed = 1.0,
  }) : trimEnd = trimEnd ?? sourceDuration;

  final String id;
  final String sourcePath;
  final Duration sourceDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final double speed;

  Duration get trimmedDuration {
    final raw = sourceSpan;
    if (raw == Duration.zero) return Duration.zero;
    return Duration(microseconds: (raw.inMicroseconds / speed).round());
  }

  Duration get sourceSpan {
    final raw = trimEnd - trimStart;
    if (raw.isNegative) return Duration.zero;
    return raw;
  }

  TimelineClip copyWith({
    String? id,
    String? sourcePath,
    Duration? sourceDuration,
    Duration? trimStart,
    Duration? trimEnd,
    double? speed,
  }) {
    return TimelineClip(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      speed: speed ?? this.speed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourcePath': sourcePath,
    'sourceDurationMs': sourceDuration.inMilliseconds,
    'trimStartMs': trimStart.inMilliseconds,
    'trimEndMs': trimEnd.inMilliseconds,
    'speed': speed,
  };

  factory TimelineClip.fromJson(Map<String, dynamic> json) {
    return TimelineClip(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      sourceDuration: Duration(milliseconds: json['sourceDurationMs'] as int),
      trimStart: Duration(milliseconds: json['trimStartMs'] as int? ?? 0),
      trimEnd: Duration(milliseconds: json['trimEndMs'] as int),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sourcePath,
    sourceDuration,
    trimStart,
    trimEnd,
    speed,
  ];
}

import 'package:equatable/equatable.dart';

enum AudioTrackKind { original, music, voiceover }

class AudioTrack extends Equatable {
  const AudioTrack({
    required this.id,
    required this.kind,
    this.sourcePath,
    this.musicId,
    this.volume = 1.0,
    this.startOffset = Duration.zero,
  });

  final String id;
  final AudioTrackKind kind;
  final String? sourcePath;
  final String? musicId;
  final double volume;
  final Duration startOffset;

  AudioTrack copyWith({
    String? id,
    AudioTrackKind? kind,
    String? sourcePath,
    String? musicId,
    double? volume,
    Duration? startOffset,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      sourcePath: sourcePath ?? this.sourcePath,
      musicId: musicId ?? this.musicId,
      volume: volume ?? this.volume,
      startOffset: startOffset ?? this.startOffset,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'sourcePath': sourcePath,
    'musicId': musicId,
    'volume': volume,
    'startOffsetMs': startOffset.inMilliseconds,
  };

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'] as String,
      kind: AudioTrackKind.values.byName(json['kind'] as String),
      sourcePath: json['sourcePath'] as String?,
      musicId: json['musicId'] as String?,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      startOffset: Duration(milliseconds: json['startOffsetMs'] as int? ?? 0),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    sourcePath,
    musicId,
    volume,
    startOffset,
  ];
}

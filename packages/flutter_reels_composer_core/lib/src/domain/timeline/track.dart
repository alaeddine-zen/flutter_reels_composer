import 'package:equatable/equatable.dart';

import '../project/audio_track.dart';
import '../project/visual_layer.dart';
import 'clip.dart';

const String kDefaultVideoTrackId = 'video-0';
const String kDefaultOverlayTrackId = 'overlay-0';

class VideoTrack extends Equatable {
  const VideoTrack({this.id = kDefaultVideoTrackId, this.clips = const []});

  final String id;
  final List<TimelineMediaClip> clips;

  Duration get duration => clips.fold<Duration>(
    Duration.zero,
    (sum, clip) => sum + clip.trimmedDuration,
  );

  VideoTrack copyWith({String? id, List<TimelineMediaClip>? clips}) {
    return VideoTrack(id: id ?? this.id, clips: clips ?? this.clips);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clips': clips.map((c) => c.toJson()).toList(),
  };

  factory VideoTrack.fromJson(Map<String, dynamic> json) {
    return VideoTrack(
      id: json['id'] as String? ?? kDefaultVideoTrackId,
      clips: (json['clips'] as List? ?? const [])
          .map(
            (e) =>
                TimelineMediaClip.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, clips];
}

class OverlayTrack extends Equatable {
  const OverlayTrack({
    this.id = kDefaultOverlayTrackId,
    this.layers = const [],
  });

  final String id;
  final List<VisualLayer> layers;

  OverlayTrack copyWith({String? id, List<VisualLayer>? layers}) {
    return OverlayTrack(id: id ?? this.id, layers: layers ?? this.layers);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory OverlayTrack.fromJson(Map<String, dynamic> json) {
    return OverlayTrack(
      id: json['id'] as String? ?? kDefaultOverlayTrackId,
      layers: (json['layers'] as List? ?? const [])
          .map((e) => VisualLayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, layers];
}

/// Typed list wrapper so hosts can reason about multiple audio tracks.
class AudioTrackList extends Equatable {
  const AudioTrackList({this.tracks = const []});

  final List<AudioTrack> tracks;

  AudioTrack? get original {
    for (final t in tracks) {
      if (t.kind == AudioTrackKind.original) return t;
    }
    return null;
  }

  AudioTrack? get music {
    for (final t in tracks) {
      if (t.kind == AudioTrackKind.music) return t;
    }
    return null;
  }

  List<AudioTrack> get voiceovers =>
      tracks.where((t) => t.kind == AudioTrackKind.voiceover).toList();

  Map<String, dynamic> toJson() => {
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory AudioTrackList.fromJson(Map<String, dynamic> json) {
    return AudioTrackList(
      tracks: (json['tracks'] as List? ?? const [])
          .map((e) => AudioTrack.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [tracks];
}

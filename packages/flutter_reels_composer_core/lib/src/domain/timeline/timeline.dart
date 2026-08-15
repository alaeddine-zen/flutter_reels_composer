import 'package:equatable/equatable.dart';

import '../project/audio_track.dart';
import '../project/project_document.dart';
import '../project/timeline_clip.dart';
import '../project/visual_layer.dart';
import 'clip.dart';
import 'track.dart';

/// Structured view of a [ProjectDocument]. Derived — not a second store.
class Timeline extends Equatable {
  const Timeline({
    this.videoTracks = const [],
    this.audioTracks = const [],
    this.overlayTracks = const [],
  });

  final List<VideoTrack> videoTracks;
  final List<AudioTrack> audioTracks;
  final List<OverlayTrack> overlayTracks;

  AudioTrackList get audioTrackList => AudioTrackList(tracks: audioTracks);

  VideoTrack get primaryVideoTrack =>
      videoTracks.isEmpty ? const VideoTrack() : videoTracks.first;

  List<TimelineMediaClip> get mediaClips => primaryVideoTrack.clips;

  Duration get duration => primaryVideoTrack.duration;

  factory Timeline.fromDocument(ProjectDocument document) {
    return Timeline(
      videoTracks: [
        VideoTrack(
          clips: document.clips
              .map(TimelineMediaClip.fromLegacy)
              .toList(growable: false),
        ),
      ],
      audioTracks: document.audioTracks,
      overlayTracks: [OverlayTrack(layers: document.layers)],
    );
  }

  List<TimelineClip> toLegacyClips() {
    return [
      for (final track in videoTracks)
        for (final clip in track.clips) clip.toLegacyClip(),
    ];
  }

  List<VisualLayer> toLegacyLayers() {
    return [for (final track in overlayTracks) ...track.layers];
  }

  Map<String, dynamic> toJson() => {
    'videoTracks': videoTracks.map((t) => t.toJson()).toList(),
    'audioTracks': audioTracks.map((t) => t.toJson()).toList(),
    'overlayTracks': overlayTracks.map((t) => t.toJson()).toList(),
  };

  factory Timeline.fromJson(Map<String, dynamic> json) {
    final audioRaw = json['audioTracks'];
    final audio = <AudioTrack>[];
    if (audioRaw is List) {
      for (final item in audioRaw) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map.containsKey('tracks')) {
          audio.addAll(AudioTrackList.fromJson(map).tracks);
        } else {
          audio.add(AudioTrack.fromJson(map));
        }
      }
    }
    return Timeline(
      videoTracks: (json['videoTracks'] as List? ?? const [])
          .map((e) => VideoTrack.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      audioTracks: audio,
      overlayTracks: (json['overlayTracks'] as List? ?? const [])
          .map(
            (e) => OverlayTrack.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [videoTracks, audioTracks, overlayTracks];
}

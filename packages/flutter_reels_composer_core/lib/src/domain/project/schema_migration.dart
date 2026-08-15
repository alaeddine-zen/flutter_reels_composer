import '../timeline/clip.dart';
import '../timeline/timeline.dart';
import '../timeline/track.dart';
import 'audio_track.dart';
import 'schema.dart';
import 'timeline_clip.dart';
import 'visual_layer.dart';

/// Migrates a [ProjectDocument] JSON map to [kProjectSchemaVersion].
///
/// v1: missing `schemaVersion`. v2: flat clips/layers/audioTracks.
/// v3: dual-write of a structured `timeline` block plus optional clip `kind`.
Map<String, dynamic> migrateProjectJson(Map<String, dynamic> json) {
  final version = json['schemaVersion'] as int? ?? 1;
  if (version < 1 || version > kProjectSchemaVersion) {
    throw UnsupportedProjectSchemaException(version);
  }
  var data = Map<String, dynamic>.from(json);
  if (version < 2) {
    data['schemaVersion'] = 2;
  }
  if ((data['schemaVersion'] as int) < 3) {
    data = migrateProjectJsonV2ToV3(data);
  }
  data['schemaVersion'] = kProjectSchemaVersion;
  return data;
}

Map<String, dynamic> migrateProjectJsonV2ToV3(Map<String, dynamic> json) {
  final data = Map<String, dynamic>.from(json);
  final clips = (data['clips'] as List? ?? const []).map((e) {
    final map = Map<String, dynamic>.from(e as Map);
    map.putIfAbsent('kind', () => TimelineClipKind.video.name);
    return map;
  }).toList();
  data['clips'] = clips;

  final layers = (data['layers'] as List? ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final audio = (data['audioTracks'] as List? ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  data['timeline'] ??= timelineJsonFromFlat(
    clipMaps: clips,
    layerMaps: layers,
    audioMaps: audio,
  );
  data['schemaVersion'] = 3;
  return data;
}

Map<String, dynamic> timelineJsonFromFlat({
  required List<Map<String, dynamic>> clipMaps,
  required List<Map<String, dynamic>> layerMaps,
  required List<Map<String, dynamic>> audioMaps,
}) {
  final clips = clipMaps.map(TimelineClip.fromJson).toList();
  final layers = layerMaps.map(VisualLayer.fromJson).toList();
  final audio = audioMaps.map(AudioTrack.fromJson).toList();
  return Timeline(
    videoTracks: [
      VideoTrack(clips: clips.map(TimelineMediaClip.fromLegacy).toList()),
    ],
    audioTracks: audio,
    overlayTracks: [OverlayTrack(layers: layers)],
  ).toJson();
}

List<TimelineClip> clipsFromTimelineJson(Map<String, dynamic> timeline) {
  return Timeline.fromJson(timeline).toLegacyClips();
}

List<VisualLayer> layersFromTimelineJson(Map<String, dynamic> timeline) {
  return Timeline.fromJson(timeline).toLegacyLayers();
}

List<AudioTrack> audioFromTimelineJson(Map<String, dynamic> timeline) {
  return Timeline.fromJson(timeline).audioTracks;
}

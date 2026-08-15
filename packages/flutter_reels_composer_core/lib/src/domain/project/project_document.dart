import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'audio_track.dart';
import 'cover_choice.dart';
import 'duet_layout.dart';
import 'effect_instance.dart';
import 'schema.dart';
import 'timeline_clip.dart';
import 'video_settings.dart';
import 'visual_layer.dart';

class ProjectDocument extends Equatable {
  const ProjectDocument({
    required this.id,
    required this.settings,
    this.schemaVersion = kProjectSchemaVersion,
    this.clips = const [],
    this.layers = const [],
    this.audioTracks = const [],
    this.effects = const [],
    this.cover = const CoverChoice(),
    this.extras = const {},
    this.updatedAt,
  });

  final int schemaVersion;
  final String id;
  final VideoSettings settings;
  final List<TimelineClip> clips;
  final List<VisualLayer> layers;
  final List<AudioTrack> audioTracks;
  final List<EffectInstance> effects;
  final CoverChoice cover;
  final Map<String, dynamic> extras;
  final DateTime? updatedAt;

  factory ProjectDocument.empty({VideoSettings? settings}) {
    return ProjectDocument(
      id: const Uuid().v4(),
      settings: settings ?? VideoSettings.vertical9x16,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  factory ProjectDocument.fromClip({
    required TimelineClip clip,
    VideoSettings? settings,
  }) {
    return ProjectDocument(
      id: const Uuid().v4(),
      settings: settings ?? VideoSettings.vertical9x16,
      clips: [clip],
      audioTracks: [
        AudioTrack(id: const Uuid().v4(), kind: AudioTrackKind.original),
      ],
      effects: [
        EffectInstance(
          id: const Uuid().v4(),
          effectId: 'normal',
          category: 'color',
        ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Duration get duration {
    if (clips.isEmpty) return Duration.zero;
    return clips.fold<Duration>(
      Duration.zero,
      (sum, c) => sum + c.trimmedDuration,
    );
  }

  String? get primarySourcePath =>
      clips.isEmpty ? null : clips.first.sourcePath;

  DuetLayout get duetLayout =>
      DuetLayoutX.parse(extras['duetLayout'] as String?);

  String? get parentVideoPath => extras['parentVideoPath'] as String?;

  String? get templateId => extras['templateId'] as String?;

  bool get hasSpeedChange => clips.any((c) => (c.speed - 1.0).abs() > 0.001);

  String? get activeFilterId {
    for (final e in effects) {
      if (e.category == 'color') return e.effectId;
    }
    return null;
  }

  double get activeFilterIntensity {
    for (final e in effects) {
      if (e.category == 'color') {
        final v = e.params['intensity'];
        if (v is num) return v.toDouble().clamp(0.0, 1.0);
        return 1.0;
      }
    }
    return 1.0;
  }

  ProjectDocument copyWith({
    int? schemaVersion,
    String? id,
    VideoSettings? settings,
    List<TimelineClip>? clips,
    List<VisualLayer>? layers,
    List<AudioTrack>? audioTracks,
    List<EffectInstance>? effects,
    CoverChoice? cover,
    Map<String, dynamic>? extras,
    DateTime? updatedAt,
  }) {
    return ProjectDocument(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      settings: settings ?? this.settings,
      clips: clips ?? this.clips,
      layers: layers ?? this.layers,
      audioTracks: audioTracks ?? this.audioTracks,
      effects: effects ?? this.effects,
      cover: cover ?? this.cover,
      extras: extras ?? this.extras,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ProjectDocument touch() => copyWith(updatedAt: DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'settings': settings.toJson(),
    'clips': clips.map((e) => e.toJson()).toList(),
    'layers': layers.map((e) => e.toJson()).toList(),
    'audioTracks': audioTracks.map((e) => e.toJson()).toList(),
    'effects': effects.map((e) => e.toJson()).toList(),
    'cover': cover.toJson(),
    'extras': extras,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 1;
    if (version < 1 || version > kProjectSchemaVersion) {
      throw UnsupportedProjectSchemaException(version);
    }
    return ProjectDocument(
      schemaVersion: kProjectSchemaVersion,
      id: json['id'] as String,
      settings: VideoSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map),
      ),
      clips: (json['clips'] as List? ?? const [])
          .map(
            (e) => TimelineClip.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      layers: (json['layers'] as List? ?? const [])
          .map((e) => VisualLayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      audioTracks: (json['audioTracks'] as List? ?? const [])
          .map((e) => AudioTrack.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      effects: (json['effects'] as List? ?? const [])
          .map(
            (e) => EffectInstance.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      cover: CoverChoice.fromJson(
        Map<String, dynamic>.from(json['cover'] as Map? ?? const {}),
      ),
      extras: Map<String, dynamic>.from(json['extras'] as Map? ?? const {}),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  ProjectSnapshot toSnapshot() => ProjectSnapshot(toJson());

  @override
  List<Object?> get props => [
    schemaVersion,
    id,
    settings,
    clips,
    layers,
    audioTracks,
    effects,
    cover,
    extras,
    updatedAt,
  ];
}

class ProjectSnapshot {
  const ProjectSnapshot(this.json);
  final Map<String, dynamic> json;

  ProjectDocument restore() => ProjectDocument.fromJson(json);
}

import 'package:flutter/painting.dart';

import '../../api/caption_engine.dart';
import '../templates/reel_template.dart';
import 'audio_track.dart';
import 'cover_choice.dart';
import 'duet_layout.dart';
import 'effect_instance.dart';
import 'project_document.dart';
import 'timeline_clip.dart';
import 'visual_layer.dart';

sealed class ProjectMutation {
  const ProjectMutation();
}

class SetClipsMutation extends ProjectMutation {
  const SetClipsMutation(this.clips);
  final List<TimelineClip> clips;
}

class AppendClipMutation extends ProjectMutation {
  const AppendClipMutation(this.clip);
  final TimelineClip clip;
}

class RemoveClipMutation extends ProjectMutation {
  const RemoveClipMutation(this.clipId);
  final String clipId;
}

class RemoveLastClipMutation extends ProjectMutation {
  const RemoveLastClipMutation();
}

class UpdateClipTrimMutation extends ProjectMutation {
  const UpdateClipTrimMutation({
    required this.clipId,
    required this.trimStart,
    required this.trimEnd,
  });
  final String clipId;
  final Duration trimStart;
  final Duration trimEnd;
}

class SetColorFilterMutation extends ProjectMutation {
  const SetColorFilterMutation(this.effectId, {this.intensity = 1.0});
  final String effectId;
  final double intensity;
}

class AddTextLayerMutation extends ProjectMutation {
  const AddTextLayerMutation({
    required this.layerId,
    required this.text,
    this.position = const Offset(0.5, 0.4),
    this.colorValue = 0xFFFFFFFF,
    this.fontSize = 28,
    this.textBackdrop = TextBackdrop.stroke,
  });
  final String layerId;
  final String text;
  final Offset position;
  final int colorValue;
  final double fontSize;
  final TextBackdrop textBackdrop;
}

class UpdateLayerMutation extends ProjectMutation {
  const UpdateLayerMutation(this.layer);
  final VisualLayer layer;
}

class RemoveLayerMutation extends ProjectMutation {
  const RemoveLayerMutation(this.layerId);
  final String layerId;
}

class SetMusicTrackMutation extends ProjectMutation {
  const SetMusicTrackMutation({
    this.musicId,
    this.sourcePath,
    this.volume = 1.0,
    this.originalVolume = 1.0,
    this.startOffset,
  });
  final String? musicId;
  final String? sourcePath;
  final double volume;
  final double originalVolume;
  final Duration? startOffset;
}

class SetCoverMutation extends ProjectMutation {
  const SetCoverMutation(this.cover);
  final CoverChoice cover;
}

class ReplaceEffectsMutation extends ProjectMutation {
  const ReplaceEffectsMutation(this.effects);
  final List<EffectInstance> effects;
}

class UpdateClipSpeedMutation extends ProjectMutation {
  const UpdateClipSpeedMutation({required this.clipId, required this.speed});
  final String clipId;
  final double speed;
}

class SetCaptionCuesMutation extends ProjectMutation {
  const SetCaptionCuesMutation(this.cues);
  final List<CaptionCue> cues;
}

class ApplyTemplateMutation extends ProjectMutation {
  const ApplyTemplateMutation(this.template);
  final ReelTemplate template;
}

class ClearTemplateMutation extends ProjectMutation {
  const ClearTemplateMutation();
}

class SetDuetLayoutMutation extends ProjectMutation {
  const SetDuetLayoutMutation({required this.layout, this.parentVideoPath});
  final DuetLayout layout;
  final String? parentVideoPath;
}

ProjectDocument applyProjectMutation(
  ProjectDocument project,
  ProjectMutation mutation,
) {
  switch (mutation) {
    case SetClipsMutation(:final clips):
      return project.copyWith(clips: clips).touch();
    case AppendClipMutation(:final clip):
      return project.copyWith(clips: [...project.clips, clip]).touch();
    case RemoveClipMutation(:final clipId):
      return project
          .copyWith(clips: project.clips.where((c) => c.id != clipId).toList())
          .touch();
    case RemoveLastClipMutation():
      if (project.clips.isEmpty) return project;
      return project
          .copyWith(clips: project.clips.sublist(0, project.clips.length - 1))
          .touch();
    case UpdateClipTrimMutation(
      :final clipId,
      :final trimStart,
      :final trimEnd,
    ):
      return project
          .copyWith(
            clips: project.clips
                .map(
                  (c) => c.id == clipId
                      ? c.copyWith(trimStart: trimStart, trimEnd: trimEnd)
                      : c,
                )
                .toList(),
          )
          .touch();
    case SetColorFilterMutation(:final effectId, :final intensity):
      final others = project.effects
          .where((e) => e.category != 'color')
          .toList();
      return project
          .copyWith(
            effects: [
              ...others,
              EffectInstance(
                id: 'color-filter',
                effectId: effectId,
                category: 'color',
                params: {'intensity': intensity.clamp(0.0, 1.0)},
              ),
            ],
          )
          .touch();
    case AddTextLayerMutation(
      :final layerId,
      :final text,
      :final position,
      :final colorValue,
      :final fontSize,
      :final textBackdrop,
    ):
      return project
          .copyWith(
            layers: [
              ...project.layers,
              VisualLayer(
                id: layerId,
                type: VisualLayerType.text,
                normalizedPosition: position,
                text: text,
                colorValue: colorValue,
                fontSize: fontSize,
                textBackdrop: textBackdrop,
                zIndex: project.layers.length,
              ),
            ],
          )
          .touch();
    case UpdateLayerMutation(:final layer):
      return project
          .copyWith(
            layers: project.layers
                .map((l) => l.id == layer.id ? layer : l)
                .toList(),
          )
          .touch();
    case RemoveLayerMutation(:final layerId):
      return project
          .copyWith(
            layers: project.layers.where((l) => l.id != layerId).toList(),
          )
          .touch();
    case SetMusicTrackMutation(
      :final musicId,
      :final sourcePath,
      :final volume,
      :final originalVolume,
      :final startOffset,
    ):
      AudioTrack? previousMusic;
      for (final t in project.audioTracks) {
        if (t.kind == AudioTrackKind.music) {
          previousMusic = t;
          break;
        }
      }
      final withoutMusic = project.audioTracks
          .where((t) => t.kind != AudioTrackKind.music)
          .map(
            (t) => t.kind == AudioTrackKind.original
                ? t.copyWith(volume: originalVolume)
                : t,
          )
          .toList();
      final tracks = [
        ...withoutMusic,
        if (musicId != null || sourcePath != null)
          AudioTrack(
            id: 'music-track',
            kind: AudioTrackKind.music,
            musicId: musicId,
            sourcePath: sourcePath,
            volume: volume,
            startOffset:
                startOffset ?? previousMusic?.startOffset ?? Duration.zero,
          ),
      ];
      return project.copyWith(audioTracks: tracks).touch();
    case SetCoverMutation(:final cover):
      return project.copyWith(cover: cover).touch();
    case ReplaceEffectsMutation(:final effects):
      return project.copyWith(effects: effects).touch();
    case UpdateClipSpeedMutation(:final clipId, :final speed):
      final clamped = speed.clamp(0.3, 3.0);
      return project
          .copyWith(
            clips: project.clips
                .map((c) => c.id == clipId ? c.copyWith(speed: clamped) : c)
                .toList(),
          )
          .touch();
    case SetCaptionCuesMutation(:final cues):
      final kept = project.layers
          .where((l) => l.role != VisualLayer.roleCaption)
          .toList();
      final captionLayers = <VisualLayer>[];
      for (var i = 0; i < cues.length; i++) {
        final cue = cues[i];
        if (cue.text.trim().isEmpty) continue;
        captionLayers.add(
          VisualLayer(
            id: 'caption-$i',
            type: VisualLayerType.text,
            normalizedPosition: const Offset(0.5, 0.78),
            text: cue.text.trim(),
            fontSize: 22,
            colorValue: 0xFFFFFFFF,
            textBackdrop: TextBackdrop.fill,
            zIndex: kept.length + i,
            startAt: cue.start,
            endAt: cue.end,
            role: VisualLayer.roleCaption,
          ),
        );
      }
      return project.copyWith(layers: [...kept, ...captionLayers]).touch();
    case ApplyTemplateMutation(:final template):
      final kept = project.layers
          .where((l) => l.role != VisualLayer.roleTemplate)
          .toList();
      final templateLayers = <VisualLayer>[];
      for (var i = 0; i < template.layers.length; i++) {
        templateLayers.add(
          template.layers[i]
              .toLayer('tpl-${template.id}-$i')
              .copyWith(zIndex: kept.length + i),
        );
      }
      final extras = <String, dynamic>{
        ...project.extras,
        'templateId': template.id,
      };
      if (template.musicId != null) {
        extras['templateMusicId'] = template.musicId;
      } else {
        extras.remove('templateMusicId');
      }
      var next = project.copyWith(
        layers: [...kept, ...templateLayers],
        extras: extras,
      );
      if (template.filterId != null) {
        next = applyProjectMutation(
          next,
          SetColorFilterMutation(template.filterId!),
        );
      }
      final speed = template.speed ?? 1.0;
      if (next.clips.isNotEmpty) {
        next = next.copyWith(
          clips: next.clips.map((c) => c.copyWith(speed: speed)).toList(),
        );
      }
      if (template.duetLayout.isActive && next.parentVideoPath != null) {
        next = next.copyWith(
          extras: {...next.extras, 'duetLayout': template.duetLayout.name},
        );
      }
      return next.touch();
    case ClearTemplateMutation():
      final extras = Map<String, dynamic>.from(project.extras)
        ..remove('templateId')
        ..remove('templateMusicId');
      return project
          .copyWith(
            layers: project.layers
                .where((l) => l.role != VisualLayer.roleTemplate)
                .toList(),
            extras: extras,
          )
          .touch();
    case SetDuetLayoutMutation(:final layout, :final parentVideoPath):
      return project
          .copyWith(
            extras: {
              ...project.extras,
              'duetLayout': layout.name,
              if (parentVideoPath case final String path)
                'parentVideoPath': path,
            },
          )
          .touch();
  }
}

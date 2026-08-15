import '../domain/project/audio_track.dart';
import '../domain/project/duet_layout.dart';
import '../domain/project/project_document.dart';

class ExportPlan {
  const ExportPlan({
    required this.needsConcat,
    required this.needsSpeed,
    required this.needsDuet,
    required this.needsFilter,
    required this.needsText,
    required this.needsMusic,
  });

  final bool needsConcat;
  final bool needsSpeed;
  final bool needsDuet;
  final bool needsFilter;
  final bool needsText;
  final bool needsMusic;

  bool get needsReencode =>
      needsConcat ||
      needsFilter ||
      needsText ||
      needsMusic ||
      needsSpeed ||
      needsDuet;
}

class ExportPlanner {
  const ExportPlanner();

  ExportPlan plan(ProjectDocument project) {
    final filterId = project.activeFilterId ?? 'normal';
    return ExportPlan(
      needsConcat: project.clips.length > 1,
      needsSpeed: project.hasSpeedChange,
      needsDuet:
          project.duetLayout.isActive &&
          (project.parentVideoPath?.isNotEmpty ?? false),
      needsFilter: filterId != 'normal' && project.activeFilterIntensity > 0.05,
      needsText: project.layers.any((l) => l.text?.isNotEmpty ?? false),
      needsMusic: project.audioTracks.any(
        (t) =>
            t.kind == AudioTrackKind.music &&
            (t.sourcePath?.isNotEmpty ?? false),
      ),
    );
  }
}

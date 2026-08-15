import '../domain/effects/effect_registry.dart';
import '../domain/project/audio_track.dart';
import '../domain/project/project_document.dart';
import '../domain/project/visual_layer.dart';
import '../render/color_grade.dart';
import '../render/render_graph.dart';
import 'export_capabilities.dart';

/// Backend-agnostic bake plan derived from a [RenderGraph].
///
/// Canonical replacement for ad-hoc `needsConcat` / `needsFilter` flags inside
/// exporters. [ExportPlanner] remains for existing tests.
class ExportRecipe {
  const ExportRecipe({
    required this.segments,
    required this.duration,
    required this.colorGrade,
    this.textOverlays = const [],
    this.stickerOverlays = const [],
    this.music,
    this.originalAudio,
    this.duet,
    this.voiceoverTracks = const [],
  });

  final List<RenderVideoSegment> segments;
  final Duration duration;
  final ColorGrade colorGrade;
  final List<VisualLayer> textOverlays;
  final List<VisualLayer> stickerOverlays;
  final AudioTrack? music;
  final AudioTrack? originalAudio;
  final RenderDuet? duet;
  final List<AudioTrack> voiceoverTracks;

  bool get needsConcat => segments.length > 1;

  bool get needsSpeed => segments.any((s) => (s.speed - 1.0).abs() > 0.001);

  bool get needsColor => colorGrade.isActive;

  bool get needsText => textOverlays.any((l) => l.text?.isNotEmpty ?? false);

  bool get needsMusic =>
      music?.sourcePath != null && music!.sourcePath!.isNotEmpty;

  bool get needsDuet => duet != null;

  bool get needsStillImage => segments.any((s) => s.isImage);

  bool get needsStickers => stickerOverlays.isNotEmpty;

  bool get needsVoiceover => voiceoverTracks.isNotEmpty;

  bool get needsTrim => segments.any((s) => s.isTrimmed);

  /// Same reencode rule as [ExportPlan.needsReencode].
  bool get needsReencode =>
      needsConcat ||
      needsColor ||
      needsText ||
      needsMusic ||
      needsSpeed ||
      needsDuet;

  Set<ExportOperationKind> get requiredOperations => {
    if (needsTrim) ExportOperationKind.trim,
    if (needsSpeed) ExportOperationKind.speed,
    if (needsConcat) ExportOperationKind.concat,
    if (needsColor) ExportOperationKind.colorMatrix,
    if (needsText) ExportOperationKind.textOverlay,
    if (needsMusic) ExportOperationKind.audioMix,
    if (needsDuet) ExportOperationKind.duet,
    if (needsStillImage) ExportOperationKind.stillImage,
    if (needsStickers) ExportOperationKind.stickerOverlay,
    if (needsVoiceover) ExportOperationKind.voiceover,
  };

  factory ExportRecipe.fromGraph(RenderGraph graph) {
    return ExportRecipe(
      segments: graph.segments,
      duration: graph.duration,
      colorGrade: graph.colorGrade,
      textOverlays: graph.textOverlays,
      stickerOverlays: graph.stickerOverlays,
      music: graph.music,
      originalAudio: graph.originalAudio,
      duet: graph.duet,
      voiceoverTracks: graph.voiceovers,
    );
  }

  factory ExportRecipe.fromProject(
    ProjectDocument project, {
    EffectRegistry? registry,
  }) {
    return ExportRecipe.fromGraph(
      RenderGraph.fromProject(project, registry: registry),
    );
  }
}

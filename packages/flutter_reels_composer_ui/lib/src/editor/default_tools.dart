import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

import 'tools/audio_tool.dart';
import 'tools/captions_tool.dart';
import 'tools/cover_tool.dart';
import 'tools/filter_tool.dart';
import 'tools/speed_tool.dart';
import 'tools/template_tool.dart';
import 'tools/text_tool.dart';
import 'tools/trim_tool.dart';

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.theme, required this.child});
  final ComposerTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.sheet.withValues(alpha: 0.94),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class TrimEditorTool implements EditorTool {
  const TrimEditorTool();
  @override
  String get id => 'trim';
  @override
  ComposerFeature get feature => ComposerFeature.trim;
  @override
  IconData icon(BuildContext context) => Icons.content_cut;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    final preview = ctx.preview;
    if (preview == null) return const SizedBox.shrink();
    return _PanelShell(
      theme: ctx.theme,
      child: TrimToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        preview: preview,
        frameExtractor: ctx.config.frameExtractor,
        maxDuration: ctx.config.maxDuration,
      ),
    );
  }
}

class FilterEditorTool implements EditorTool {
  const FilterEditorTool();
  @override
  String get id => 'filter';
  @override
  ComposerFeature get feature => ComposerFeature.colorFilters;
  @override
  IconData icon(BuildContext context) => Icons.filter_vintage;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    return _PanelShell(
      theme: ctx.theme,
      child: FilterToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        selectedId: ctx.project.activeFilterId,
        intensity: ctx.project.activeFilterIntensity,
        frameExtractor: ctx.config.frameExtractor,
        previewSourcePath: ctx.project.primarySourcePath,
        onCompareChanged: (comparing) {
          ctx.preview?.setCompareOriginal(comparing);
        },
      ),
    );
  }
}

class TextEditorTool implements EditorTool {
  const TextEditorTool();
  @override
  String get id => 'text';
  @override
  ComposerFeature get feature => ComposerFeature.textOverlays;
  @override
  IconData icon(BuildContext context) => Icons.text_fields;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    return _PanelShell(
      theme: ctx.theme,
      child: TextToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        selectedLayerId: ctx.selectedLayerId,
        onSelectedLayerId: ctx.onSelectedLayerId,
        onClearSelection: () => ctx.onSelectedLayerId?.call(null),
      ),
    );
  }
}

class AudioEditorTool implements EditorTool {
  const AudioEditorTool();
  @override
  String get id => 'audio';
  @override
  ComposerFeature get feature => ComposerFeature.musicMix;
  @override
  IconData icon(BuildContext context) => Icons.music_note;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    return _PanelShell(
      theme: ctx.theme,
      child: AudioToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        catalog: ctx.config.musicCatalog,
        selectedMusicId: ctx.project.audioTracks
            .where((t) => t.kind == AudioTrackKind.music)
            .map((t) => t.musicId)
            .firstWhere((id) => id != null, orElse: () => null),
        preview: ctx.preview,
      ),
    );
  }
}

class CoverEditorTool implements EditorTool {
  const CoverEditorTool();
  @override
  String get id => 'cover';
  @override
  ComposerFeature get feature => ComposerFeature.cover;
  @override
  IconData icon(BuildContext context) => Icons.image_outlined;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    final preview = ctx.preview;
    if (preview == null) return const SizedBox.shrink();
    return _PanelShell(
      theme: ctx.theme,
      child: CoverToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        preview: preview,
        frameExtractor: ctx.config.frameExtractor,
      ),
    );
  }
}

class SpeedEditorTool implements EditorTool {
  const SpeedEditorTool();
  @override
  String get id => 'speed';
  @override
  ComposerFeature get feature => ComposerFeature.speed;
  @override
  IconData icon(BuildContext context) => Icons.speed;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    final preview = ctx.preview;
    if (preview == null) return const SizedBox.shrink();
    return _PanelShell(
      theme: ctx.theme,
      child: SpeedToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        preview: preview,
        onChanged: (speed) {
          ctx.config.onEvent?.call(
            ComposerAnalyticsEvent(
              ComposerAnalyticsEventType.speedChanged,
              properties: {'speed': speed},
            ),
          );
        },
      ),
    );
  }
}

class CaptionsEditorTool implements EditorTool {
  const CaptionsEditorTool();
  @override
  String get id => 'captions';
  @override
  ComposerFeature get feature => ComposerFeature.aiCaptions;
  @override
  IconData icon(BuildContext context) => Icons.closed_caption;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    return _PanelShell(
      theme: ctx.theme,
      child: CaptionsToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        captionEngine: ctx.config.captionEngine,
        preview: ctx.preview,
        selectedLayerId: ctx.selectedLayerId,
        onGenerated: () {
          ctx.config.onEvent?.call(
            const ComposerAnalyticsEvent(
              ComposerAnalyticsEventType.captionsGenerated,
            ),
          );
        },
      ),
    );
  }
}

class TemplateEditorTool implements EditorTool {
  const TemplateEditorTool();
  @override
  String get id => 'templates';
  @override
  ComposerFeature get feature => ComposerFeature.templates;
  @override
  IconData icon(BuildContext context) => Icons.dashboard_customize_outlined;
  @override
  String label(ComposerToolL10n l10n) => l10n.toolLabel(feature);
  @override
  Widget buildPanel(EditorToolContext ctx) {
    return _PanelShell(
      theme: ctx.theme,
      child: TemplateToolPanel(
        theme: ctx.theme,
        controller: ctx.controller,
        project: ctx.project,
        catalog: ctx.config.templateCatalog.templates.isEmpty
            ? TemplateCatalog.bundled
            : ctx.config.templateCatalog,
        onApplied: (template) {
          ctx.config.onEvent?.call(
            ComposerAnalyticsEvent(
              ComposerAnalyticsEventType.templateApplied,
              properties: {'templateId': template.id},
            ),
          );
          final musicId = template.musicId;
          if (musicId == null) return;
          final track = ctx.config.musicCatalog.byId(musicId);
          if (track == null || track.sourcePath.isEmpty) return;
          unawaited(
            ctx.controller.apply(
              SetMusicTrackMutation(
                musicId: track.id,
                sourcePath: track.sourcePath,
                volume: 1,
                originalVolume: 0.35,
              ),
            ),
          );
        },
      ),
    );
  }
}

List<EditorTool> defaultEditorTools() {
  return const [
    TrimEditorTool(),
    FilterEditorTool(),
    TextEditorTool(),
    AudioEditorTool(),
    CoverEditorTool(),
    SpeedEditorTool(),
    CaptionsEditorTool(),
    TemplateEditorTool(),
  ];
}

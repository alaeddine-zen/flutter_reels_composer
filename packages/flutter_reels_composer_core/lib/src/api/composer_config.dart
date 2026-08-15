import 'package:flutter/widgets.dart';

import '../analytics/composer_analytics.dart';
import '../capabilities/composer_feature.dart';
import '../contracts/composer_engine.dart';
import '../contracts/export_port.dart';
import '../contracts/frame_extractor.dart';
import '../persistence/draft_store.dart';
import '../domain/effects/effect_catalog.dart';
import '../domain/project/duet_layout.dart';
import '../domain/templates/reel_template.dart';
import '../plugins/editor_tool.dart';
import 'caption_engine.dart';
import 'composer_theme.dart';
import 'music_catalog.dart';

class ComposerConfig {
  ComposerConfig({
    this.engine,
    this.exporter,
    this.theme = ComposerTheme.snapTikTok,
    this.maxDuration = const Duration(seconds: 60),
    this.recordPresets = const [
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
    this.musicCatalog = MusicCatalog.empty,
    this.effectCatalog = EffectCatalog.empty,
    this.templateCatalog = TemplateCatalog.empty,
    this.enabledFeatures = kDefaultV1Features,
    this.extraTools = const [],
    this.parentPostUuid,
    this.parentVideoPath,
    this.duetLayout = DuetLayout.none,
    this.captionEngine = const NullCaptionEngine(),
    this.frameExtractor = const NoopFrameExtractor(),
    this.onEvent,
    this.locale,
    this.l10n,
    this.draftStore,
  });

  final ComposerEngine? engine;
  final ExportPort? exporter;
  final ComposerTheme theme;
  final Duration maxDuration;
  final List<Duration> recordPresets;
  final MusicCatalog musicCatalog;
  final EffectCatalog effectCatalog;
  final TemplateCatalog templateCatalog;
  final Set<ComposerFeature> enabledFeatures;
  final List<EditorTool> extraTools;
  final String? parentPostUuid;
  final String? parentVideoPath;
  final DuetLayout duetLayout;
  final CaptionEngine captionEngine;
  final FrameExtractorPort frameExtractor;
  final ComposerAnalyticsCallback? onEvent;
  final Locale? locale;
  final ComposerToolL10n? l10n;
  final DraftStore? draftStore;

  bool get isDuet =>
      parentVideoPath != null &&
      parentVideoPath!.isNotEmpty &&
      duetLayout.isActive;

  bool get duetParentMissing =>
      parentPostUuid != null && parentPostUuid!.isNotEmpty && !isDuet;
}

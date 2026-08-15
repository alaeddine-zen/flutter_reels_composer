import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_reels_composer_export_lgpl/flutter_reels_composer_export_lgpl.dart';
import 'package:flutter_reels_composer_local/flutter_reels_composer_local.dart';
import 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';

/// Batteries-included entry point.
class FlutterReelsComposer {
  FlutterReelsComposer._();

  static Future<ComposerResult?> open(
    BuildContext context, {
    ComposerConfig? config,
  }) async {
    final resolved = config ?? ComposerConfig();
    final hostLocale = resolved.locale ?? Localizations.maybeLocaleOf(context);
    final exporter = resolved.exporter ?? FfmpegLgplExportPort();
    final frameExtractor = resolved.frameExtractor is NoopFrameExtractor
        ? FfmpegLgplFrameExtractor()
        : resolved.frameExtractor;
    final ownsEngine = resolved.engine == null;
    final engine =
        resolved.engine ??
        LocalComposerEngine(
          photoClipEncoder: exporter is StillImageEncoderPort
              ? (exporter as StillImageEncoderPort).encodeStillImage
              : null,
        );
    final drafts = resolved.draftStore ?? FileDraftStore();
    final bundle = DefaultAssetBundle.of(context);

    try {
      await engine.initialize(
        EngineInitConfig(maxDuration: resolved.maxDuration),
      );
      try {
        const asset =
            'packages/flutter_reels_composer_ui/assets/effects/effects_manifest.json';
        final raw = await bundle.loadString(asset);
        await engine.loadEffectPack(
          EffectAssetStore().parsePack(raw, id: 'bundled-v2'),
        );
      } catch (error) {
        debugPrint('FlutterReelsComposer: effect pack load failed: $error');
        resolved.onEvent?.call(
          ComposerAnalyticsEvent(
            ComposerAnalyticsEventType.effectPackLoadFailed,
            properties: {'error': error.toString()},
          ),
        );
      }
      if (resolved.effectCatalog.effects.isNotEmpty) {
        await engine.loadEffectPack(
          EffectPack(
            id: 'host',
            version: 1,
            effects: resolved.effectCatalog.effects,
          ),
        );
      }
      if (exporter is EffectRegistryAwareExportPort) {
        (exporter as EffectRegistryAwareExportPort).attachRegistry(
          engine.effectRegistry,
        );
      }

      TemplateCatalog templateCatalog = resolved.templateCatalog;
      if (templateCatalog.templates.isEmpty) {
        try {
          const asset =
              'packages/flutter_reels_composer_ui/assets/templates/templates.json';
          final raw = await bundle.loadString(asset);
          final parsed = TemplateCatalog.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          templateCatalog = parsed.templates.isEmpty
              ? TemplateCatalog.bundled
              : parsed;
        } catch (error) {
          debugPrint(
            'FlutterReelsComposer: template catalog load failed: $error',
          );
          resolved.onEvent?.call(
            ComposerAnalyticsEvent(
              ComposerAnalyticsEventType.templateCatalogLoadFailed,
              properties: {'error': error.toString()},
            ),
          );
          templateCatalog = TemplateCatalog.bundled;
        }
      }

      final wired = ComposerConfig(
        engine: engine,
        exporter: exporter,
        theme: resolved.theme,
        maxDuration: resolved.maxDuration,
        recordPresets: resolved.recordPresets,
        musicCatalog: resolved.musicCatalog,
        effectCatalog: resolved.effectCatalog,
        templateCatalog: templateCatalog,
        enabledFeatures: resolved.enabledFeatures,
        extraTools: resolved.extraTools,
        parentPostUuid: resolved.parentPostUuid,
        parentVideoPath: resolved.parentVideoPath,
        duetLayout: resolved.duetLayout,
        captionEngine: resolved.captionEngine,
        frameExtractor: frameExtractor,
        onEvent: resolved.onEvent,
        locale: hostLocale,
        l10n: resolved.l10n,
        draftStore: drafts,
      );

      if (!context.mounted) return null;
      wired.onEvent?.call(
        const ComposerAnalyticsEvent(ComposerAnalyticsEventType.opened),
      );
      return await Navigator.of(
        context,
        rootNavigator: true,
      ).push<ComposerResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Theme(
            data: wired.theme.toThemeData(),
            child: ComposerNavigator(
              config: wired,
              engine: engine,
              draftStore: drafts,
            ),
          ),
        ),
      );
    } finally {
      if (ownsEngine) await engine.dispose();
    }
  }
}

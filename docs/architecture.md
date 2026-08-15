# Architecture

Flutter Reels Composer is a **monorepo of Dart packages**. The workspace root
is documentation and CI only (`publish_to: none`).

## Package graph

```
Host app
  └─ flutter_reels_composer          MIT facade (or flutter_reels_composer_gpl)
        ├─ flutter_reels_composer_ui
        ├─ flutter_reels_composer_local
        └─ flutter_reels_composer_export_lgpl   (GPL facade uses export_gpl)
              └─ flutter_reels_composer_core    (all arrows)
```

Internal `pubspec.yaml` files use hosted `^0.2.0`. Each package (and the
example) has `pubspec_overrides.yaml` pointing at sibling paths for local
work.

## Runtime flow

```
FlutterReelsComposer.open(context, config)
  → initialize ComposerEngine (maxDuration)
  → load bundled effect pack + host EffectCatalog
  → attach EffectRegistry to exporter if EffectRegistryAwareExportPort
  → resolve TemplateCatalog (host, else UI assets, else bundled)
  → Navigator.push fullscreen ComposerNavigator
        camera  ↔  gallery  →  editor  →  ExportPort.export
  → ComposerResult | null
  → dispose engine if the facade owns it
```

`ComposerNavigator` offers draft resume from `DraftStore.list()` on first
frame.

## Layers

| Layer | Package | Responsibility |
| --- | --- | --- |
| Facade | `flutter_reels_composer` | Wire defaults and present UI |
| UI | `flutter_reels_composer_ui` | Pages, tool rail, l10n, bundled tools |
| Local engine | `flutter_reels_composer_local` | Camera (`camerawesome`), gallery (`photo_manager`), preview, drafts |
| Export | `export_lgpl` / `export_gpl` | Bake `ProjectDocument` to MP4 |
| Domain | `flutter_reels_composer_core` | Immutable project, mutations, ports |

## Project model

`ProjectDocument` is immutable (JSON schema **v3**). Editor UI edits go
through `ComposerController.apply` / `applyLive` (undo/redo). The engine
still applies a `ProjectMutation` underneath.

`Timeline.fromDocument` and `RenderGraph.fromProject` are **derived views** —
not a second store. Preview and FFmpeg export consume the same graph.
The editor timeline (`ClipTimeline`) splits, trims and rolls clips through
`ComposerController`; export concatenates the resulting segments.

Color is a 4×5 `ColorFilter` matrix (`ColorGrade`), applied as
`ColorFilter.matrix` in preview and `colorchannelmixer` (+ `lutrgb` offsets)
in FFmpeg. This is **not** `.cube` LUT support.

Export builds an `ExportRecipe` and checks `ExportCapabilitySet` before
baking. Unsupported operations throw `UnsupportedExportException` instead of
being dropped.

FFmpeg helpers (`atempo` / `setpts`) live in the export packages.
`FfmpegFilters` remaining in core is deprecated.

Legacy bake (trim, concat, speed, text PNG, audio mix, duet, cover JPEG)
still runs; the recipe is the canonical plan.

## Ports (core)

| Port | Default (MIT facade) |
| --- | --- |
| `ComposerEngine` | `LocalComposerEngine` |
| `ExportPort` | `FfmpegLgplExportPort` (`mpeg4`) |
| `StillImageEncoderPort` | same LGPL exporter (3 s photo clips) |
| `FrameExtractorPort` | `FfmpegLgplFrameExtractor` |
| `DraftStore` | `FileDraftStore` |
| `CaptionEngine` | `NullCaptionEngine` |
| `CapturePort` / `MediaPickerPort` / `PreviewPort` | created by the engine |

UI never imports FFmpeg Kit. Thumbnails go through `FrameExtractorPort`.

## Public barrels

| Import | Audience |
| --- | --- |
| `package:flutter_reels_composer/flutter_reels_composer.dart` | Host apps: `FlutterReelsComposer.open`, `ComposerConfig`, catalogs, theme, l10n, ports, `EditorTool` / `defaultEditorTools`, `ComposerNavigator` |
| `package:flutter_reels_composer_gpl/flutter_reels_composer_gpl.dart` | GPL hosts only (`FlutterReelsComposerGpl.open`; same stable surface, no pages) |
| `package:flutter_reels_composer_core/flutter_reels_composer_core.dart` | Custom engines / tools |
| `package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart` | `ComposerNavigator`, `defaultEditorTools`, l10n, chrome (`ToolRail`, `Filmstrip`, `ClipTimeline`) |
| `package:flutter_reels_composer_ui/pages.dart` | Custom shells: `CameraPage`, `GalleryPage`, `EditorPage` |

## Capability gates

`CapabilityGate.resolve` intersects `ComposerEngine.capabilities` with
`ComposerConfig.enabledFeatures`. Built-in tools hide when the feature is off.
**Host `extraTools` stay visible** regardless of the gate (`EditorToolRegistry`).

`LocalComposerEngine.capabilities` is `ComposerCapabilities.localV1` =
`kDefaultV1Features` (record, gallery, trim, filters, text, music, cover,
multi-clip, speed, templates, captions, duet). Not included: stickers, beauty,
AR masks, green screen.

## Analytics

`ComposerConfig.onEvent` receives `ComposerAnalyticsEvent` (`opened`,
`exportCompleted`, `draftSaved`, `effectPackLoadFailed`, …). The facade does
not send data off-device.

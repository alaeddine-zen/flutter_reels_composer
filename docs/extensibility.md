# Extensibility

The composer is built so a host can replace UI tools, capture, export, and
catalogs without forking packages. Prefer **composition** (`ComposerConfig`)
over copy-paste.

## What you can plug in

| Extension | Config field | Contract |
| --- | --- | --- |
| Extra / replacement editor tools | `extraTools` | `EditorTool` |
| Capture + preview + mutations | `engine` | `ComposerEngine` |
| MP4 bake (or cloud) | `exporter` | `ExportPort` |
| Photo → clip | (exporter if `StillImageEncoderPort`) | `StillImageEncoderPort` |
| Filmstrip thumbnails | `frameExtractor` | `FrameExtractorPort` |
| Draft persistence | `draftStore` | `DraftStore` |
| Speech-to-captions | `captionEngine` | `CaptionEngine` |
| Licensed music | `musicCatalog` | `MusicCatalog` / `MusicTrack` |
| Extra color/FX | `effectCatalog` | `EffectCatalog` / `EffectDescriptor` |
| Overlay layouts | `templateCatalog` | `TemplateCatalog` |
| Strings | `l10n` / `locale` | `ComposerToolL10n` |
| Colors / sizes | `theme` | `ComposerTheme` |
| Feature flags | `enabledFeatures` | `ComposerFeature` |
| Product analytics | `onEvent` | `ComposerAnalyticsCallback` |

## Editor tools

See [extensions/editor-tools.md](extensions/editor-tools.md).

- Built-in ids: `trim`, `filter`, `text`, `audio`, `cover`, `speed`,
  `captions`, `templates`
- Same `id` in `extraTools` **replaces** the built-in
- New ids are **appended** (host tools are always visible)
- Mutate via `EditorToolContext.controller.apply(ProjectMutation)`

`stickers`, `beauty`, `arMasks`, and `greenScreen` are enum values for host
tools. This repo does not ship those panels.

## Engines

See [extensions/engines.md](extensions/engines.md).

`ComposerEngine` owns capture, picker, preview, and project state.
**Export is a separate `ExportPort`.** Keep FFmpeg (or any encoder) out of
`core`, `ui`, and `local`.

`packages/flutter_reels_composer_core` exports `FakeComposerEngine` for tests.

## Export

Implement `ExportPort`:

```dart
abstract class ExportPort {
  ExportLicenseKind get licenseKind; // none | lgpl | gpl
  ExportSession export(ProjectDocument project, ExportOptions options);
}
```

Optional mixins:

- `StillImageEncoderPort` — gallery photos become 3 s clips in the MIT/GPL facades
- `EffectRegistryAwareExportPort` — facade calls `attachRegistry` after effects load

LGPL default: `FfmpegLgplExportPort` (`mpeg4`, or `hardwareH264`).
GPL opt-in: `FfmpegGplExportPort` (`libx264`) via the **GPL facade only**.

## Catalogs

- **Music** — empty by default. Pass local file paths you are licensed to use.
- **Effects** — bundled pack loads from
  `packages/flutter_reels_composer_ui/assets/effects/effects_manifest.json`.
  Non-empty `effectCatalog` is loaded as pack id `host`.
- **Templates** — if `templateCatalog.templates` is empty, the facade loads
  `assets/templates/templates.json`, then falls back to
  `TemplateCatalog.bundled`.

## Custom shell

Skip the facade. Depend on `core`, `ui`, and an engine/exporter. Prefer
`ComposerNavigator` from `package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart`
(also re-exported by the MIT/GPL façades).

To assemble screens yourself, import the pages library — they are **not**
on the main UI barrel or façades:

```dart
import 'package:flutter_reels_composer_ui/pages.dart';
```

That export is `CameraPage`, `GalleryPage`, and `EditorPage`.

## Hard rule

Do not depend on `flutter_reels_composer` and `flutter_reels_composer_gpl` in
the same app. See [licensing.md](licensing.md).

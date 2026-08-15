# Changelog

All notable changes to this monorepo are listed here. Each publishable package
also has its own `CHANGELOG.md`.

## Unreleased

Internal render-model foundation (schema v3). Host `FlutterReelsComposer.open`
is unchanged.

- `Timeline` / `VideoClip` / `ImageClip` / `RenderGraph` / `ExportRecipe`
- Dual-write `timeline` JSON; v1/v2 drafts migrate
- Preview and FFmpeg share `ColorGrade` (4×5 ColorMatrix, not `.cube`)
- `ExportCapabilitySet` — unsupported ops fail explicitly
- `FfmpegFilters` in core is deprecated (helpers live in export packages)
- Editor undo/redo: tools call `ComposerController.apply` / `applyLive` ;
  gestures (trim, intensity, drag texte) coalescent en une entrée d'historique
- Timeline éditeur : split, poignées trim/roll, snap, zoom
- Parité preview = export : canvas **cover** (crop) sur tous les segments,
  y compris le cas 1 clip ; overlays preview via `RenderGraph`
- Fondu dip-to-black honnête (pas de crossfade chevauchant)
- Presets export 480 / 720 / 1080, autosave éditeur, texte RTL
- Photos galerie → `ImageClip` (sans encode FFmpeg à l’import)
- Erreurs d’export typées ; `file_picker` < 11 pour le CI Android
- Preview: chrome éditeur découplé du playhead (~50 ms), `RenderGraph` mis en cache
- Filmstrips: 8 frames source stables + `CachedFrameExtractor` (LRU, FFmpeg sérialisé)
- Autosave: skip si `updatedAt` inchangé ; `FileDraftStore` ne recopie pas les médias identiques
- Export: `executeAsync` complete callback ; `ffmpegEscapePath` (`\`, `"`, `$`, `` ` ``)
- Horloges preview: resync musique ≥ 120 ms, duet sans seek à chaque tick, prefetch filmstrips
- Guide [docs/verification.md](docs/verification.md) (tests + checks device)
- Suppression des chrome factices : waveform musique, Generate captions sans moteur, filmstrip « faux frames »
- Guide audio [docs/audio.md](docs/audio.md)

## 0.2.0

Independent V2 monorepo. There is no compatibility layer with earlier in-app
composer APIs.

### Packages

- **flutter_reels_composer** — MIT batteries-included facade
  (`FlutterReelsComposer.open`) with LGPL FFmpeg export.
- **flutter_reels_composer_core** — Immutable `ProjectDocument`, mutations,
  ports, `EditorTool` registry, catalogs, analytics.
- **flutter_reels_composer_ui** — Camera, gallery, editor, bundled tools,
  theme, l10n (`en` / `fr` / `ar`).
- **flutter_reels_composer_local** — Capture, gallery/audio pick, preview,
  `FileDraftStore`.
- **flutter_reels_composer_export_lgpl** — FFmpeg Kit min (LGPL): `mpeg4`
  default; optional `h264_videotoolbox` / `h264_mediacodec`. No `libx264`.
- **flutter_reels_composer_export_gpl** — FFmpeg Kit min GPL with `libx264`.
- **flutter_reels_composer_gpl** — Isolated GPL facade
  (`FlutterReelsComposerGpl.open`). Must not be combined with the MIT facade.

### Host API

- `ComposerConfig`: theme, duration, catalogs, `extraTools`, duet, captions,
  analytics, locale/l10n, injectable engine/exporter/drafts/frame extractor.
- `ComposerResult`: `videoFile`, optional `coverFile`, duration, project snapshot.
- Export lives behind `ExportPort`, not on `ComposerEngine`.
- Stable surface: `FlutterReelsComposer.open`, `ComposerConfig`, catalogs,
  theme, l10n, ports, `EditorTool` / `defaultEditorTools`, `ComposerNavigator`.
- `CameraPage` / `GalleryPage` / `EditorPage` are not on the MIT/GPL façades
  or the main UI barrel; import `package:flutter_reels_composer_ui/pages.dart`.

### Tooling

- Example app with Android + iOS permissions (SPM on iOS).
- GitHub Actions CI: format, analyze, tests, Android debug APK.

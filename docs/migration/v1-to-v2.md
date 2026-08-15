# Migration to 0.2.0

0.2.0 is a **clean break**. There is no compatibility shim, rename layer, or
deprecated facade that maps old types onto new ones.

If you previously embedded a one-off in-app composer (custom `open()` helper,
export on the engine, hardcoded copy, GPL FFmpeg on the main package), move to
the packages in this repository.

## API mapping

| Previous idea | 0.2.0 |
| --- | --- |
| Single `open(context)` helper | `FlutterReelsComposer.open` (MIT) or `FlutterReelsComposerGpl.open` (GPL) |
| `engine.export(...)` | `ComposerConfig.exporter` implementing `ExportPort` |
| GPL FFmpeg on the default package | LGPL adapter by default; GPL is a **separate** facade |
| Hardcoded UI strings | `ComposerL10n` (`en` / `fr` / `ar`) or custom `ComposerToolL10n` |
| Concrete draft class in the UI | `DraftStore` + default `FileDraftStore` |
| Vendor SDK stubs in core | Removed. Keep proprietary SDKs out of this repo |
| Editor forks for one extra button | `ComposerConfig.extraTools` / stable tool `id` |
| Import `CameraPage` / `GalleryPage` / `EditorPage` from a façade | `package:flutter_reels_composer_ui/pages.dart` (not the main UI barrel) |

## Integration steps

1. Depend on `flutter_reels_composer` (Git/path until pub.dev). Do **not** also
   depend on `flutter_reels_composer_gpl`.
2. Call `FlutterReelsComposer.open` with a `ComposerConfig`.
3. Upload `ComposerResult.videoFile` (and `coverFile`) in the host. Auth,
   moderation, and publishing stay in the host.
4. Move music, effects, and templates into catalogs.
5. Replace string tables with `locale` or `l10n`.
6. If you need `libx264`, switch the **entire** app to
   `flutter_reels_composer_gpl` — do not mix.

## Behavior that is intentional in 0.2.0

- Default video codec is **mpeg4**, not x264.
- Captions do nothing until you inject a `CaptionEngine`.
- Music catalog starts **empty**.
- Host `extraTools` are visible even when the local engine lacks that feature.

## Platforms

Android and iOS only. Do not expect web or desktop.

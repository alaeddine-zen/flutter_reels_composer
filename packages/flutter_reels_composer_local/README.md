# flutter_reels_composer_local

Default **Android + iOS** implementation of capture, gallery, audio picking,
and preview.

- `LocalComposerEngine` — `ComposerCapabilities.localV1`
- `LocalCapturePort` — `camerawesome`
- `LocalMediaPicker` — `photo_manager` / `file_picker`
- `LocalPreviewPort` — `video_player` + `just_audio` (stills via `Image.file`)
- `FileDraftStore` — app support directory `reels_composer_drafts`

Photos import as `ImageClip` stills. `photoClipEncoder` remains as a fallback
if the copy fails. This package does not depend on FFmpeg Kit.

Preview throttles UI notifies (~50 ms), caches `RenderGraph`, and skips no-op
`Opacity` / `ColorFiltered` layers. Music preview is `just_audio` (no waveform
UI). `FileDraftStore` skips redundant media copies on autosave.

Docs: [engines](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/extensions/engines.md) ·
[permissions](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/permissions.md) ·
[performance](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/performance.md)

**Not on pub.dev yet.** Version 0.2.0.

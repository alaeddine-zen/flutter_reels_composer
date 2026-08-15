# flutter_reels_composer_local

Default **Android + iOS** implementation of capture, gallery, audio picking,
and preview.

- `LocalComposerEngine` — `ComposerCapabilities.localV1`
- `LocalCapturePort` — `camerawesome`
- `LocalMediaPicker` — `photo_manager` / `file_picker`
- `LocalPreviewPort` — `video_player` + `just_audio`
- `FileDraftStore` — app support directory `reels_composer_drafts`

Photo-to-video encoding is injectable (`photoClipEncoder`). This package does
not depend on FFmpeg Kit.

Docs: [engines](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/extensions/engines.md) ·
[permissions](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/permissions.md)

**Not on pub.dev yet.** Version 0.2.0.

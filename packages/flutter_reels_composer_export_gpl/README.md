# flutter_reels_composer_export_gpl

**GPL-3.0-only** FFmpeg export, frame extraction, and still-image encoding.

Uses `ffmpeg_kit_flutter_new_min_gpl` and **`-c:v libx264`**. Distributing an
app that includes this package typically GPL-licenses the combined work.

Most apps should use [`flutter_reels_composer_export_lgpl`](../flutter_reels_composer_export_lgpl)
via the MIT facade. Prefer [`flutter_reels_composer_gpl`](../flutter_reels_composer_gpl)
if you explicitly want this adapter.

**Never** depend on this package together with
`flutter_reels_composer` or `flutter_reels_composer_export_lgpl`.

Frame extraction uses the same `CachedFrameExtractor` + disk JPEG cache as
the LGPL adapter.

Docs: [licensing](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/licensing.md)

**Not on pub.dev yet.** Version 0.2.0.

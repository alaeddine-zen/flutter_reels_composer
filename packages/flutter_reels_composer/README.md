# flutter_reels_composer

[![CI](https://github.com/allochat/flutter_reels_composer/actions/workflows/ci.yml/badge.svg)](https://github.com/allochat/flutter_reels_composer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Batteries-included TikTok/Snap-style video composer for **Android and iOS**.

```dart
final result = await FlutterReelsComposer.open(
  context,
  config: ComposerConfig(
    theme: const ComposerTheme(accent: Colors.pink),
    extraTools: [MyStickerTool()],
  ),
);
```

Bundles camera, gallery, editor UI, local preview, drafts, frame thumbnails,
still-image clips, and **LGPL** FFmpeg export (`mpeg4` default; optional
`h264_videotoolbox` / `h264_mediacodec`). Your app keeps auth, upload, CDN,
and moderation.

Stable surface: `FlutterReelsComposer.open`, `ComposerConfig`, catalogs,
theme, l10n, ports, `EditorTool` / `defaultEditorTools`, `ComposerNavigator`.
`CameraPage` / `GalleryPage` / `EditorPage` are **not** exported here —
import `package:flutter_reels_composer_ui/pages.dart`.

**Not on pub.dev yet** (0.2.0 is developed in this monorepo). Install from
Git or a path — see the [repository README](https://github.com/allochat/flutter_reels_composer#quick-start).

## License split

This package depends on `flutter_reels_composer_export_lgpl`
(`ffmpeg_kit_flutter_new_min`). It does **not** include `libx264`.

For x264, use [`flutter_reels_composer_gpl`](../flutter_reels_composer_gpl) and
`FlutterReelsComposerGpl.open`. **Never** depend on both facades in one app.

## Docs

- [Getting started](https://github.com/allochat/flutter_reels_composer/blob/main/docs/getting-started.md)
- [ComposerConfig](https://github.com/allochat/flutter_reels_composer/blob/main/docs/api/composer-config.md)
- [Permissions](https://github.com/allochat/flutter_reels_composer/blob/main/docs/permissions.md)
- [Licensing](https://github.com/allochat/flutter_reels_composer/blob/main/docs/licensing.md)

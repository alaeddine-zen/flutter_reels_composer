# flutter_reels_composer_ui

Composable camera, gallery, and editor screens for Flutter Reels Composer.

- Built-in tools: trim, filter, text, audio, cover, speed, captions, templates
- `EditorToolRegistry` merges `ComposerConfig.extraTools` (same `id` replaces)
- Bundled `ComposerL10n`: English, French, Arabic
- Assets: effects manifest + templates JSON
- `ClipTimeline`: split, trim/roll, snap, zoom, dip-to-black fade
- Editor undo / redo (buttons + Ctrl/Cmd+Z)
- Filmstrips: stable 8-frame source extract (trim/zoom crop in the widget)

Most applications should depend on
[`flutter_reels_composer`](../flutter_reels_composer). The main library
exports `ComposerNavigator`, `defaultEditorTools`, l10n, and chrome widgets.

Custom shells that assemble screens themselves must import the pages library
(not the main barrel, and not the MIT/GPL façades):

```dart
import 'package:flutter_reels_composer_ui/pages.dart';
```

That export is `CameraPage`, `GalleryPage`, and `EditorPage`.

No FFmpeg Kit dependency — thumbnails go through `FrameExtractorPort`.

Docs: [editor tools](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/extensions/editor-tools.md) ·
[customization](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/customization.md) ·
[performance](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/performance.md)

**Not on pub.dev yet.** Version 0.2.0.

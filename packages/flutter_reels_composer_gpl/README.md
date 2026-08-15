# flutter_reels_composer_gpl

**GPL-3.0-only** batteries-included facade. Bundles the x264 FFmpeg adapter.

```dart
import 'package:flutter_reels_composer_gpl/flutter_reels_composer_gpl.dart';

final result = await FlutterReelsComposerGpl.open(context);
```

`ComposerConfig` is the same object as the MIT facade. Stable surface:
`FlutterReelsComposerGpl.open`, `ComposerConfig`, catalogs, theme, l10n,
ports, `EditorTool` / `defaultEditorTools`, `ComposerNavigator`. Pages
(`CameraPage`, `GalleryPage`, `EditorPage`) are **not** on this barrel —
import `package:flutter_reels_composer_ui/pages.dart`.

Defaults:

- `FfmpegGplExportPort` (`libx264`)
- `FfmpegGplFrameExtractor` when `frameExtractor` is `NoopFrameExtractor`
- `LocalComposerEngine` + `FileDraftStore`

## Mutually exclusive with the MIT facade

Do **not** depend on `flutter_reels_composer` in the same app. The two facades
pull `ffmpeg_kit_flutter_new_min` vs `ffmpeg_kit_flutter_new_min_gpl`.

Review GPL-3.0 obligations before shipping.

Docs: [licensing](https://github.com/allochat/flutter_reels_composer/blob/main/docs/licensing.md) ·
[ComposerConfig](https://github.com/allochat/flutter_reels_composer/blob/main/docs/api/composer-config.md)

**Not on pub.dev yet.** Version 0.2.0.

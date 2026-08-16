# Customization

## Drop-in flow

`FlutterReelsComposer.open` owns camera, gallery, editor, preview, drafts,
frame thumbnails, photo-to-video conversion, and LGPL export:

```dart
final result = await FlutterReelsComposer.open(
  context,
  config: ComposerConfig(
    theme: const ComposerTheme(accent: Colors.purple),
    maxDuration: const Duration(seconds: 90),
    musicCatalog: myMusic,
    templateCatalog: myTemplates,
    captionEngine: myCaptionEngine,
    extraTools: [MyStickerTool()],
    draftStore: myDraftStore,
    onEvent: analytics.track,
  ),
);
```

The host keeps authentication, upload, moderation, and publication.

Field-by-field: [api/composer-config.md](api/composer-config.md).

## Theme

`ComposerTheme.snapTikTok` is the default (black background, pink accent
`0xFFFF2D55`, dark `sheet` for dialogs and tool panels). Override any color
or `toolIconSize` / `recordButtonSize`.
The facade wraps the route in `theme.toThemeData()` (dark Material 3).

## Text and localization

Bundled languages: **English**, **French**, **Arabic** (`ComposerL10n`).
Pass `locale` to select one (`languageCode`), or implement `ComposerToolL10n`:

```dart
class AppComposerStrings implements ComposerToolL10n {
  @override
  String toolLabel(ComposerFeature feature) => appLabel(feature);

  @override
  String text(String key) => appTranslations[key] ?? key;
}
```

Keys with variables use `{count}`, `{seconds}`, `{current}`, `{total}`, or
`{number}` (`textWith` on the l10n extension).

If both `l10n` and `locale` are set, **`l10n` wins**.

## Replace behavior

| Contract | Use |
| --- | --- |
| `ComposerEngine` | Capture, project state, preview, capabilities |
| `ExportPort` | Local, cloud, native, or vendor export |
| `FrameExtractorPort` | Thumbnails without FFmpeg in UI |
| `StillImageEncoderPort` | Photo-to-video (3 s clip in bundled exporters) |
| `CaptionEngine` | Local or remote transcription |
| `DraftStore` | Memory, files, database, or cloud |
| `EditorTool` | Add or replace panels by stable `id` |

## Custom shell

The facade is optional. Depend on `flutter_reels_composer_core`,
`flutter_reels_composer_ui`, and an engine.

The **main UI barrel** exports `ComposerNavigator`, `defaultEditorTools`,
l10n, `ToolRail`, `Filmstrip`, and `ClipTimeline`. Prefer
`ComposerNavigator` unless you own navigation.

`CameraPage`, `GalleryPage`, and `EditorPage` are **not** on that barrel
(or on the MIT/GPL façades). Import them from `pages.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';
import 'package:flutter_reels_composer_ui/pages.dart';

Widget buildCustomCamera({
  required ComposerConfig config,
  required ComposerEngine engine,
  required ValueChanged<ProjectDocument> onCaptured,
  required VoidCallback onOpenGallery,
  required VoidCallback onClose,
}) {
  return CameraPage(
    config: config,
    engine: engine,
    onCaptured: onCaptured,
    onOpenGallery: onOpenGallery,
    onClose: onClose,
  );
}
```

## FFmpeg choice

- `flutter_reels_composer`: LGPL facade, portable MPEG-4 default, optional
  hardware H.264
- `flutter_reels_composer_gpl`: GPL facade with `libx264`
- Custom `ExportPort`: no FFmpeg

Never combine both FFmpeg facades in one application. See
[licensing.md](licensing.md).

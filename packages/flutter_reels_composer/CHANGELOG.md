## 0.2.0

- Add `FlutterReelsComposer.open` with injectable `ComposerConfig`.
- Bundle camera-to-export UI, local engine, drafts, and LGPL FFmpeg export.
- Default video encoder is `mpeg4`; hardware H.264 is opt-in on the LGPL port.
- Do not depend on the GPL facade from this package.
- Does not re-export `CameraPage` / `GalleryPage` / `EditorPage` (use
  `package:flutter_reels_composer_ui/pages.dart`).

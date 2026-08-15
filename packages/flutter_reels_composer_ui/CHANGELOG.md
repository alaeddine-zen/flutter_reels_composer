## 0.2.0

- Add camera, gallery, and editor pages plus the default tool rail.
- Export `CameraPage`, `GalleryPage`, and `EditorPage` from `pages.dart`
  only — not from the main UI barrel.
- Add built-in tools: trim, filter, text, audio, cover, speed, captions,
  templates.
- Add `ComposerL10n` (en / fr / ar) and registry-driven `extraTools`.
- Export `ComposerNavigator` and `defaultEditorTools` from the main barrel.

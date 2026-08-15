## Unreleased

- Wire editor tools through `ComposerController.apply` / `applyLive`.
- Add undo / redo in the editor (buttons + Ctrl/Cmd+Z).
- Professional `ClipTimeline`: split, trim/roll handles, snap, zoom.
- Timeline fade toggle (dip-to-black, not overlapping crossfade).
- Cover panel: export quality chips 480 / 720 / 1080.
- Periodic editor autosave; typed `ExportCancelledException` handling.
- RTL overlay text; gallery photos import as `ImageClip` (no FFmpeg at import).

## 0.2.0

- Add camera, gallery, and editor pages plus the default tool rail.
- Export `CameraPage`, `GalleryPage`, and `EditorPage` from `pages.dart`
  only — not from the main UI barrel.
- Add built-in tools: trim, filter, text, audio, cover, speed, captions,
  templates.
- Add `ComposerL10n` (en / fr / ar) and registry-driven `extraTools`.
- Export `ComposerNavigator` and `defaultEditorTools` from the main barrel.

## Unreleased

- Add `Timeline`, `RenderGraph`, `ExportRecipe`, `ColorGrade`, schema v3.
- Deprecate `FfmpegFilters` in core (moved to export packages).
- `ComposerController.applyLive` coalesces slider/drag gestures into one undo
  entry. Editor tools should call `apply` / `applyLive`, not `applyMutation`.
- `SplitClipMutation`, `rollJunction`, `snapDuration` for the editor timeline.

## 0.2.0

- Add immutable `ProjectDocument` and `ProjectMutation` types.
- Add ports: `ComposerEngine`, `ExportPort`, `FrameExtractorPort`, `DraftStore`,
  `CaptionEngine`.
- Add `EditorTool` / `EditorToolRegistry`, catalogs, theme, analytics, and
  `ComposerConfig`.

## Unreleased

- Add `Timeline`, `RenderGraph`, `ExportRecipe`, `ColorGrade`, schema v3.
- Deprecate `FfmpegFilters` in core (moved to export packages).
- `ComposerController.applyLive` coalesces slider/drag gestures into one undo
  entry. Editor tools should call `apply` / `applyLive`, not `applyMutation`.
- `SplitClipMutation`, `rollJunction`, `snapDuration` for the editor timeline.
- Dip-to-black clip fade (`transitionOut`, `clipFadeOpacity`) — not a crossfade.
- Export quality ladders: `VideoSettings.sd480` / `hd720` / `fhd1080`.
- `SetVideoSettingsMutation`, `SetClipTransitionMutation`.
- `ComposerConfig.autosaveInterval` (default 8s; `Duration.zero` disables).
- `textLooksRtl` for overlay text direction.
- `ExportCancelledException` / `MissingClipException` from exporters.
- `CachedFrameExtractor` (LRU + serialized extract) and `ffmpegEscapePath`.
- `MemoryDraftStore` keeps an existing `updatedAt` (autosave-friendly).

## 0.2.0

- Add immutable `ProjectDocument` and `ProjectMutation` types.
- Add ports: `ComposerEngine`, `ExportPort`, `FrameExtractorPort`, `DraftStore`,
  `CaptionEngine`.
- Add `EditorTool` / `EditorToolRegistry`, catalogs, theme, analytics, and
  `ComposerConfig`.

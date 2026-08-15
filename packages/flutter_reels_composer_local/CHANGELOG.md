## Unreleased

- Preview color uses `ColorGrade` (same matrix as export).
- Preview overlays and dip-to-black fade come from `RenderGraph`.
- Photo clips play as stills (`ImageClip`) with `BoxFit.cover`.
- Pin `file_picker` to `>=8.0.0 <11.0.0` (avoid Kotlin 11.x CI break).
- Throttle preview UI notifies (~50 ms); cache `RenderGraph`; skip no-op
  fade/grade layers; detach the throttled video listener on clip change.
- `FileDraftStore` skips `touch()` when stamped and skips media copy when
  the destination already matches source length.

## 0.2.0

- Add `LocalComposerEngine` (camera, gallery, preview).
- Add `FileDraftStore` under the application support directory.
- Support injectable still-image encoding (no FFmpeg Kit dependency here).

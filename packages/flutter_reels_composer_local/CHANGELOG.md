## Unreleased

- Preview color uses `ColorGrade` (same matrix as export).
- Preview overlays and dip-to-black fade come from `RenderGraph`.
- Photo clips play as stills (`ImageClip`) with `BoxFit.cover`.
- Pin `file_picker` to `>=8.0.0 <11.0.0` (avoid Kotlin 11.x CI break).

## 0.2.0

- Add `LocalComposerEngine` (camera, gallery, preview).
- Add `FileDraftStore` under the application support directory.
- Support injectable still-image encoding (no FFmpeg Kit dependency here).

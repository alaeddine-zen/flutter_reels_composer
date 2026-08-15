## Unreleased

- Apply `ColorGrade` via `colorchannelmixer` (same 4×5 matrix as preview).
- Compile FFmpeg from `ExportRecipe`; reject unsupported operations.
- Canvas cover (`scale=increase,crop`) on **every** segment, including
  single-clip — matches preview `BoxFit.cover`.
- Dip-to-black `fade` filters; bitrate/fps from `VideoSettings`.
- Typed `MissingClipException` / `ExportCancelledException`; validate duet parent.
- Overlay `TextPainter` uses RTL when `textLooksRtl`.
- Volume mix clamped 0–1 to match preview.
- `CachedFrameExtractor` around FFmpeg thumbs; serialize extract jobs.
- Export waits on the `executeAsync` complete callback; `ffmpegEscapePath`.

## 0.2.0

- Add `FfmpegGplExportPort` using `-c:v libx264`.
- Add GPL frame extraction and still-image encoding.
- GPL-3.0-only; mutually exclusive with the LGPL adapter.

## Unreleased

- Apply `ColorGrade` via `colorchannelmixer` (same 4×5 matrix as preview).
- Compile FFmpeg from `ExportRecipe`; reject unsupported operations.
- Canvas cover (`scale=increase,crop`) on **every** segment, including
  single-clip — matches preview `BoxFit.cover`.
- Dip-to-black `fade` filters; bitrate/fps from `VideoSettings`.
- Typed `MissingClipException` / `ExportCancelledException`; validate duet parent.
- Overlay `TextPainter` uses RTL when `textLooksRtl`.
- Volume mix clamped 0–1 to match preview.

## 0.2.0

- Add `FfmpegLgplExportPort`, frame extraction, and still-image encoding.
- Use LGPL-compatible encoders only: `mpeg4` default; optional
  `h264_videotoolbox` / `h264_mediacodec`.
- Do not use `libx264`.

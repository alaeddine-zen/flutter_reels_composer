## Unreleased

- Apply `ColorGrade` via `colorchannelmixer` (same 4×5 matrix as preview).
- Compile FFmpeg from `ExportRecipe`; reject unsupported operations.

## 0.2.0

- Add `FfmpegLgplExportPort`, frame extraction, and still-image encoding.
- Use LGPL-compatible encoders only: `mpeg4` default; optional
  `h264_videotoolbox` / `h264_mediacodec`.
- Do not use `libx264`.

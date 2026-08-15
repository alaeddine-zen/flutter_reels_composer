## Unreleased

- Apply `ColorGrade` via `colorchannelmixer` (same 4×5 matrix as preview).
- Compile FFmpeg from `ExportRecipe`; reject unsupported operations.

## 0.2.0

- Add `FfmpegGplExportPort` using `-c:v libx264`.
- Add GPL frame extraction and still-image encoding.
- GPL-3.0-only; mutually exclusive with the LGPL adapter.

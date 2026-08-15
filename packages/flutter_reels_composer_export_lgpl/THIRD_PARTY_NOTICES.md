# Third-party notices

This package invokes FFmpeg through `ffmpeg_kit_flutter_new_min`.
That dependency and its FFmpeg binaries are distributed under LGPL-3.0.
Applications must independently satisfy the corresponding LGPL obligations.

No GPL codec such as x264, x265, xvidcore, or vid.stab is used by this adapter.
The default video encoder is FFmpeg's native MPEG-4 encoder; optional hardware
H.264 uses platform encoders.

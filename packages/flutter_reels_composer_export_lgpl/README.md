# flutter_reels_composer_export_lgpl

LGPL FFmpeg export, frame extraction, and still-image encoding for Flutter
Reels Composer.

Uses `ffmpeg_kit_flutter_new_min`. **No GPL codecs** (`libx264`, x265, …).

| `FfmpegLgplVideoCodec` | Encoder |
| --- | --- |
| `mpeg4` (default) | `-c:v mpeg4` |
| `hardwareH264` | iOS `-c:v h264_videotoolbox`, Android `-c:v h264_mediacodec` |

```dart
ComposerConfig(
  exporter: FfmpegLgplExportPort(
    videoCodec: FfmpegLgplVideoCodec.hardwareH264,
  ),
)
```

Read [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) before distributing.
LGPL compliance is the host app’s responsibility.

Do not add this package alongside `flutter_reels_composer_export_gpl`.

Docs: [licensing](https://github.com/allochat/flutter_reels_composer/blob/main/docs/licensing.md)

**Not on pub.dev yet.** Version 0.2.0. Source is MIT; binaries are LGPL.

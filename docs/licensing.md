# Licensing and FFmpeg

This repository is a **mixed-license** monorepo. Choose one export stack per
app.

## Package licenses

| Path | License |
| --- | --- |
| Repository root `LICENSE` | MIT |
| `flutter_reels_composer` | MIT (bundles LGPL FFmpeg Kit) |
| `flutter_reels_composer_core` | MIT |
| `flutter_reels_composer_ui` | MIT |
| `flutter_reels_composer_local` | MIT |
| `flutter_reels_composer_export_lgpl` | MIT source; **FFmpeg LGPL binaries** |
| `flutter_reels_composer_export_gpl` | **GPL-3.0-only** + GPL FFmpeg / x264 |
| `flutter_reels_composer_gpl` | **GPL-3.0-only** |

Root MIT does **not** relicense the GPL packages. Do not copy GPL adapters
into MIT packages.

This is not legal advice. Confirm obligations with counsel before you ship.

## Default path (most apps): MIT + LGPL FFmpeg

```yaml
dependencies:
  flutter_reels_composer: # Git/path or ^0.2.0 after publish
```

```dart
FlutterReelsComposer.open(context);
```

Export uses `ffmpeg_kit_flutter_new_min` and `FfmpegLgplExportPort`.

| Encoder | Flag | Notes |
| --- | --- | --- |
| MPEG-4 Part 2 | `FfmpegLgplVideoCodec.mpeg4` | **Default.** FFmpeg native `mpeg4`. |
| Hardware H.264 | `FfmpegLgplVideoCodec.hardwareH264` | iOS `h264_videotoolbox`, Android `h264_mediacodec` |

There is **no `libx264`** on this path (that encoder is GPL).

If you distribute the LGPL FFmpeg binaries, you must meet LGPL terms
(typically dynamic linking and/or offering object files). See
[`THIRD_PARTY_NOTICES.md`](../packages/flutter_reels_composer_export_lgpl/THIRD_PARTY_NOTICES.md).

## Opt-in path: GPL + x264

```dart
import 'package:flutter_reels_composer_gpl/flutter_reels_composer_gpl.dart';

await FlutterReelsComposerGpl.open(context);
```

Uses `ffmpeg_kit_flutter_new_min_gpl` and `-c:v libx264` (e.g. `-preset
veryfast -crf 23`). Shipping this usually makes the **whole application** a
GPL work (source offer, same license for combined work, etc.).

## Never combine facades

`ffmpeg_kit_flutter_new_min` and `ffmpeg_kit_flutter_new_min_gpl` are
**mutually exclusive**. Do not depend on:

- `flutter_reels_composer` **and** `flutter_reels_composer_gpl`
- `flutter_reels_composer_export_lgpl` **and** `flutter_reels_composer_export_gpl`

in one app. The MIT facade must never gain a GPL export dependency.

## No FFmpeg

Implement `ExportPort` (and typically `StillImageEncoderPort` +
`FrameExtractorPort`) and pass them on `ComposerConfig`. `licenseKind` can be
`ExportLicenseKind.none`.

## Proprietary vendor SDKs

Keep proprietary camera/AR vendor SDKs in a **separate** repository. They are
not part of this MIT tree.

# Getting started

A host app can open a full camera-to-export flow with one call. This guide
matches **0.2.0** in this repository.

## 1. Requirements

- Dart `>=3.8.0 <4.0.0`, Flutter `>=3.32.0`
- Android or iOS device/emulator (no web/desktop)
- Camera, microphone, and photo library permissions — [permissions.md](permissions.md)

## 2. Add the package

Packages are **not on pub.dev yet**. Use Git (with overrides) or a path clone.

### Git

See the [root README](../README.md#quick-start) for the full `dependency_overrides`
block. Internal packages declare hosted `^0.2.0`; overrides are required until
publish.

### Local path (this monorepo)

```yaml
dependencies:
  flutter_reels_composer:
    path: ../flutter_reels_composer/packages/flutter_reels_composer
```

Copy `example/pubspec_overrides.yaml` (adjust relative paths) so `core`, `ui`,
`local`, and `export_lgpl` resolve to the same checkout.

After packages are published:

```yaml
dependencies:
  flutter_reels_composer: ^0.2.0
```

## 3. Permissions

Copy the Android `<uses-permission>` entries and iOS `NS*UsageDescription`
keys from [`example/`](../example/). CocoaPods hosts also need `PERMISSION_*`
macros. Details: [permissions.md](permissions.md).

## 4. Open the composer

```dart
import 'package:flutter/material.dart';
import 'package:flutter_reels_composer/flutter_reels_composer.dart';

Future<void> createReel(BuildContext context) async {
  final result = await FlutterReelsComposer.open(
    context,
    config: ComposerConfig(
      theme: const ComposerTheme(accent: Color(0xFFFF2D55)),
      maxDuration: const Duration(seconds: 60),
      locale: Localizations.localeOf(context),
    ),
  );
  if (result == null) return; // cancelled
  await uploadReel(result.videoFile, cover: result.coverFile);
}
```

`FlutterReelsComposer.open`:

1. Builds `LocalComposerEngine` unless you pass `engine`
2. Uses `FfmpegLgplExportPort` unless you pass `exporter`
3. Replaces `NoopFrameExtractor` with `FfmpegLgplFrameExtractor`
4. Loads the bundled effects pack, then any host `effectCatalog`
5. Loads templates from UI assets, or `TemplateCatalog.bundled` on failure
6. Pushes a fullscreen `ComposerNavigator` (camera → gallery → editor)
7. Disposes the engine on pop if the facade created it

The return value is `ComposerResult` or `null`.

Editor drafts flush every 8 seconds by default
(`ComposerConfig.autosaveInterval`). Pass `Duration.zero` to disable.
See [performance.md](performance.md) for preview/timeline costs.

## 5. Run the example

```bash
cd example
flutter pub get
flutter run
```

Tap **Open composer**. See [example/README.md](../example/README.md).

## Next

- [ComposerConfig](api/composer-config.md) — catalogs, tools, duet, analytics, autosave
- [Performance](performance.md) — preview, filmstrips, drafts
- [LGPL vs GPL](licensing.md) — do not mix facades
- [Extensibility](extensibility.md) — custom tools and exporters
- [Customization](customization.md) — theme, l10n, custom shell (`pages.dart`)

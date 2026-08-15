# Contributing

Thanks for helping improve Flutter Reels Composer. This monorepo is meant to
stay easy to clone, extend, and review.

## Requirements

- Flutter `>=3.32.0` (stable)
- Dart SDK `>=3.8.0 <4.0.0`
- Android and/or iOS toolchain for the example app

## Clone and bootstrap

```bash
git clone https://github.com/alaeddine-zen/flutter_reels_composer.git
cd flutter_reels_composer
```

Each package declares **hosted** `^0.2.0` sibling dependencies. Local
development uses `pubspec_overrides.yaml` so `flutter pub get` resolves to
`packages/*` paths. Do not delete those override files.

```bash
# Facade (pulls UI, local, LGPL export, core via overrides)
(cd packages/flutter_reels_composer && flutter pub get)

# Example host
(cd example && flutter pub get)
```

CI runs `flutter pub get` in every `packages/*` directory plus `example/`.

## Run the example

```bash
cd example
flutter pub get
flutter run
```

Grant camera, microphone, and photos access on the device/simulator.
See [`example/README.md`](example/README.md) and [`docs/permissions.md`](docs/permissions.md).

## Analyze, test, format

Match [`.github/workflows/ci.yml`](.github/workflows/ci.yml) before you open a PR:

```bash
# Format (CI fails on drift)
dart format --output=none --set-exit-if-changed packages example/lib

# Analyze every package
for package in packages/*; do
  (cd "$package" && flutter pub get && flutter analyze)
done

# Tests that CI runs
(cd packages/flutter_reels_composer_core && flutter test)
(cd packages/flutter_reels_composer_ui && flutter test)
(cd packages/flutter_reels_composer_export_lgpl && flutter test)
(cd example && flutter pub get && flutter analyze && flutter test)

# Optional: Android example APK (CI does this)
(cd example && flutter build apk --debug)
```

Format Dart you touch (`dart format packages example/lib`). Do not skip hooks.
If `flutter pub get` rewrites `analysis_options.yaml` (“Upgrading
analysis_options.yaml…”), **revert those files** before you commit.

## Package boundaries

| Package | May depend on | Must not contain |
| --- | --- | --- |
| `flutter_reels_composer_core` | Flutter widgets / `equatable` / `uuid` | Camera, FFmpeg, host product code |
| `flutter_reels_composer_ui` | `core` | FFmpeg Kit |
| `flutter_reels_composer_local` | `core` | FFmpeg Kit |
| `flutter_reels_composer_export_lgpl` | `core`, LGPL FFmpeg Kit (`mpeg4` / `h264_videotoolbox` / `h264_mediacodec`) | `libx264` / GPL Kit |
| `flutter_reels_composer_export_gpl` | `core`, GPL FFmpeg Kit | MIT facade |
| `flutter_reels_composer` | MIT packages + LGPL export | GPL packages |
| `flutter_reels_composer_gpl` | MIT packages + GPL export | LGPL export / MIT facade |

**Never mix GPL into the MIT facade.** Do not add
`flutter_reels_composer_gpl` or `flutter_reels_composer_export_gpl` as a
dependency of `flutter_reels_composer`. The two FFmpeg Kit binaries cannot
coexist in one app.

Do not vendor proprietary camera/AR SDKs in this tree.

## Adding an `EditorTool`

1. Implement `EditorTool` in the host app, or in `flutter_reels_composer_ui`
   only if it should ship as a built-in.
2. Give it a **stable `id`**. Reusing `trim`, `filter`, `text`, `audio`,
   `cover`, `speed`, `captions`, or `templates` **replaces** that built-in.
3. Map `feature` to a `ComposerFeature`. Host extras remain visible even when
   the local engine does not advertise that feature.
4. Mutate the project through `context.controller.apply(...)` with a
   `ProjectMutation`. Do not mutate `ProjectDocument` in place.
5. Register via `ComposerConfig(extraTools: [MyTool()])`.
6. Add a widget test if the tool lives in this repo (`packages/flutter_reels_composer_ui/test`).

Walkthrough: [`docs/extensions/editor-tools.md`](docs/extensions/editor-tools.md).

## Pull requests

- One concern per PR; keep diffs reviewable.
- Update the relevant package `CHANGELOG.md` and the [root changelog](CHANGELOG.md)
  when behavior changes.
- Add or extend tests for domain, planner, registry, or UI behavior you change.
- Do not commit secrets, `.env` files, or generated iOS `ephemeral/` noise.
- Confirm you did **not** introduce a GPL FFmpeg dependency into an MIT package.
- Fill in [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md).

## License

Contributions to MIT packages are MIT. Changes under
`packages/flutter_reels_composer_gpl` and
`packages/flutter_reels_composer_export_gpl` are GPL-3.0-only.

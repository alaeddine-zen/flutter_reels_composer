# Flutter Reels Composer example

Minimal host for the batteries-included MIT composer.

## Run

From the **repository root**:

```bash
cd example
flutter pub get
flutter run
```

Requirements: Flutter `>=3.32.0`, an Android emulator/device or iOS
simulator/device. Web and desktop are not supported.

`pubspec.yaml` depends on the local facade:

```yaml
flutter_reels_composer:
  path: ../packages/flutter_reels_composer
```

`pubspec_overrides.yaml` rewires hosted `^0.2.0` sibling packages to
`../packages/*`. Leave the overrides in place while developing in the monorepo.

The home screen calls `FlutterReelsComposer.open` with `ComposerTheme.snapTikTok`,
`TemplateCatalog.bundled`, `locale: Locale('en')`, and debug analytics prints.

## Permissions

Already declared in this example.

### Android

`android/app/src/main/AndroidManifest.xml`:

- `CAMERA`
- `RECORD_AUDIO`
- `READ_MEDIA_VIDEO`
- `READ_MEDIA_IMAGES`
- `READ_MEDIA_AUDIO`
- `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`)

### iOS (Swift Package Manager)

This example uses SPM (no `Podfile`). Usage strings in `ios/Runner/Info.plist`:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

`permission_handler` enables those groups from the usage keys under SPM.

### CocoaPods hosts

If you copy this example into a CocoaPods app, add to the `Podfile`:

```ruby
'PERMISSION_CAMERA=1',
'PERMISSION_MICROPHONE=1',
'PERMISSION_PHOTOS=1',
'PERMISSION_PHOTOS_ADD_ONLY=1',
```

See [docs/permissions.md](../docs/permissions.md).

## CI

`.github/workflows/ci.yml` analyzes this example, runs `flutter test`, and
builds a debug APK (`flutter build apk --debug`).

# Write a ComposerEngine

Implement `ComposerEngine` in `flutter_reels_composer_core`:

- `initialize` / `dispose`
- `createCaptureSession()` → `CapturePort`
- `createMediaPicker()` → `MediaPickerPort`
- `attachPreview()` → `PreviewPort`
- `applyMutation` / `loadProject` / `loadEffectPack`
- `capabilities`, `project`, `projectListenable`, `effectRegistry`

Export is **not** part of the engine. Implement `ExportPort` separately so
FFmpeg stays optional.

```dart
FlutterReelsComposer.open(
  context,
  config: ComposerConfig(
    engine: MyNativeEngine(),
    exporter: MyNativeExporter(),
  ),
);
```

The MIT facade constructs `LocalComposerEngine` when `engine` is null, and
passes `encodeStillImage` when the exporter implements `StillImageEncoderPort`.
If you inject an engine, **you** own its lifecycle (`ownsEngine` is false and
the facade will not `dispose` it).

`FakeComposerEngine` in core is the in-memory double for tests.

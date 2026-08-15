# flutter_reels_composer_core

MIT domain layer for Flutter Reels Composer: immutable `ProjectDocument`,
`ProjectMutation`s, capability gates, and ports.

Use this package to implement a custom `ComposerEngine`, `ExportPort`,
`FrameExtractorPort`, `DraftStore`, `CaptionEngine`, or `EditorTool`.

No camera, gallery, or FFmpeg Kit dependency.

Host apps should usually depend on
[`flutter_reels_composer`](../flutter_reels_composer) instead.

Docs: [architecture](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/architecture.md) ·
[extensibility](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/extensibility.md) ·
[ComposerConfig](https://github.com/alaeddine-zen/flutter_reels_composer/blob/main/docs/api/composer-config.md)

**Not on pub.dev yet.** Version 0.2.0 lives in this monorepo (`^0.2.0` +
`pubspec_overrides.yaml` for local development).

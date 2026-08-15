# Write an EditorTool

Built-in tool ids: `trim`, `filter`, `text`, `audio`, `cover`, `speed`,
`captions`, `templates`. A host tool with the same `id` **replaces** the
built-in. A new `id` is added to the rail.

```dart
class MyStickerTool implements EditorTool {
  const MyStickerTool();

  @override
  String get id => 'my_stickers';

  @override
  ComposerFeature get feature => ComposerFeature.stickers;

  @override
  IconData icon(BuildContext context) => Icons.emoji_emotions;

  @override
  String label(ComposerToolL10n l10n) =>
      l10n.toolLabel(ComposerFeature.stickers);

  @override
  Widget buildPanel(EditorToolContext context) {
    return MyStickerPanel(
      onApply: (sticker) {
        unawaited(
          context.controller.apply(
            AddTextLayerMutation(
              layerId: sticker.id,
              text: sticker.emoji,
            ),
          ),
        );
      },
    );
  }
}
```

Register it:

```dart
ComposerConfig(
  extraTools: [MyStickerTool()],
)
```

Host tools stay visible even when `LocalComposerEngine` does not advertise
their `ComposerFeature`. You own mutations and export support.

## Replace a built-in

```dart
class MyTrimTool implements EditorTool {
  @override
  String get id => 'trim';

  @override
  ComposerFeature get feature => ComposerFeature.trim;
  // ...
}
```

`EditorToolRegistry` keeps the last registration per id (extras win). You do
not fork `EditorPage`.

## EditorToolContext

Each panel receives:

| Field | Meaning |
| --- | --- |
| `controller` | `apply(ProjectMutation)` |
| `project` | Current immutable `ProjectDocument` |
| `preview` | `PreviewPort?` (trim/speed/cover need it) |
| `l10n` / `theme` / `config` | Host configuration |
| `selectedLayerId` / `onSelectedLayerId` | Text layer selection |
| `onClose` | Dismiss the panel |

`context.engine` is `controller.engine`.

## Tests

Registry merge is covered in `packages/flutter_reels_composer_ui/test`. Add a
test when you ship a built-in tool from this repo.

# ComposerConfig

Host integration object passed to `FlutterReelsComposer.open` /
`FlutterReelsComposerGpl.open`. Defined in
`packages/flutter_reels_composer_core/lib/src/api/composer_config.dart`.

The MIT facade fills unspecified ports:

| Field | Facade default |
| --- | --- |
| `engine` | `LocalComposerEngine` (photo encoder from exporter when possible) |
| `exporter` | `FfmpegLgplExportPort()` / GPL facade: `FfmpegGplExportPort()` |
| `frameExtractor` | If `NoopFrameExtractor`, LGPL/GPL FFmpeg extractor |
| `draftStore` | `FileDraftStore()` |
| `locale` | `config.locale` or `Localizations.maybeLocaleOf(context)` |

## Fields

| Field | Type | Default | Purpose |
| --- | --- | --- | --- |
| `engine` | `ComposerEngine?` | facade local engine | Capture, preview, mutations |
| `exporter` | `ExportPort?` | LGPL or GPL FFmpeg | Bake MP4 |
| `theme` | `ComposerTheme` | `ComposerTheme.snapTikTok` | Dark colors, accent, control sizes |
| `maxDuration` | `Duration` | 60 s | Engine init + trim cap |
| `recordPresets` | `List<Duration>` | 15, 30, 60 s | Camera duration chips |
| `musicCatalog` | `MusicCatalog` | empty | In-app music list (`sourcePath` on device) |
| `effectCatalog` | `EffectCatalog` | empty | Extra `EffectDescriptor`s (pack `host`) |
| `templateCatalog` | `TemplateCatalog` | empty → bundled assets | Overlay/filter/speed presets |
| `enabledFeatures` | `Set<ComposerFeature>` | `kDefaultV1Features` | Intersected with engine capabilities |
| `extraTools` | `List<EditorTool>` | `[]` | Add or replace tools by `id` |
| `parentPostUuid` | `String?` | null | Duet metadata; if set without video, UI shows parent-missing copy |
| `parentVideoPath` | `String?` | null | Local parent media for duet |
| `duetLayout` | `DuetLayout` | `none` | `split` or `pip` when a parent path is set |
| `captionEngine` | `CaptionEngine` | `NullCaptionEngine` | `transcribe(mediaPath, locale:)` |
| `frameExtractor` | `FrameExtractorPort` | `NoopFrameExtractor` then FFmpeg | Filmstrip / cover thumbs |
| `onEvent` | `ComposerAnalyticsCallback?` | null | `ComposerAnalyticsEvent` |
| `locale` | `Locale?` | inherited | Selects bundled `ComposerL10n` (`en`, `fr`, `ar`) |
| `l10n` | `ComposerToolL10n?` | `ComposerL10n.resolve(locale)` | Full string override |
| `draftStore` | `DraftStore?` | `FileDraftStore` | Save / list / restore |

Helpers:

- `config.isDuet` — parent path non-empty and `duetLayout.isActive`
- `config.duetParentMissing` — `parentPostUuid` set but duet cannot run

## ComposerTheme

```dart
const ComposerTheme({
  Color background = Color(0xFF000000),
  Color foreground = Color(0xFFFFFFFF),
  Color accent = Color(0xFFFF2D55),
  Color secondary = Color(0xFF2C2C2E),
  Color muted = Color(0x99FFFFFF),
  Color recordRed = Color(0xFFFF3B30),
  double toolIconSize = 26,
  double recordButtonSize = 78,
});
```

`toThemeData()` builds a dark Material 3 `ThemeData` wrapped around the
navigator.

## ComposerResult

```dart
class ComposerResult {
  final File videoFile;
  final File? coverFile;
  final ProjectSnapshot project;
  final Duration duration;
  final Map<String, dynamic> metadata;
  String? get filterId;
  String? get musicId;
}
```

`filterId` / `musicId` read the snapshot JSON. Upload and moderation stay in
the host.

## ComposerFeature (`kDefaultV1Features`)

Enabled by default: `recordVideo`, `importGallery`, `trim`, `colorFilters`,
`textOverlays`, `musicMix`, `cover`, `multiClip`, `speed`, `templates`,
`aiCaptions`, `duetPip`.

Present on the enum but **not** in the default set: `stickers`, `beauty`,
`arMasks`, `greenScreen`.

## Localization

Bundled `ComposerL10n` tables: English, French, Arabic (`languageCode`).
Unknown codes fall back to English. Interpolation placeholders: `{count}`,
`{seconds}`, `{current}`, `{total}`, `{number}`.

Implement `ComposerToolL10n` (`toolLabel`, `text`) to replace every built-in
string without forking UI.

## Example

```dart
ComposerConfig(
  theme: const ComposerTheme(accent: Colors.purple),
  maxDuration: const Duration(seconds: 90),
  locale: const Locale('en'),
  musicCatalog: myMusic,
  extraTools: [MyStickerTool()],
  captionEngine: MyCaptionEngine(),
  exporter: FfmpegLgplExportPort(
    videoCodec: FfmpegLgplVideoCodec.hardwareH264,
  ),
  onEvent: (e) => debugPrint(e.type.name),
)
```

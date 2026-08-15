# Performance

How the editor stays responsive while preview, timeline thumbnails, and
autosave run on device. Host `FlutterReelsComposer.open` is unchanged.

## Preview

The editor chrome (tool rail, Next, undo) listens to `projectListenable` and
`ComposerController` only. Playhead widgets (`ClipTimeline`, play icon,
`EditableTextLayers`) subscribe to `PreviewPort` separately.

`LocalPreviewPort` throttles `notifyListeners` to **50 ms** (~20 Hz) so a
60 fps `VideoPlayerController` does not rebuild overlays every frame.
`RenderGraph.fromProject` is cached until the project instance changes.
`Opacity` / `ColorFiltered` are skipped when fade is opaque and the grade is
inactive. The video layer sits in a `RepaintBoundary`.

Image clips use a 50 ms ticker (same cadence as the video throttle).

## Timeline filmstrips

Clip cells extract **8 frames of the full source** (`start: 0`,
`end: sourceDuration`). Trim and zoom crop that strip in the widget tree;
they do not change the FFmpeg cache key. Photo clips decode **one**
`Image.file`, not N copies of the same still.

`CachedFrameExtractor` (core) wraps the FFmpeg extractors:

- LRU of 48 completed keys
- coalesced in-flight requests
- **one** inner extract at a time (FFmpeg is serialized)

Disk JPEGs under the temp dir remain the durable cache.

## Drafts

`ComposerConfig.autosaveInterval` defaults to 8 s (`Duration.zero` disables).
Autosave skips when `project.updatedAt` has not changed. Periodic autosave
does **not** emit `draftSaved`.

`FileDraftStore.save` does not call `touch()` when `updatedAt` is already
set (mutations already stamp). Media files are copied only when the
destination is missing or the length differs.

## Export

`_runFfmpeg` completes from the FFmpeg Kit `executeAsync` callback and polls
only to honor cancel. Paths go through `ffmpegEscapePath` (`\`, `"`, `$`,
`` ` ``).

## Remaining costs (honest limits)

- **First** filmstrip for a new source still runs FFmpeg (sparse JPEGs).
  `prefetchTimelineThumbs` starts that work when the project loads so the
  timeline often hits cache. Verify: [verification.md](verification.md).
- Export is offline FFmpeg Kit, not a GPU timeline renderer.
- Duet parent is a second `VideoPlayer` (camera UI + editor preview widgets).
  Seeks use `duetSeekFromNotify` / `kDuetParentDriftThreshold`, not every tick.
- Music uses `just_audio`. Playhead mapping is `musicSeekTarget`. Drift ≥
  120 ms triggers a seek while playing (`_correctMusicClock`).
- No waveform widget and no voice-over UI.

How to prove each claim: [verification.md](verification.md). Audio mix:
[audio.md](audio.md).

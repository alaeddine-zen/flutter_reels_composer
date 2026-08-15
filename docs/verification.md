# Verifying remaining editor costs

How to **prove** preview/timeline/export behavior instead of guessing. Host
API is unchanged: `FlutterReelsComposer.open`.

Automated checks run in CI. Device checks need the [example](../example/) app.

## Automated (every PR)

From the repo root, after `flutter pub get` in each package:

```bash
dart format --output=none --set-exit-if-changed packages example/lib

(cd packages/flutter_reels_composer_core && flutter test)
(cd packages/flutter_reels_composer_ui && flutter test)
(cd packages/flutter_reels_composer_export_lgpl && flutter test)
(cd packages/flutter_reels_composer_local && flutter test)
```

| Claim | Test |
| --- | --- |
| Music seek = playhead + `startOffset` | `preview_clock_test` `musicSeekTarget` |
| Audio resync only if drift ≥ 120 ms | `shouldCorrectClock` |
| Duet ignores 50 ms ticks, seeks on scrub | `duetSeekFromNotify` |
| Looping parent wraps past its duration | `wrapLoopingClock` |
| Filmstrip prefetch = 8 frames, full source, skip photos | `prefetchTimelineThumbs` |
| FFmpeg thumbs LRU + one job at a time | `cached_frame_extractor_test` |
| Path escape (`\`, `"`, `$`, `` ` ``) | `ffmpeg_path_escape_test` |
| Draft skip-copy when length matches | `media_copy_test` (local) |
| Autosave keeps existing `updatedAt` | `draft_store_test` |
| Split / fade timeline | `clip_timeline_test` |

If you add a new extract call site, it **must** use `kTimelineThumbCount` /
`kTimelineThumbHeight` / `Duration.zero`…`sourceDuration` or the prefetch
cache will miss.

## Device checks (example app)

1. **Preview chrome vs playhead.** Play a clip. The tool rail and Next must
   not flicker. The playhead and pause icon must still move (~20 Hz).
2. **Music drift.** Add a catalog track, play 30 s, watch mouth vs beat.
   Correction fires only when `just_audio` vs video differ by ≥ 120 ms
   (`_correctMusicClock`).
3. **Duet.** Open with `parentVideoPath` + `DuetLayout.split`. Scrub the
   timeline: parent jumps. During play, parent is not seeked every frame
   (80 ms notify gate, 280 ms drift gate).
4. **Filmstrip.** Import a video, open the editor, trim and zoom. FFmpeg
   should not restart for that clip (same cache key). First load still
   extracts once — prefetch starts at project load.
5. **Autosave.** Edit nothing for 16 s: drafts folder should not recopy
   `source_*` files (mtime/size unchanged). Edit a trim: `project.json`
   updates, media copy skipped if length matches.
6. **Loop.** Default: composition restarts. `preview.setLooping(false)`
   pauses at the last frame (no silent API no-op).
7. **Music tool meter.** The bar is a **start-offset** meter (equal heights),
   not PCM. Drag “start”: the highlight moves; heights stay equal.

## What we do not fake

These stay **unsupported** until a real port exists. Export already throws
`UnsupportedExportException` rather than dropping them:

- Stickers / drawings as baked overlays
- Voice-over recording and mix
- `.cube` LUT files (color is a 4×5 matrix)
- GPU / native timeline exporter (bake is FFmpeg Kit)

Capability gates (`stickers`, `beauty`, …) are for **host** `extraTools`.

## Architecture leftover

`DuetStage` exists in both `flutter_reels_composer_ui` (camera) and
`flutter_reels_composer_local` (editor preview). The packages must not
depend on each other. Clock math is shared in core; keep the two widgets
in sync if you change layout.

# Audio

What the composer actually mixes. There is **no** waveform visualizer and
**no** voice-over recorder in this repository.

Host API is unchanged: `FlutterReelsComposer.open`.

## What ships

| Piece | Preview | Export |
| --- | --- | --- |
| Original clip audio | `VideoPlayer.setVolume` (0–1) | FFmpeg map / volume filter, clamped 0–1 |
| Music track | `just_audio` file + volume | FFmpeg second input, loop, mix |
| Music start | `AudioTrack.startOffset` | FFmpeg `-ss` / delay on the music input |
| Playhead sync | `musicSeekTarget` + resync if drift ≥ 120 ms | N/A (offline bake) |

Sources:

- In-app `MusicCatalog` (`sourcePath` already on device)
- Device picker (`file_picker` / `LocalMediaPicker.pickAudio`)

Editor controls (audio tool): original volume, music volume, start offset
slider, catalog list, remove. Camera can attach a track before record.

## What is not in the tree

| Removed / never shipped | Why |
| --- | --- |
| Waveform / PCM bars | Would require a real decoder port; a RNG strip was deleted |
| Voice-over record + mix | `AudioTrackKind.voiceover` exists so export can **reject** it |
| Karaoke / auto-captions | Only if the host injects a `CaptionEngine` with `canTranscribe` |

If a project contains a voice-over track, `ExportRecipe` lists
`ExportOperationKind.voiceover` and the FFmpeg adapters throw
`UnsupportedExportException`. Same for sticker overlays.

## Host wiring

```dart
ComposerConfig(
  musicCatalog: MusicCatalog(tracks: [
    MusicTrack(
      id: 'beat_1',
      title: 'Night Drive',
      artist: 'Catalog',
      sourcePath: '/path/to/audio.m4a',
      duration: const Duration(seconds: 180),
    ),
  ]),
)
```

Empty catalog is valid: the user can still import from the device.

## Checks

Unit: `preview_clock_test` (`musicSeekTarget`, drift threshold).
Device: [verification.md](verification.md) items 2 (music drift) and the
audio tool sliders.

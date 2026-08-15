import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';
import '../../widgets/music_waveform.dart';

/// Applies music mutations only — preview playback is owned by LocalPreviewPort.
class AudioToolPanel extends StatefulWidget {
  const AudioToolPanel({
    super.key,
    required this.theme,
    required this.controller,
    required this.catalog,
    required this.selectedMusicId,
    this.preview,
  });

  final ComposerTheme theme;
  final ComposerController controller;
  final MusicCatalog catalog;
  final String? selectedMusicId;
  final PreviewPort? preview;

  ComposerEngine get engine => controller.engine;

  @override
  State<AudioToolPanel> createState() => _AudioToolPanelState();
}

class _AudioToolPanelState extends State<AudioToolPanel> {
  double _musicVolume = 1.0;
  double _originalVolume = 0.35;
  double _startOffsetMs = 0;
  MediaPickerPort? _picker;
  String? _importedTitle;
  bool _picking = false;

  AudioTrack? get _musicTrack {
    for (final t in widget.engine.project.audioTracks) {
      if (t.kind == AudioTrackKind.music) return t;
    }
    return null;
  }

  AudioTrack? get _originalTrack {
    for (final t in widget.engine.project.audioTracks) {
      if (t.kind == AudioTrackKind.original) return t;
    }
    return null;
  }

  String? get _effectiveMusicPath {
    final fromProject = _musicTrack?.sourcePath;
    if (fromProject != null && fromProject.isNotEmpty) return fromProject;
    final id = widget.selectedMusicId;
    if (id == null) return null;
    return widget.catalog.byId(id)?.sourcePath;
  }

  bool get _hasSelection =>
      _effectiveMusicPath != null || widget.selectedMusicId != null;

  @override
  void initState() {
    super.initState();
    _picker = widget.engine.createMediaPicker();
    _hydrateFromProject();
  }

  @override
  void didUpdateWidget(covariant AudioToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMusicId != widget.selectedMusicId ||
        oldWidget.engine.project != widget.engine.project) {
      _hydrateFromProject();
    }
  }

  double get _maxStartMs {
    final id = widget.selectedMusicId ?? _musicTrack?.musicId;
    final catalogDur = id == null ? null : widget.catalog.byId(id)?.duration;
    final ms = (catalogDur ?? const Duration(seconds: 180)).inMilliseconds;
    return ms.clamp(1000, 600000).toDouble();
  }

  void _hydrateFromProject() {
    final music = _musicTrack;
    final original = _originalTrack;
    _musicVolume = music?.volume ?? 1.0;
    _originalVolume = original?.volume ?? 0.35;
    _startOffsetMs = (music?.startOffset.inMilliseconds ?? 0).toDouble().clamp(
      0,
      _maxStartMs,
    );
    final path = music?.sourcePath;
    if (path != null) {
      final catalogTrack = widget.catalog.byId(music?.musicId ?? '');
      _importedTitle =
          catalogTrack?.title ??
          (path.contains('/') ? path.split('/').last : path);
    } else {
      _importedTitle = null;
    }
  }

  @override
  void dispose() {
    _picker?.dispose();
    super.dispose();
  }

  Future<void> _select({
    String? musicId,
    String? sourcePath,
    String? title,
  }) async {
    setState(() {
      _importedTitle = title;
      // New track → reset start point (TikTok behavior).
      if (musicId != null || sourcePath != null) {
        _startOffsetMs = 0;
      }
    });
    await widget.controller.apply(
      SetMusicTrackMutation(
        musicId: musicId,
        sourcePath: sourcePath,
        volume: _musicVolume,
        originalVolume: _originalVolume,
        startOffset: Duration.zero,
      ),
    );
  }

  Future<void> _applyMusic({Duration? startOffset, bool live = false}) async {
    final mutation = SetMusicTrackMutation(
      musicId: widget.selectedMusicId ?? _musicTrack?.musicId,
      sourcePath: _effectiveMusicPath,
      volume: _musicVolume,
      originalVolume: _originalVolume,
      startOffset:
          startOffset ?? Duration(milliseconds: _startOffsetMs.round()),
    );
    if (live) {
      await widget.controller.applyLive(mutation);
    } else {
      await widget.controller.apply(mutation);
    }
    final preview = widget.preview;
    if (preview != null && startOffset != null) {
      await preview.seek(preview.position);
    }
  }

  Future<void> _applyVolumes({bool live = false}) => _applyMusic(live: live);

  Future<void> _pickFromDevice() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final audio = await _picker?.pickAudio();
      if (!mounted) return;
      if (audio == null) {
        // Cancelled or unsupported (e.g. DRM). Files picker on iOS.
        return;
      }
      await _select(
        musicId: 'local-${const Uuid().v4()}',
        sourcePath: audio.path,
        title: audio.title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.composerL10n.text('audioImportError')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.catalog.tracks;

    // Color lives on Material (not a DecoratedBox above ListTiles) so ink
    // splash assertions stay clean in debug / widget tests.
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _hasSelection ? 310 : 220,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      context.composerL10n.text('addSound'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_hasSelection)
                      TextButton(
                        onPressed: () => _select(),
                        child: Text(
                          'Retirer',
                          style: TextStyle(color: widget.theme.accent),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.composerL10n.text('original'),
                            style: TextStyle(
                              color: widget.theme.muted,
                              fontSize: 11,
                            ),
                          ),
                          Slider(
                            value: _originalVolume,
                            onChanged: (v) {
                              setState(() => _originalVolume = v);
                              _applyVolumes(live: true);
                            },
                            onChangeEnd: (_) => widget.controller.endLive(),
                            activeColor: widget.theme.accent,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Musique',
                            style: TextStyle(
                              color: widget.theme.muted,
                              fontSize: 11,
                            ),
                          ),
                          Slider(
                            value: _musicVolume,
                            onChanged: (v) {
                              setState(() => _musicVolume = v);
                              if (!_hasSelection) return;
                              _applyVolumes(live: true);
                            },
                            onChangeEnd: (_) => widget.controller.endLive(),
                            activeColor: widget.theme.accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasSelection) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: MusicWaveform(
                    seed:
                        _effectiveMusicPath ??
                        widget.selectedMusicId ??
                        'music',
                    progress: _maxStartMs <= 0
                        ? 0
                        : (_startOffsetMs / _maxStartMs).clamp(0.0, 1.0),
                    accent: widget.theme.accent,
                    height: 32,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.skip_next,
                        color: widget.theme.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.composerL10n.text('start'),
                        style: TextStyle(
                          color: widget.theme.muted,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _startOffsetMs.clamp(0, _maxStartMs),
                          min: 0,
                          max: _maxStartMs,
                          activeColor: widget.theme.accent,
                          inactiveColor: Colors.white24,
                          onChanged: (v) {
                            setState(() => _startOffsetMs = v);
                            _applyMusic(
                              startOffset: Duration(milliseconds: v.round()),
                              live: true,
                            );
                          },
                          onChangeEnd: (_) => widget.controller.endLive(),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _fmt(Duration(milliseconds: _startOffsetMs.round())),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: widget.theme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    ListTile(
                      dense: true,
                      leading: _picking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.library_music,
                              color: widget.theme.accent,
                            ),
                      title: Text(
                        context.composerL10n.text('chooseFromDevice'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _importedTitle ?? 'MP3, M4A, WAV…',
                        style: TextStyle(
                          color: widget.theme.muted,
                          fontSize: 12,
                        ),
                      ),
                      onTap: _picking ? null : _pickFromDevice,
                    ),
                    if (tracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Text(
                          context.composerL10n.text('audioImportHint'),
                          style: TextStyle(
                            color: widget.theme.muted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      ...tracks.map((track) {
                        final selected = track.id == widget.selectedMusicId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: widget.theme.secondary,
                          leading: const Icon(
                            Icons.music_note,
                            color: Colors.white70,
                          ),
                          title: Text(
                            track.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            track.artist,
                            style: TextStyle(
                              color: widget.theme.muted,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _select(
                            musicId: track.id,
                            sourcePath: track.sourcePath,
                            title: track.title,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

import 'duet_stage.dart';
import 'styled_overlay_text.dart';

class LocalPreviewPort extends PreviewPort {
  LocalPreviewPort({
    required ProjectDocument project,
    required EffectRegistry registry,
  }) : _project = project,
       _registry = registry;

  ProjectDocument _project;
  final EffectRegistry _registry;
  VideoPlayerController? _controller;
  final AudioPlayer _music = AudioPlayer();
  bool _disposed = false;
  VoidCallback? _clipListener;
  String? _loadedMusicPath;
  int _clipIndex = 0;
  bool _advancing = false;
  RenderGraph? _cachedGraph;
  ProjectDocument? _graphProject;
  DateTime? _lastUiNotify;
  VoidCallback? _throttledVideoListener;

  static const _uiNotifyInterval = Duration(milliseconds: 50);

  RenderGraph get renderGraph {
    if (_cachedGraph == null || !identical(_graphProject, _project)) {
      _cachedGraph = RenderGraph.fromProject(_project, registry: _registry);
      _graphProject = _project;
    }
    return _cachedGraph!;
  }

  void _notifyPreviewUi({bool force = false}) {
    if (_disposed) return;
    if (!force && _lastUiNotify != null) {
      final elapsed = DateTime.now().difference(_lastUiNotify!);
      if (elapsed < _uiNotifyInterval) return;
    }
    _lastUiNotify = DateTime.now();
    notifyListeners();
  }

  Future<void> _loadChain = Future<void>.value();
  int _loadGeneration = 0;
  Timer? _imageTicker;
  Duration _imageElapsed = Duration.zero;
  DateTime? _imageAnchor;
  bool _imagePlaying = false;

  @override
  ProjectDocument get project => _project;

  @override
  bool get isPlaying {
    final clip = _currentClip;
    if (clip?.kind == TimelineClipKind.image) return _imagePlaying;
    return _controller?.value.isPlaying ?? false;
  }

  TimelineClip? get _currentClip => _project.clips.isEmpty
      ? null
      : _project.clips[_clipIndex.clamp(0, _project.clips.length - 1)];

  Duration get _prefixDuration {
    var sum = Duration.zero;
    for (var i = 0; i < _clipIndex && i < _project.clips.length; i++) {
      sum += _project.clips[i].trimmedDuration;
    }
    return sum;
  }

  @override
  Duration get position {
    final clip = _currentClip;
    if (clip == null) return Duration.zero;
    if (clip.kind == TimelineClipKind.image) {
      return _prefixDuration + _imageLocalPosition(clip);
    }
    final raw = _controller?.value.position ?? Duration.zero;
    final relative = raw - clip.trimStart;
    final local = relative.isNegative ? Duration.zero : relative;
    final timelineLocal = Duration(
      microseconds: (local.inMicroseconds / clip.speed).round(),
    );
    return _prefixDuration + timelineLocal;
  }

  Duration _imageLocalPosition(TimelineClip clip) {
    var local = _imageElapsed;
    if (_imagePlaying && _imageAnchor != null) {
      local += DateTime.now().difference(_imageAnchor!);
    }
    if (local > clip.trimmedDuration) return clip.trimmedDuration;
    if (local.isNegative) return Duration.zero;
    return local;
  }

  @override
  Duration get duration => _project.duration;

  @override
  bool get isInitialized {
    final clip = _currentClip;
    if (clip?.kind == TimelineClipKind.image) return true;
    return _controller?.value.isInitialized ?? false;
  }

  AudioTrack? get _musicTrack {
    for (final t in _project.audioTracks) {
      if (t.kind == AudioTrackKind.music) return t;
    }
    return null;
  }

  AudioTrack? get _originalTrack {
    for (final t in _project.audioTracks) {
      if (t.kind == AudioTrackKind.original) return t;
    }
    return null;
  }

  Future<void> ensureInitialized() async {
    if (_disposed || isInitialized) return;
    if (_project.clips.isEmpty) return;
    _clipIndex = 0;
    await _loadClipAt(_clipIndex, autoplay: false);
  }

  void _attachVideoUiListener(VideoPlayerController controller) {
    _throttledVideoListener ??= () => _notifyPreviewUi();
    controller.addListener(_throttledVideoListener!);
  }

  void _detachVideoUiListener(VideoPlayerController controller) {
    final listener = _throttledVideoListener;
    if (listener != null) controller.removeListener(listener);
  }

  Future<void> _disposeVideoController() async {
    final previous = _controller;
    _controller = null;
    if (previous == null) return;
    _detachVideoUiListener(previous);
    if (_clipListener != null) previous.removeListener(_clipListener!);
    await previous.dispose();
  }

  void _startImageClock() {
    _pauseImageClock();
    _imagePlaying = true;
    _imageAnchor = DateTime.now();
    _imageTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_disposed) return;
      final clip = _currentClip;
      if (clip == null || clip.kind != TimelineClipKind.image) return;
      if (_imageLocalPosition(clip) >= clip.trimmedDuration) {
        unawaited(_advanceFromEnd(playing: true));
        return;
      }
      _notifyPreviewUi();
    });
    _notifyPreviewUi(force: true);
  }

  void _pauseImageClock() {
    if (_imagePlaying && _imageAnchor != null) {
      _imageElapsed += DateTime.now().difference(_imageAnchor!);
    }
    _imagePlaying = false;
    _imageAnchor = null;
    _imageTicker?.cancel();
    _imageTicker = null;
  }

  Future<void> _advanceFromEnd({required bool playing}) async {
    if (_disposed || _advancing) return;
    _advancing = true;
    try {
      if (_clipIndex < _project.clips.length - 1) {
        await _loadClipAt(_clipIndex + 1, autoplay: playing);
      } else {
        await _loadClipAt(0, autoplay: playing);
        await _seekMusicTo(Duration.zero);
      }
    } finally {
      _advancing = false;
    }
  }

  Future<void> _loadClipAt(int index, {required bool autoplay}) {
    final run = _loadChain.then((_) => _loadClipAtUnlocked(index, autoplay));
    _loadChain = run.catchError((_) {});
    return run;
  }

  Future<void> _loadClipAtUnlocked(int index, bool autoplay) async {
    if (_disposed || _project.clips.isEmpty) return;
    final generation = ++_loadGeneration;
    VideoPlayerController? next;
    try {
      _clipIndex = index.clamp(0, _project.clips.length - 1);
      final clip = _project.clips[_clipIndex];
      if (clip.kind == TimelineClipKind.image) {
        await _disposeVideoController();
        _pauseImageClock();
        _imageElapsed = Duration.zero;
        if (autoplay) {
          _startImageClock();
        }
        await _syncMusic(forceReload: _clipIndex == 0);
        if (!_disposed && generation == _loadGeneration) notifyListeners();
        return;
      }
      _pauseImageClock();
      next = VideoPlayerController.file(File(clip.sourcePath));
      await next.initialize();
      if (_disposed || generation != _loadGeneration) {
        await next.dispose();
        return;
      }
      await next.setLooping(false);
      await next.setPlaybackSpeed(clip.speed.clamp(0.3, 3.0));
      await next.setVolume((_originalTrack?.volume ?? 1.0).clamp(0.0, 1.0));
      await next.seekTo(clip.trimStart);
      _attachClipListener(next);
      final previous = _controller;
      _controller = next;
      _attachVideoUiListener(next);
      next = null;
      if (previous != null) {
        _detachVideoUiListener(previous);
        if (_clipListener != null) previous.removeListener(_clipListener!);
        await previous.dispose();
      }
      await _syncMusic(forceReload: _clipIndex == 0);
      if (autoplay && !_disposed && generation == _loadGeneration) {
        await _controller?.play();
        try {
          await _music.play();
        } catch (_) {}
      }
      if (!_disposed) notifyListeners();
    } catch (_) {
      await next?.dispose();
    }
  }

  void _attachClipListener(VideoPlayerController controller) {
    if (_clipListener != null) {
      controller.removeListener(_clipListener!);
    }
    _clipListener = () {
      if (_disposed || _advancing) return;
      final clip = _currentClip;
      if (clip == null || !controller.value.isInitialized) return;
      final pos = controller.value.position;
      if (pos < clip.trimEnd) return;

      if (_clipIndex < _project.clips.length - 1) {
        _advancing = true;
        unawaited(() async {
          try {
            await _loadClipAt(_clipIndex + 1, autoplay: true);
          } finally {
            _advancing = false;
          }
        }());
      } else {
        // Loop whole composition from start.
        _advancing = true;
        unawaited(() async {
          try {
            await _loadClipAt(0, autoplay: controller.value.isPlaying);
            await _seekMusicTo(Duration.zero);
          } finally {
            _advancing = false;
          }
        }());
      }
    };
    controller.addListener(_clipListener!);
  }

  Future<void> _syncMusic({bool forceReload = false}) async {
    if (_disposed) return;
    final track = _musicTrack;
    final path = track?.sourcePath;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      _loadedMusicPath = null;
      try {
        await _music.stop();
      } catch (_) {}
      return;
    }

    try {
      if (forceReload || _loadedMusicPath != path) {
        await _music.setFilePath(path);
        _loadedMusicPath = path;
      }
      await _music.setVolume((track?.volume ?? 1.0).clamp(0.0, 1.0));
      await _seekMusicTo(position);
      if (isPlaying) {
        await _music.play();
      } else {
        await _music.pause();
      }
    } catch (_) {}
  }

  Future<void> _seekMusicTo(Duration global) async {
    try {
      final offset = _musicTrack?.startOffset ?? Duration.zero;
      await _music.seek(offset + global);
    } catch (_) {}
  }

  void updateProject(ProjectDocument project) {
    if (_disposed) return;
    final oldPaths = _project.clips.map((c) => c.sourcePath).join('|');
    final newPaths = project.clips.map((c) => c.sourcePath).join('|');
    final oldSpeeds = _project.clips.map((c) => c.speed).join('|');
    final newSpeeds = project.clips.map((c) => c.speed).join('|');
    final oldMusic = _musicTrack?.sourcePath;
    final oldMusicVol = _musicTrack?.volume;
    final oldMusicOffset = _musicTrack?.startOffset;
    final oldOriginalVol = _originalTrack?.volume;
    final oldTimelinePos = position;
    _project = project;
    _cachedGraph = null;
    _graphProject = null;
    if (newPaths != oldPaths) {
      _pauseImageClock();
      final old = _controller;
      _controller = null;
      if (old != null) {
        _detachVideoUiListener(old);
        if (_clipListener != null) old.removeListener(_clipListener!);
        old.dispose();
      }
      _clipIndex = 0;
      ensureInitialized();
    } else {
      final c = _controller;
      if (c != null) {
        _attachClipListener(c);
        final vol = (_originalTrack?.volume ?? 1.0).clamp(0.0, 1.0);
        c.setVolume(vol);
        if (oldSpeeds != newSpeeds) {
          final clip = _currentClip;
          if (clip != null) {
            c.setPlaybackSpeed(clip.speed.clamp(0.3, 3.0));
          }
          unawaited(seek(oldTimelinePos));
        }
      }
      final musicChanged =
          oldMusic != _musicTrack?.sourcePath ||
          oldMusicVol != _musicTrack?.volume ||
          oldMusicOffset != _musicTrack?.startOffset ||
          oldOriginalVol != _originalTrack?.volume;
      if (musicChanged) {
        unawaited(_syncMusic(forceReload: oldMusic != _musicTrack?.sourcePath));
      }
      notifyListeners();
    }
  }

  /// When true, preview shows the unfiltered original (compare gesture).
  bool _compareOriginal = false;

  @override
  void setCompareOriginal(bool value) {
    if (_compareOriginal == value) return;
    _compareOriginal = value;
    notifyListeners();
  }

  List<double> _matrixForFilter() {
    if (_compareOriginal) return kIdentityColorMatrix;
    return renderGraph.colorGrade.matrix;
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    await ensureInitialized();
    final clip = _currentClip;
    if (clip?.kind == TimelineClipKind.image) {
      _startImageClock();
      await _syncMusic();
      return;
    }
    await _controller?.play();
    await _syncMusic();
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _pauseImageClock();
    await _controller?.pause();
    try {
      await _music.pause();
    } catch (_) {}
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    await ensureInitialized();
    if (_project.clips.isEmpty) return;

    var remaining = position;
    if (remaining.isNegative) remaining = Duration.zero;
    var index = 0;
    while (index < _project.clips.length - 1 &&
        remaining > _project.clips[index].trimmedDuration) {
      remaining -= _project.clips[index].trimmedDuration;
      index++;
    }
    final clip = _project.clips[index];
    if (remaining > clip.trimmedDuration) remaining = clip.trimmedDuration;

    if (index != _clipIndex ||
        (_controller == null && clip.kind != TimelineClipKind.image)) {
      await _loadClipAt(index, autoplay: isPlaying);
    }
    if (clip.kind == TimelineClipKind.image) {
      _pauseImageClock();
      _imageElapsed = remaining;
      if (isPlaying) _startImageClock();
      await _seekMusicTo(position);
      if (!_disposed) notifyListeners();
      return;
    }
    final target =
        clip.trimStart +
        Duration(microseconds: (remaining.inMicroseconds * clip.speed).round());
    await _controller?.seekTo(target);
    await _seekMusicTo(position);
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Widget buildPreview({Key? key, bool showTextLayers = true}) {
    return _LocalPreviewView(
      key: key,
      controller: this,
      showTextLayers: showTextLayers,
    );
  }

  @override
  Future<void> disposePreview() async {
    if (_disposed) return;
    _disposed = true;
    _loadGeneration++;
    _pauseImageClock();
    final c = _controller;
    _controller = null;
    if (c != null) {
      _detachVideoUiListener(c);
      if (_clipListener != null) {
        c.removeListener(_clipListener!);
      }
      await c.dispose();
    }
    _clipListener = null;
    try {
      await _music.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    disposePreview();
    super.dispose();
  }
}

class _LocalPreviewView extends StatelessWidget {
  const _LocalPreviewView({
    super.key,
    required this.controller,
    this.showTextLayers = true,
  });

  final LocalPreviewPort controller;
  final bool showTextLayers;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final matrix = controller._matrixForFilter();
        final pos = controller.position;
        final graph = controller.renderGraph;
        final fade = graph.fadeOpacityAt(pos);
        final clip = controller._currentClip;
        final vc = controller._controller;
        final isImage = clip?.kind == TimelineClipKind.image;
        if (!isImage && (vc == null || !vc.value.isInitialized)) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        Widget video;
        if (isImage) {
          video = Image.file(
            File(clip!.sourcePath),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
          );
        } else {
          video = RepaintBoundary(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: vc!.value.size.width,
                height: vc.value.size.height,
                child: VideoPlayer(vc),
              ),
            ),
          );
        }
        if (fade < 0.999) {
          video = Opacity(opacity: fade, child: video);
        }
        if (!controller._compareOriginal && graph.colorGrade.isActive) {
          video = ColorFiltered(
            colorFilter: ColorFilter.matrix(matrix),
            child: video,
          );
        }
        video = DuetStage(
          layout: controller.project.duetLayout,
          parentVideoPath: controller.project.parentVideoPath,
          playParent: controller.isPlaying,
          seekTo: pos,
          child: video,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            video,
            if (showTextLayers)
              ...graph
                  .overlaysAt(pos)
                  .where((l) => l.type == VisualLayerType.text)
                  .map((layer) {
                    return Align(
                      alignment: Alignment(
                        (layer.normalizedPosition.dx - 0.5) * 2,
                        (layer.normalizedPosition.dy - 0.5) * 2,
                      ),
                      child: StyledOverlayText(layer: layer),
                    );
                  }),
          ],
        );
      },
    );
  }
}

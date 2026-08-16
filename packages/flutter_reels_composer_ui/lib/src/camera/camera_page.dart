import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../l10n/composer_l10n.dart';
import '../widgets/duet_layout_chip.dart';
import '../widgets/duet_stage.dart';
import '../widgets/filmstrip.dart';
import '../widgets/record_button.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    required this.config,
    required this.engine,
    required this.onCaptured,
    required this.onOpenGallery,
    required this.onClose,
    this.initialTemplate,
    this.onTemplateChanged,
  });

  final ComposerConfig config;
  final ComposerEngine engine;
  final ValueChanged<ProjectDocument> onCaptured;
  final VoidCallback onOpenGallery;
  final VoidCallback onClose;
  final ReelTemplate? initialTemplate;
  final ValueChanged<ReelTemplate?>? onTemplateChanged;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late final CapturePort _session;
  StreamSubscription<Duration>? _progressSub;
  StreamSubscription<CapturedMedia>? _finishedSub;
  CapturePermissionStatus? _permission;
  Duration _elapsed = Duration.zero;
  Duration _max = const Duration(seconds: 60);
  bool _recording = false;
  bool _handlingCapture = false;
  bool _discardNextCapture = false;
  bool _countdownEnabled = false;
  bool _countdown = false;
  bool _countdownCancelled = false;
  int _countdownValue = 3;
  CaptureFlashMode _flash = CaptureFlashMode.off;
  String? _filterId;
  double _zoom = 0;
  double _zoomAtScaleStart = 0;
  Timer? _readyPoll;

  final List<TimelineClip> _segments = [];
  final AudioPlayer _musicPlayer = AudioPlayer();
  MediaPickerPort? _picker;
  String? _musicPath;
  String? _musicId;
  String? _musicTitle;
  bool _pickingMusic = false;
  bool _holdRecording = false;
  Timer? _discardClearTimer;
  ReelTemplate? _template;
  late DuetLayout _duetLayout;

  ComposerConfig get config => widget.config;

  List<LutColorEffectDescriptor> get _filters =>
      widget.engine.effectRegistry.colorFilters;

  Duration get _segmentsDuration => _segments.fold<Duration>(
    Duration.zero,
    (sum, c) => sum + c.trimmedDuration,
  );

  Duration get _budgetRemaining {
    final used = _segmentsDuration + (_recording ? _elapsed : Duration.zero);
    final left = _max - used;
    return left.isNegative ? Duration.zero : left;
  }

  bool get _canStartRecord =>
      _session.isReady &&
      !_countdown &&
      _budgetRemaining >= const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _max = config.recordPresets.contains(config.maxDuration)
        ? config.maxDuration
        : config.recordPresets.last;
    _session = widget.engine.createCaptureSession();
    _picker = widget.engine.createMediaPicker();
    _template = widget.initialTemplate;
    _duetLayout = config.isDuet
        ? (config.duetLayout.isActive ? config.duetLayout : DuetLayout.split)
        : DuetLayout.none;
    _bootstrap();
    _readyPoll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _session.isReady) {
        if (mounted && _session.isReady) setState(() {});
        _readyPoll?.cancel();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheckPermissions());
      unawaited(_resumeMusicIfNeeded());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_countdown) _cancelCountdown();
      unawaited(_musicPlayer.pause());
      if (_recording) {
        _discardNextCapture = true;
        unawaited(_session.stopRecording());
      }
    }
  }

  Future<void> _recheckPermissions() async {
    final status = await _session.ensurePermissions();
    if (!mounted) return;
    setState(() => _permission = status);
  }

  Future<void> _bootstrap() async {
    config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.opened),
    );
    if (config.isDuet) {
      config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.duetStarted,
          properties: {'layout': config.duetLayout.name},
        ),
      );
    }
    final status = await _session.ensurePermissions();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status != CapturePermissionStatus.granted) {
      config.onEvent?.call(
        const ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.permissionDenied,
        ),
      );
    }
    await _session.setMaxDuration(_budgetRemaining);
    _progressSub = _session.recordingProgress.listen((d) {
      if (!mounted) return;
      setState(() {
        _elapsed = d;
        _recording = _session.isRecording;
      });
      if (_recording && _budgetRemaining <= Duration.zero) {
        unawaited(_stop(discard: false));
      }
    });
    _finishedSub = _session.recordingFinished.listen(_onRecordingFinished);
  }

  void _onRecordingFinished(CapturedMedia media) {
    if (_handlingCapture || !mounted) return;
    _discardClearTimer?.cancel();
    if (_discardNextCapture) {
      _discardNextCapture = false;
      unawaited(_deleteQuietly(media.path));
      setState(() {
        _recording = false;
        _elapsed = Duration.zero;
        _holdRecording = false;
      });
      return;
    }
    _handlingCapture = true;
    final clip = TimelineClip(
      id: const Uuid().v4(),
      sourcePath: media.path,
      sourceDuration: media.duration,
    );
    setState(() {
      _segments.add(clip);
      _recording = false;
      _elapsed = Duration.zero;
      _handlingCapture = false;
      _holdRecording = false;
    });
    config.onEvent?.call(
      ComposerAnalyticsEvent(
        ComposerAnalyticsEventType.recordStopped,
        properties: {
          'durationMs': media.duration.inMilliseconds,
          'segments': _segments.length,
        },
      ),
    );
    unawaited(_session.setMaxDuration(_budgetRemaining));
    unawaited(_syncMusicPlayback());
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  Future<void> _goToEditor() async {
    if (_segments.isEmpty || _recording) return;
    await _musicPlayer.stop();
    var project = ProjectDocument(
      id: const Uuid().v4(),
      settings: VideoSettings.vertical9x16,
      clips: List<TimelineClip>.from(_segments),
      audioTracks: [
        AudioTrack(id: const Uuid().v4(), kind: AudioTrackKind.original),
      ],
      effects: [
        EffectInstance(
          id: const Uuid().v4(),
          effectId: 'normal',
          category: 'color',
        ),
      ],
    );
    // Seed via fromClip-equivalent fields using mutations for music/filter.
    if (_filterId != null && _filterId != 'normal') {
      project = applyProjectMutation(
        project,
        SetColorFilterMutation(_filterId!),
      );
    }
    if (_musicPath != null) {
      // Mute original to avoid double music (speaker bleed into mic).
      project = applyProjectMutation(
        project,
        SetMusicTrackMutation(
          musicId: _musicId,
          sourcePath: _musicPath,
          volume: 1.0,
          originalVolume: 0.0,
        ),
      );
    }
    if (config.parentVideoPath != null && config.parentVideoPath!.isNotEmpty) {
      project = applyProjectMutation(
        project,
        SetDuetLayoutMutation(
          layout: _duetLayout.isActive ? _duetLayout : DuetLayout.split,
          parentVideoPath: config.parentVideoPath,
        ),
      );
    }
    if (_template != null) {
      project = applyProjectMutation(
        project,
        ApplyTemplateMutation(_template!),
      );
      if (_musicPath == null) {
        final musicId = _template!.musicId;
        final track = musicId == null
            ? null
            : config.musicCatalog.byId(musicId);
        if (track != null && track.sourcePath.isNotEmpty) {
          project = applyProjectMutation(
            project,
            SetMusicTrackMutation(
              musicId: track.id,
              sourcePath: track.sourcePath,
              volume: 1.0,
              originalVolume: 0.35,
            ),
          );
        }
      }
    }
    widget.onCaptured(project.touch());
  }

  void _undoLastSegment() {
    if (_segments.isEmpty || _recording) return;
    HapticFeedback.selectionClick();
    final removed = _segments.removeLast();
    setState(() {});
    unawaited(_deleteQuietly(removed.sourcePath));
    unawaited(_session.setMaxDuration(_budgetRemaining));
  }

  Future<void> _openTemplateSheet() async {
    if (_recording || _countdown) return;
    final catalog = config.templateCatalog.templates.isEmpty
        ? TemplateCatalog.bundled
        : config.templateCatalog;
    final chosen = await showModalBottomSheet<_TemplateChoice>(
      context: context,
      backgroundColor: config.theme.sheet,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  ctx.composerL10n.text('templates'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              for (final t in catalog.templates)
                ListTile(
                  leading: Icon(
                    Icons.dashboard_customize_outlined,
                    color: _template?.id == t.id
                        ? config.theme.accent
                        : Colors.white70,
                  ),
                  title: Text(
                    t.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, _TemplateChoice(t)),
                ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, const _TemplateChoice(null)),
                child: Text(ctx.composerL10n.text('none')),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || chosen == null) return;
    setState(() => _template = chosen.template);
    widget.onTemplateChanged?.call(_template);
    if (_template != null) {
      config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.templateApplied,
          properties: {'templateId': _template!.id, 'source': 'camera'},
        ),
      );
    }
  }

  Future<void> _openSoundSheet() async {
    if (_recording || _countdown) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: config.theme.sheet,
      showDragHandle: true,
      builder: (ctx) {
        final tracks = config.musicCatalog.tracks;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.composerL10n.text('addSound'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.library_music, color: config.theme.accent),
                title: Text(
                  context.composerL10n.text('chooseFromDevice'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _musicTitle ?? context.composerL10n.text('audioFormats'),
                  style: TextStyle(color: config.theme.muted, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickMusicFromDevice();
                },
              ),
              if (_musicPath != null)
                ListTile(
                  leading: const Icon(Icons.music_off, color: Colors.white70),
                  title: Text(
                    context.composerL10n.text('removeSound'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _clearMusic();
                  },
                ),
              ...tracks.map(
                (t) => ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.white70),
                  title: Text(
                    t.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    t.artist,
                    style: TextStyle(color: config.theme.muted, fontSize: 12),
                  ),
                  selected: t.id == _musicId,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _setMusic(
                      id: t.id,
                      path: t.sourcePath,
                      title: t.title,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickMusicFromDevice() async {
    if (_pickingMusic) return;
    setState(() => _pickingMusic = true);
    try {
      final audio = await _picker?.pickAudio();
      if (!mounted) return;
      if (audio == null) return;
      await _setMusic(
        id: 'local-${const Uuid().v4()}',
        path: audio.path,
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
      if (mounted) setState(() => _pickingMusic = false);
    }
  }

  Future<void> _setMusic({
    required String id,
    required String path,
    required String title,
  }) async {
    setState(() {
      _musicId = id;
      _musicPath = path;
      _musicTitle = title;
    });
    config.onEvent?.call(
      ComposerAnalyticsEvent(
        ComposerAnalyticsEventType.musicSelected,
        properties: {'musicId': id, 'fromCamera': true},
      ),
    );
    try {
      await _musicPlayer.setFilePath(path);
      await _musicPlayer.setLoopMode(LoopMode.one);
      await _musicPlayer.setVolume(1);
      await _musicPlayer.play();
    } catch (_) {}
  }

  Future<void> _clearMusic() async {
    setState(() {
      _musicId = null;
      _musicPath = null;
      _musicTitle = null;
    });
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> _resumeMusicIfNeeded() async {
    if (_musicPath == null || _recording) return;
    await _syncMusicPlayback();
  }

  Future<void> _syncMusicPlayback() async {
    if (_musicPath == null) return;
    try {
      // Keep a quiet preview during record to reduce mic bleed.
      await _musicPlayer.setVolume(_recording ? 0.15 : 1.0);
      if (_recording || !_musicPlayer.playing) {
        await _musicPlayer.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readyPoll?.cancel();
    _discardClearTimer?.cancel();
    _progressSub?.cancel();
    _finishedSub?.cancel();
    _musicPlayer.dispose();
    _picker?.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _discardAllSegments() async {
    final paths = _segments.map((s) => s.sourcePath).toList();
    _segments.clear();
    for (final path in paths) {
      await _deleteQuietly(path);
    }
  }

  Future<void> _toggleRecord() async {
    if (_countdown) {
      _cancelCountdown();
      return;
    }
    if (_recording) {
      await _stop(discard: false);
    } else if (_countdownEnabled) {
      await _startWithCountdown();
    } else {
      await _start();
    }
  }

  void _cancelCountdown() {
    if (!_countdown) return;
    setState(() {
      _countdownCancelled = true;
      _countdown = false;
    });
  }

  Future<void> _startWithCountdown() async {
    if (_countdown || _recording || !_canStartRecord) return;
    setState(() {
      _countdown = true;
      _countdownCancelled = false;
      _countdownValue = 3;
    });
    for (var i = 3; i >= 1; i--) {
      if (!mounted || _countdownCancelled || _recording) {
        if (mounted) setState(() => _countdown = false);
        return;
      }
      setState(() => _countdownValue = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted || _countdownCancelled) {
      if (mounted) setState(() => _countdown = false);
      return;
    }
    setState(() => _countdown = false);
    await _start();
  }

  Future<void> _start({bool fromHold = false}) async {
    if (_recording || !_canStartRecord) return;
    _discardNextCapture = false;
    _discardClearTimer?.cancel();
    _holdRecording = fromHold;
    await _session.setMaxDuration(_budgetRemaining);
    await _syncMusicPlayback();
    config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.recordStarted),
    );
    final started = await _session.startRecording();
    if (!mounted) return;
    setState(() {
      _recording = started;
      if (!started) {
        _elapsed = Duration.zero;
        _holdRecording = false;
      }
    });
    if (started) await _syncMusicPlayback();
  }

  Future<void> _stop({required bool discard}) async {
    if (!_recording) return;
    _discardNextCapture = discard;
    _discardClearTimer?.cancel();
    if (discard) {
      // Safety: never leave discard stuck if finished event never arrives.
      _discardClearTimer = Timer(const Duration(seconds: 20), () {
        _discardNextCapture = false;
      });
    }
    try {
      final media = await _session.stopRecording();
      if (media == null) {
        _discardNextCapture = false;
        _discardClearTimer?.cancel();
      }
    } catch (error) {
      debugPrint('CameraPage: stopRecording failed: $error');
      _discardNextCapture = false;
      _discardClearTimer?.cancel();
    }
    if (!mounted) return;
    setState(() {
      _recording = _session.isRecording;
      if (!_recording) {
        _elapsed = Duration.zero;
        _holdRecording = false;
      }
    });
    if (!_recording) unawaited(_syncMusicPlayback());
  }

  Future<void> _cycleFlash() async {
    const modes = CaptureFlashMode.values;
    final next = modes[(_flash.index + 1) % modes.length];
    await _session.setFlash(next);
    if (!mounted) return;
    setState(() => _flash = next);
  }

  Future<void> _selectFilter(String? id) async {
    HapticFeedback.selectionClick();
    setState(() => _filterId = id);
    await _session.setLiveFilter(id);
  }

  List<double> _matrixFor(String? id) {
    final desc = widget.engine.effectRegistry[id ?? 'normal'];
    if (desc is LutColorEffectDescriptor) return desc.matrix;
    return const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  }

  Future<void> _confirmLeave(VoidCallback action) async {
    if (_countdown) {
      _cancelCountdown();
      return;
    }
    if (!_recording && _segments.isEmpty) {
      action();
      return;
    }
    final l10n = context.composerL10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.theme.sheet,
        title: Text(
          l10n.text('leaveConfirm'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.text(
            _recording && _segments.isEmpty
                ? 'discardRecording'
                : 'discardSegments',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.text('stay')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.text('leave'),
              style: TextStyle(color: config.theme.accent),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (_recording) await _stop(discard: true);
      await _discardAllSegments();
      if (mounted) action();
    }
  }

  IconData get _flashIcon {
    switch (_flash) {
      case CaptureFlashMode.off:
        return Icons.flash_off;
      case CaptureFlashMode.on:
        return Icons.flash_on;
      case CaptureFlashMode.auto:
        return Icons.flash_auto;
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = (s ~/ 60).toString();
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = config.theme;
    final used = _segmentsDuration + (_recording ? _elapsed : Duration.zero);
    final progress = _max.inMilliseconds == 0
        ? 0.0
        : used.inMilliseconds / _max.inMilliseconds;

    if (_permission == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_permission != CapturePermissionStatus.granted) {
      return Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.videocam, size: 64, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  context.composerL10n.text('cameraPermission'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final s = await _session.ensurePermissions();
                    if (s == CapturePermissionStatus.permanentlyDenied) {
                      await openAppSettings();
                    }
                    if (!mounted) return;
                    setState(() => _permission = s);
                  },
                  child: Text(context.composerL10n.text('allow')),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave(widget.onClose);
      },
      child: Scaffold(
        backgroundColor: theme.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onDoubleTap: () {
                HapticFeedback.selectionClick();
                _session.flipCamera();
              },
              onScaleStart: (_) => _zoomAtScaleStart = _zoom,
              onScaleUpdate: (details) {
                if (details.pointerCount < 2 && details.scale == 1.0) return;
                final next = (_zoomAtScaleStart + (details.scale - 1) / 3)
                    .clamp(0.0, 1.0);
                _zoom = next;
                _session.setZoom(next);
              },
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_matrixFor(_filterId)),
                child: DuetStage(
                  layout: config.isDuet ? _duetLayout : DuetLayout.none,
                  parentVideoPath: config.parentVideoPath,
                  playParent: _recording,
                  seekTo: _recording ? null : Duration.zero,
                  child: _session.buildPreview(),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _confirmLeave(widget.onClose),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        if (_recording || _segments.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _recording
                                  ? theme.recordRed
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _fmt(used),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (config.isDuet && !_countdown) ...[
                          DuetLayoutChip(
                            label: context.composerL10n.text('duetSplit'),
                            selected: _duetLayout == DuetLayout.split,
                            accent: theme.accent,
                            onTap: _recording
                                ? null
                                : () => setState(
                                    () => _duetLayout = DuetLayout.split,
                                  ),
                          ),
                          const SizedBox(width: 6),
                          DuetLayoutChip(
                            label: context.composerL10n.text('duetPip'),
                            selected: _duetLayout == DuetLayout.pip,
                            accent: theme.accent,
                            onTap: _recording
                                ? null
                                : () => setState(
                                    () => _duetLayout = DuetLayout.pip,
                                  ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (config.enabledFeatures.contains(
                          ComposerFeature.templates,
                        ))
                          IconButton(
                            tooltip: context.composerL10n.text('templates'),
                            onPressed: _recording || _countdown
                                ? null
                                : _openTemplateSheet,
                            icon: Icon(
                              Icons.dashboard_customize_outlined,
                              color: _template != null
                                  ? theme.accent
                                  : Colors.white,
                            ),
                          ),
                        IconButton(
                          tooltip: context.composerL10n.text('music'),
                          onPressed: _recording || _countdown
                              ? null
                              : _openSoundSheet,
                          icon: Icon(
                            _musicPath != null
                                ? Icons.music_note
                                : Icons.music_note_outlined,
                            color: _musicPath != null
                                ? theme.accent
                                : Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: _countdownEnabled
                              ? context.composerL10n.text('countdownEnabled')
                              : context.composerL10n.text('countdown'),
                          onPressed: _recording
                              ? null
                              : () => setState(
                                  () => _countdownEnabled = !_countdownEnabled,
                                ),
                          icon: Icon(
                            Icons.timer_outlined,
                            color: _countdownEnabled
                                ? theme.accent
                                : Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _recording ? null : _cycleFlash,
                          icon: Icon(_flashIcon, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (config.duetParentMissing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        context.composerL10n.text('parentUnavailable'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.muted, fontSize: 11),
                      ),
                    ),
                  if (_musicTitle != null && !_countdown)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '♪ $_musicTitle',
                        style: TextStyle(color: theme.muted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_template != null && !_countdown)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _template!.name,
                        style: TextStyle(color: theme.accent, fontSize: 11),
                      ),
                    ),
                  const Spacer(),
                  if (_countdown)
                    GestureDetector(
                      onTap: _cancelCountdown,
                      child: Column(
                        children: [
                          Text(
                            '$_countdownValue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            context.composerL10n.text('cameraTouchToCancel'),
                            style: TextStyle(color: theme.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  if (!_session.isReady && !_countdown)
                    Text(
                      context.composerL10n.text('cameraPreparing'),
                      style: TextStyle(color: theme.muted),
                    ),
                  if (!_recording &&
                      !_countdown &&
                      _session.isReady &&
                      _segments.isEmpty)
                    Text(
                      context.composerL10n.text('cameraRecordHint'),
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                  const Spacer(),
                  if (_segments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _segments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, i) {
                                final seg = _segments[i];
                                return Stack(
                                  children: [
                                    VideoFrameThumb(
                                      sourcePath: seg.sourcePath,
                                      at: seg.trimStart,
                                      frameExtractor:
                                          widget.config.frameExtractor,
                                      size: 56,
                                      borderRadius: 10,
                                    ),
                                    Positioned(
                                      left: 4,
                                      bottom: 4,
                                      child: Text(
                                        '${seg.trimmedDuration.inSeconds}s',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 4,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: theme.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 4,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _segments.length; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                Container(
                                  width:
                                      (48 *
                                              (_segments[i]
                                                      .trimmedDuration
                                                      .inMilliseconds /
                                                  _max.inMilliseconds.clamp(
                                                    1,
                                                    1 << 30,
                                                  )))
                                          .clamp(8.0, 64.0),
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.accent,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_filters.isNotEmpty && !_recording && !_countdown)
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final f = _filters[index];
                          final selected = (_filterId ?? 'normal') == f.id;
                          return GestureDetector(
                            onTap: () => _selectFilter(f.id),
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? theme.accent
                                          : Colors.white24,
                                      width: selected ? 2.5 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(f.matrix),
                                    child: Container(
                                      color: const Color(0xFF667788),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.landscape,
                                        color: Colors.white70,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  f.name,
                                  style: TextStyle(
                                    color: selected
                                        ? theme.accent
                                        : theme.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!_recording && _segments.isEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: config.recordPresets.map((d) {
                        final selected = d == _max;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text('${d.inSeconds}s'),
                            selected: selected,
                            onSelected: _countdown
                                ? null
                                : (_) async {
                                    setState(() => _max = d);
                                    await _session.setMaxDuration(
                                      _budgetRemaining,
                                    );
                                  },
                            selectedColor: theme.accent,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : theme.muted,
                            ),
                            backgroundColor: theme.secondary,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        _SideButton(
                          enabled: !_recording && !_countdown,
                          onTap: () => _confirmLeave(widget.onOpenGallery),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.secondary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SideButton(
                          enabled: _segments.isNotEmpty && !_recording,
                          onTap: _undoLastSegment,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.secondary.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.undo, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        Opacity(
                          opacity: _canStartRecord || _recording || _countdown
                              ? 1
                              : 0.4,
                          child: RecordButton(
                            theme: theme,
                            progress: progress.clamp(0.0, 1.0),
                            isRecording: _recording,
                            onTap: _canStartRecord || _recording || _countdown
                                ? _toggleRecord
                                : () {},
                            onLongPressStart: () {
                              if (_canStartRecord) {
                                _start(fromHold: true);
                              }
                            },
                            onLongPressEnd: () {
                              if (_recording && _holdRecording) {
                                _stop(discard: false);
                              }
                            },
                          ),
                        ),
                        const Spacer(),
                        _SideButton(
                          enabled: !_recording && !_countdown,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _session.flipCamera();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.secondary.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cameraswitch,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SideButton(
                          enabled: _segments.isNotEmpty && !_recording,
                          onTap: _goToEditor,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _segments.isNotEmpty
                                  ? theme.accent
                                  : theme.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_pickingMusic)
              const ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChoice {
  const _TemplateChoice(this.template);
  final ReelTemplate? template;
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(opacity: enabled ? 1 : 0.35, child: child),
    );
  }
}

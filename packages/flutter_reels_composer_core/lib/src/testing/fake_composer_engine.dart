import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../api/composer_errors.dart';
import '../capabilities/composer_capabilities.dart';
import '../contracts/capture_port.dart';
import '../contracts/composer_engine.dart';
import '../contracts/export_port.dart';
import '../contracts/preview_port.dart';
import '../domain/effects/effect_descriptor.dart';
import '../domain/effects/effect_registry.dart';
import '../domain/project/project_document.dart';
import '../domain/project/project_mutation.dart';

class FakeComposerEngine implements ComposerEngine {
  FakeComposerEngine({
    EffectRegistry? registry,
    this.failExport = false,
    this.exportDelay = Duration.zero,
  }) : _registry = registry ?? EffectRegistry();

  final EffectRegistry _registry;
  final bool failExport;
  final Duration exportDelay;
  final ProjectChangeNotifier _listenable = ProjectChangeNotifier();
  ProjectDocument _project = ProjectDocument.empty();
  FakePreviewPort? _preview;
  bool _initialized = false;
  Duration maxDuration = const Duration(seconds: 60);
  FakeCapturePort? lastCaptureSession;
  int exportAttempts = 0;

  @override
  ComposerCapabilities get capabilities => ComposerCapabilities.localV1;

  @override
  Listenable get projectListenable => _listenable;

  @override
  EffectRegistry get effectRegistry => _registry;

  @override
  ProjectDocument get project => _project;

  @override
  Future<void> initialize(EngineInitConfig config) async {
    maxDuration = config.maxDuration;
    if (_registry.colorFilters.isEmpty) {
      _registry.register(
        LutColorEffectDescriptor(
          id: 'normal',
          name: 'Normal',
          matrix: const [
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ],
        ),
      );
    }
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    await _preview?.disposePreview();
    _preview = null;
    _initialized = false;
    _listenable.dispose();
  }

  @override
  CapturePort createCaptureSession() {
    _assertInit();
    final session = FakeCapturePort(maxDuration: maxDuration);
    lastCaptureSession = session;
    return session;
  }

  @override
  MediaPickerPort createMediaPicker() {
    _assertInit();
    return FakeMediaPicker();
  }

  @override
  PreviewPort attachPreview(ProjectDocument project) {
    _assertInit();
    _project = project;
    _preview?.disposePreview();
    final preview = FakePreviewPort(project: project);
    _preview = preview;
    return preview;
  }

  @override
  Future<void> applyMutation(ProjectMutation mutation) async {
    _project = applyProjectMutation(_project, mutation);
    _preview?.updateProject(_project);
    _listenable.tick();
  }

  @override
  Future<void> loadProject(ProjectDocument project) async {
    _project = project;
    _preview?.updateProject(project);
    _listenable.tick();
  }

  @override
  Future<void> loadEffectPack(EffectPack pack) async {
    _registry.registerAll(pack.effects);
  }

  ExportSession fakeExport(ProjectDocument project, ExportOptions options) {
    _assertInit();
    exportAttempts++;
    return ProgressiveExportSession((onProgress, cancelToken) async {
      onProgress(
        const ExportProgress(phase: ExportPhase.preparing, progress: 0.1),
      );
      if (cancelToken.isCancelled) throw const ExportCancelledException();
      if (failExport) throw StateError('Fake export failed');
      if (exportDelay > Duration.zero) {
        await Future<void>.delayed(exportDelay);
      }
      if (cancelToken.isCancelled) throw const ExportCancelledException();
      final dir = Directory.systemTemp.createTempSync('reels_fake_export_');
      final video = File('${dir.path}/reel.mp4')
        ..writeAsBytesSync(const [0, 0, 0, 0]);
      File? cover;
      if (options.includeCover) {
        cover = File('${dir.path}/cover.jpg')
          ..writeAsBytesSync(const [0xFF, 0xD8, 0xFF]);
      }
      onProgress(const ExportProgress(phase: ExportPhase.done, progress: 1));
      return ExportOutput(
        videoFile: video,
        coverFile: cover,
        duration: project.duration,
      );
    });
  }

  void _assertInit() {
    if (!_initialized) {
      throw StateError('FakeComposerEngine not initialized');
    }
  }
}

class FakeCapturePort implements CapturePort {
  FakeCapturePort({this.maxDuration = const Duration(seconds: 60)});

  @override
  Duration maxDuration;
  final _progress = StreamController<Duration>.broadcast();
  final _finished = StreamController<CapturedMedia>.broadcast();
  bool _recording = false;
  final bool _ready = true;
  Timer? _timer;
  DateTime? _started;
  String finishPath = '/tmp/fake_reel.mp4';

  @override
  Stream<Duration> get recordingProgress => _progress.stream;

  @override
  Stream<CapturedMedia> get recordingFinished => _finished.stream;

  @override
  bool get isRecording => _recording;

  @override
  bool get isReady => _ready;

  @override
  Future<CapturePermissionStatus> ensurePermissions() async =>
      CapturePermissionStatus.granted;

  @override
  Widget buildPreview({Key? key}) =>
      ColoredBox(key: key, color: const Color(0xFF222222));

  @override
  Future<bool> startRecording() async {
    if (!_ready || _recording) return false;
    _recording = true;
    _started = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final started = _started;
      if (started == null) return;
      final elapsed = DateTime.now().difference(started);
      _progress.add(elapsed);
      if (elapsed >= maxDuration) {
        unawaited(stopRecording());
      }
    });
    return true;
  }

  @override
  Future<CapturedMedia?> stopRecording() async {
    if (!_recording) return null;
    _timer?.cancel();
    final started = _started;
    _started = null;
    _recording = false;
    final elapsed = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    final media = CapturedMedia(path: finishPath, duration: elapsed);
    _finished.add(media);
    return media;
  }

  @override
  Future<void> flipCamera() async {}

  @override
  Future<void> setFlash(CaptureFlashMode mode) async {}

  @override
  Future<void> setZoom(double zoom) async {}

  @override
  Future<void> setMaxDuration(Duration duration) async {
    maxDuration = duration;
  }

  @override
  Future<void> setLiveFilter(String? filterId) async {}

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _progress.close();
    await _finished.close();
  }
}

class FakeMediaPicker implements MediaPickerPort {
  @override
  bool get permissionDenied => false;

  @override
  Future<List<GalleryAsset>> listVideos({
    int page = 0,
    int pageSize = 60,
  }) async => const [];

  @override
  Future<List<GalleryAsset>> listPhotos({
    int page = 0,
    int pageSize = 60,
  }) async => const [];

  @override
  Future<CapturedMedia?> importAsset(GalleryAsset asset) async => null;

  @override
  Future<PickedAudio?> pickAudio() async => null;

  @override
  Future<void> dispose() async {}
}

class FakePreviewPort extends PreviewPort {
  FakePreviewPort({required ProjectDocument project}) : _project = project;

  ProjectDocument _project;
  bool _playing = false;
  Duration _position = Duration.zero;
  bool looping = true;

  void updateProject(ProjectDocument project) {
    _project = project;
    notifyListeners();
  }

  @override
  ProjectDocument get project => _project;

  @override
  bool get isPlaying => _playing;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _project.duration;

  @override
  bool get isInitialized => true;

  @override
  Future<void> play() async {
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
  }

  @override
  Future<void> setLooping(bool looping) async {
    this.looping = looping;
  }

  @override
  Widget buildPreview({Key? key, bool showTextLayers = true}) =>
      ColoredBox(key: key, color: const Color(0xFF111111));

  @override
  Future<void> disposePreview() async {}
}

class FakeExportPort implements ExportPort {
  FakeExportPort(this.engine);

  final FakeComposerEngine engine;

  @override
  ExportLicenseKind get licenseKind => ExportLicenseKind.none;

  @override
  ExportSession export(ProjectDocument project, ExportOptions options) {
    return engine.fakeExport(project, options);
  }
}

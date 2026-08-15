import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

import 'capture/local_capture_session.dart';
import 'capture/local_media_picker.dart';
import 'preview/local_preview_controller.dart';

class LocalComposerEngine implements ComposerEngine {
  LocalComposerEngine({EffectRegistry? registry, this.photoClipEncoder})
    : _registry = registry ?? EffectRegistry();

  final EffectRegistry _registry;
  final Future<CapturedMedia?> Function(File image, Directory dir)?
  photoClipEncoder;
  final ProjectChangeNotifier _projectListenable = ProjectChangeNotifier();

  ProjectDocument _project = ProjectDocument.empty();
  LocalPreviewPort? _preview;
  EngineInitConfig? _config;
  bool _initialized = false;

  @override
  EffectRegistry get effectRegistry => _registry;

  @override
  Listenable get projectListenable => _projectListenable;

  @override
  ComposerCapabilities get capabilities => ComposerCapabilities.localV1;

  @override
  ProjectDocument get project => _project;

  @override
  Future<void> initialize(EngineInitConfig config) async {
    _config = config;
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    await _preview?.disposePreview();
    _preview = null;
    _initialized = false;
    _projectListenable.dispose();
  }

  @override
  CapturePort createCaptureSession() {
    _assertInit();
    return LocalCapturePort(
      maxDuration: _config?.maxDuration ?? const Duration(seconds: 60),
    );
  }

  @override
  MediaPickerPort createMediaPicker() {
    _assertInit();
    return LocalMediaPicker(photoClipEncoder: photoClipEncoder);
  }

  @override
  PreviewPort attachPreview(ProjectDocument project) {
    _assertInit();
    _project = project;
    final previous = _preview;
    _preview = null;
    previous?.disposePreview();
    final preview = LocalPreviewPort(project: project, registry: _registry);
    _preview = preview;
    preview.ensureInitialized();
    return preview;
  }

  @override
  Future<void> applyMutation(ProjectMutation mutation) async {
    _project = applyProjectMutation(_project, mutation);
    _preview?.updateProject(_project);
    _projectListenable.tick();
  }

  @override
  Future<void> loadProject(ProjectDocument project) async {
    _project = project;
    _preview?.updateProject(project);
    _projectListenable.tick();
  }

  @override
  Future<void> loadEffectPack(EffectPack pack) async {
    _registry.registerAll(pack.effects);
  }

  void _assertInit() {
    if (!_initialized) {
      throw StateError('LocalComposerEngine not initialized');
    }
  }
}

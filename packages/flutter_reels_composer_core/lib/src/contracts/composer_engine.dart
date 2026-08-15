import 'package:flutter/foundation.dart';

import '../capabilities/composer_capabilities.dart';
import '../domain/effects/effect_descriptor.dart';
import '../domain/effects/effect_registry.dart';
import '../domain/project/project_document.dart';
import '../domain/project/project_mutation.dart';
import 'capture_port.dart';
import 'export_port.dart';
import 'preview_port.dart';

class EngineInitConfig {
  const EngineInitConfig({
    this.maxDuration = const Duration(seconds: 60),
    this.tempDirectory,
  });

  final Duration maxDuration;
  final String? tempDirectory;
}

/// Pluggable capture / preview engine. Export is a separate [ExportPort].
abstract class ComposerEngine {
  ComposerCapabilities get capabilities;
  Listenable get projectListenable;
  EffectRegistry get effectRegistry;
  ProjectDocument get project;

  Future<void> initialize(EngineInitConfig config);
  Future<void> dispose();

  CapturePort createCaptureSession();
  MediaPickerPort createMediaPicker();
  PreviewPort attachPreview(ProjectDocument project);

  Future<void> applyMutation(ProjectMutation mutation);
  Future<void> loadProject(ProjectDocument project);
  Future<void> loadEffectPack(EffectPack pack);
}

class ProjectChangeNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}

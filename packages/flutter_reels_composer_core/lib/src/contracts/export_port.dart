import 'dart:async';
import 'dart:io';

import '../domain/effects/effect_registry.dart';
import '../domain/project/project_document.dart';

enum ExportLicenseKind { none, lgpl, gpl }

/// Optional capability for exporters that need the engine's resolved effects.
abstract interface class EffectRegistryAwareExportPort {
  void attachRegistry(EffectRegistry registry);
}

class ExportOptions {
  const ExportOptions({this.includeCover = true, this.outputDirectory});

  final bool includeCover;
  final Directory? outputDirectory;
}

enum ExportPhase { preparing, encoding, writingCover, done, failed }

class ExportProgress {
  const ExportProgress({
    required this.phase,
    required this.progress,
    this.message,
  });

  final ExportPhase phase;
  final double progress;
  final String? message;
}

class ExportOutput {
  const ExportOutput({
    required this.videoFile,
    this.coverFile,
    required this.duration,
  });

  final File videoFile;
  final File? coverFile;
  final Duration duration;
}

abstract class ExportSession {
  Stream<ExportProgress> get progress;
  Future<ExportOutput> get result;
  Future<void> cancel();
}

abstract class ExportPort {
  ExportLicenseKind get licenseKind;
  ExportSession export(ProjectDocument project, ExportOptions options);
}

class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class ProgressiveExportSession implements ExportSession {
  ProgressiveExportSession(this._runner) {
    _future = _run();
  }

  final Future<ExportOutput> Function(
    void Function(ExportProgress) onProgress,
    CancelToken cancelToken,
  )
  _runner;

  final _controller = StreamController<ExportProgress>.broadcast();
  final CancelToken _cancelToken = CancelToken();
  late final Future<ExportOutput> _future;

  Future<ExportOutput> _run() async {
    try {
      final out = await _runner(_controller.add, _cancelToken);
      await _controller.close();
      return out;
    } catch (e) {
      _controller.add(
        ExportProgress(
          phase: ExportPhase.failed,
          progress: 0,
          message: e.toString(),
        ),
      );
      await _controller.close();
      rethrow;
    }
  }

  @override
  Stream<ExportProgress> get progress => _controller.stream;

  @override
  Future<ExportOutput> get result => _future;

  @override
  Future<void> cancel() async {
    _cancelToken.cancel();
  }
}

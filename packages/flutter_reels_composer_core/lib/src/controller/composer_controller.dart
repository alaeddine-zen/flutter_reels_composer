import 'package:flutter/foundation.dart';

import '../contracts/composer_engine.dart';
import '../domain/project/project_document.dart';
import '../domain/project/project_mutation.dart';

/// Host-facing project state with undo / redo.
///
/// Editor UI and host [EditorTool]s must call [apply] / [applyLive] rather
/// than [ComposerEngine.applyMutation] so history stays complete.
class ComposerController extends ChangeNotifier {
  ComposerController(this._engine);

  static const int maxUndoDepth = 50;

  final ComposerEngine _engine;
  final List<ProjectDocument> _undo = [];
  final List<ProjectDocument> _redo = [];
  bool _live = false;

  ComposerEngine get engine => _engine;
  ProjectDocument get project => _engine.project;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// True while a continuous gesture ([applyLive]) is open.
  bool get isLive => _live;

  /// Discrete edit: one undo entry.
  Future<void> apply(ProjectMutation mutation) async {
    endLive();
    _pushUndo(_engine.project);
    _redo.clear();
    await _engine.applyMutation(mutation);
    notifyListeners();
  }

  /// Live preview of a slider / drag. The first call records one undo
  /// snapshot; later calls mutate without stacking. Call [endLive] on
  /// pointer-up (or the next [apply] / [undo] / [redo]).
  Future<void> applyLive(ProjectMutation mutation) async {
    if (!_live) {
      _pushUndo(_engine.project);
      _redo.clear();
      _live = true;
    }
    await _engine.applyMutation(mutation);
    notifyListeners();
  }

  /// Closes a live gesture. No-op if none is open.
  void endLive() {
    if (!_live) return;
    _live = false;
  }

  Future<void> load(ProjectDocument project) async {
    _live = false;
    _undo.clear();
    _redo.clear();
    await _engine.loadProject(project);
    notifyListeners();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    _live = false;
    _redo.add(_engine.project);
    await _engine.loadProject(_undo.removeLast());
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    _live = false;
    _undo.add(_engine.project);
    await _engine.loadProject(_redo.removeLast());
    notifyListeners();
  }

  void _pushUndo(ProjectDocument snapshot) {
    _undo.add(snapshot);
    while (_undo.length > maxUndoDepth) {
      _undo.removeAt(0);
    }
  }
}

import 'package:flutter/foundation.dart';

import '../contracts/composer_engine.dart';
import '../domain/project/project_document.dart';
import '../domain/project/project_mutation.dart';

/// Host-facing project state with a simple undo stack.
class ComposerController extends ChangeNotifier {
  ComposerController(this._engine);

  final ComposerEngine _engine;
  final List<ProjectDocument> _undo = [];
  final List<ProjectDocument> _redo = [];

  ComposerEngine get engine => _engine;
  ProjectDocument get project => _engine.project;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  Future<void> apply(ProjectMutation mutation) async {
    _undo.add(_engine.project);
    _redo.clear();
    await _engine.applyMutation(mutation);
    notifyListeners();
  }

  Future<void> load(ProjectDocument project) async {
    _undo.clear();
    _redo.clear();
    await _engine.loadProject(project);
    notifyListeners();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    _redo.add(_engine.project);
    await _engine.loadProject(_undo.removeLast());
    notifyListeners();
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    _undo.add(_engine.project);
    await _engine.loadProject(_redo.removeLast());
    notifyListeners();
  }
}

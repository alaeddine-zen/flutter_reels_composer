import '../capabilities/composer_capabilities.dart';
import '../capabilities/composer_feature.dart';
import 'editor_tool.dart';

class EditorToolRegistry {
  EditorToolRegistry({
    required List<EditorTool> builtins,
    List<EditorTool> extras = const [],
  }) : _tools = _merge(builtins, extras),
       _hostToolIds = Set.unmodifiable(extras.map((tool) => tool.id));

  final List<EditorTool> _tools;
  final Set<String> _hostToolIds;

  List<EditorTool> get all => _tools;

  /// Extra tools replace built-ins with the same id. This lets host apps
  /// customize a standard tool without forking the editor shell.
  static List<EditorTool> _merge(
    List<EditorTool> builtins,
    List<EditorTool> extras,
  ) {
    final byId = <String, EditorTool>{
      for (final tool in builtins) tool.id: tool,
    };
    for (final tool in extras) {
      byId[tool.id] = tool;
    }
    return List.unmodifiable(byId.values);
  }

  List<EditorTool> visible(CapabilityGate gate) {
    return List.unmodifiable(
      _tools.where(
        (tool) => _hostToolIds.contains(tool.id) || gate.allows(tool.feature),
      ),
    );
  }

  bool isVisible(EditorTool tool, CapabilityGate gate) =>
      _hostToolIds.contains(tool.id) || gate.allows(tool.feature);

  EditorTool? byId(String id) {
    for (final t in _tools) {
      if (t.id == id) return t;
    }
    return null;
  }

  EditorTool? byFeature(ComposerFeature feature) {
    for (final t in _tools) {
      if (t.feature == feature) return t;
    }
    return null;
  }
}

import 'package:flutter/widgets.dart';

import '../api/composer_config.dart';
import '../api/composer_theme.dart';
import '../capabilities/composer_feature.dart';
import '../contracts/composer_engine.dart';
import '../controller/composer_controller.dart';
import '../contracts/preview_port.dart';
import '../domain/project/project_document.dart';

class EditorToolContext {
  const EditorToolContext({
    required this.controller,
    required this.project,
    required this.preview,
    required this.l10n,
    required this.theme,
    required this.config,
    this.selectedLayerId,
    this.onSelectedLayerId,
    this.onClose,
  });

  final ComposerController controller;
  final ProjectDocument project;
  final PreviewPort? preview;
  final ComposerToolL10n l10n;
  final ComposerTheme theme;
  final ComposerConfig config;
  final String? selectedLayerId;
  final ValueChanged<String?>? onSelectedLayerId;
  final VoidCallback? onClose;

  ComposerEngine get engine => controller.engine;
}

/// Minimal strings a tool may need. Host UI supplies a richer l10n object.
abstract class ComposerToolL10n {
  String toolLabel(ComposerFeature feature);

  /// Resolves a UI string by a stable key. Custom host implementations can
  /// translate every built-in label without forking the package.
  String text(String key);
}

extension ComposerToolL10nInterpolation on ComposerToolL10n {
  String textWith(String key, Map<String, Object> values) {
    var value = text(key);
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }
}

/// One editor tool. Register extras via [EditorToolRegistry] / config.extraTools.
abstract class EditorTool {
  String get id;
  ComposerFeature get feature;
  IconData icon(BuildContext context);
  String label(ComposerToolL10n l10n);
  Widget buildPanel(EditorToolContext context);
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extraTools replace the builtin trim used by EditorPage', () {
    final registry = EditorToolRegistry(
      builtins: defaultEditorTools(),
      extras: const [_HostTrimTool()],
    );
    expect(registry.byId('trim'), isA<_HostTrimTool>());
    expect(registry.all.where((tool) => tool.id == 'trim'), hasLength(1));
  });

  test('ComposerL10n resolves keys, interpolates, and falls back', () {
    const en = ComposerL10n('en');
    const fr = ComposerL10n('fr');
    const unknown = ComposerL10n('zz');

    expect(en.text('exportFailed'), 'Export failed');
    expect(fr.text('exportFailed'), isNot(en.text('exportFailed')));
    expect(unknown.text('exportFailed'), 'Export failed');
    expect(en.text('not_a_real_key'), 'not_a_real_key');
    expect(en.textWith('addClips', {'count': 3}), 'Add 3 clip(s)');
    expect(en.text('undo'), 'Undo');
    expect(fr.text('undo'), 'Annuler');
    expect(en.text('redo'), 'Redo');
    expect(fr.text('newText'), 'Nouveau');
    expect(en.toolLabel(ComposerFeature.trim), 'Trim');
  });

  testWidgets('templates.json matches TemplateCatalog.bundled ids', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/templates/templates.json');
    final catalog = TemplateCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    expect(
      catalog.templates.map((t) => t.id),
      TemplateCatalog.bundled.templates.map((t) => t.id),
    );
    expect(catalog.byId('intro_trend')?.name, 'Trend intro');
  });
}

class _HostTrimTool implements EditorTool {
  const _HostTrimTool();

  @override
  String get id => 'trim';

  @override
  ComposerFeature get feature => ComposerFeature.trim;

  @override
  IconData icon(BuildContext context) => Icons.content_cut;

  @override
  String label(ComposerToolL10n l10n) => 'Host Trim';

  @override
  Widget buildPanel(EditorToolContext context) => const SizedBox.shrink();
}

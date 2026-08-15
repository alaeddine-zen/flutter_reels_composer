import 'package:flutter/material.dart';
import 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses each EditorTool icon, label, and id', (tester) async {
    EditorTool? selected;
    const tools = [_Tool('host-a', 'Host A'), _Tool('host-b', 'Host B')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToolRail(
            theme: ComposerTheme.snapTikTok,
            tools: tools,
            selected: null,
            l10n: const _L10n(),
            axis: Axis.horizontal,
            onSelected: (tool) => selected = tool,
          ),
        ),
      ),
    );

    expect(find.text('Host A'), findsOneWidget);
    expect(find.text('Host B'), findsOneWidget);
    await tester.tap(find.text('Host B'));
    expect(selected?.id, 'host-b');
  });
}

class _Tool implements EditorTool {
  const _Tool(this.id, this.displayName);

  @override
  final String id;
  final String displayName;

  @override
  ComposerFeature get feature => ComposerFeature.stickers;

  @override
  Widget buildPanel(EditorToolContext context) => const SizedBox.shrink();

  @override
  IconData icon(BuildContext context) => Icons.extension;

  @override
  String label(ComposerToolL10n l10n) => displayName;
}

class _L10n implements ComposerToolL10n {
  const _L10n();

  @override
  String text(String key) => key;

  @override
  String toolLabel(ComposerFeature feature) => feature.name;
}

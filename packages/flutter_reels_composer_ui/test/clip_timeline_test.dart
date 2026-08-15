import 'package:flutter/material.dart';
import 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('split at playhead creates a second clip', (tester) async {
    final engine = FakeComposerEngine();
    await engine.initialize(const EngineInitConfig());
    final controller = ComposerController(engine);
    await controller.load(
      ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'a',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 6),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return ClipTimeline(
                theme: ComposerTheme.snapTikTok,
                project: controller.project,
                position: const Duration(seconds: 2),
                controller: controller,
                l10n: const ComposerL10n('en'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-split')), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-split')));
    await tester.pumpAndSettle();

    expect(controller.project.clips, hasLength(2));
    expect(
      controller.project.clips.first.trimmedDuration,
      const Duration(seconds: 2),
    );
    await controller.undo();
    expect(controller.project.clips, hasLength(1));

    controller.dispose();
    await engine.dispose();
  });
}

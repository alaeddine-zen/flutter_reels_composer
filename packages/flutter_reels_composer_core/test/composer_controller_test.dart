import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeComposerEngine engine;
  late ComposerController controller;

  ProjectDocument clipProject() => ProjectDocument.fromClip(
    clip: const TimelineClip(
      id: 'c1',
      sourcePath: '/tmp/a.mp4',
      sourceDuration: Duration(seconds: 5),
    ),
  );

  setUp(() async {
    engine = FakeComposerEngine();
    await engine.initialize(const EngineInitConfig());
    controller = ComposerController(engine);
    await controller.load(clipProject());
  });

  tearDown(() async {
    controller.dispose();
    await engine.dispose();
  });

  test('apply records one undo entry and redo restores it', () async {
    await controller.apply(const SetColorFilterMutation('warm'));
    expect(controller.project.activeFilterId, 'warm');
    expect(controller.canUndo, isTrue);
    expect(controller.canRedo, isFalse);

    await controller.undo();
    expect(controller.project.activeFilterId, 'normal');
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isTrue);

    await controller.redo();
    expect(controller.project.activeFilterId, 'warm');
    expect(controller.canRedo, isFalse);
  });

  test('applyLive coalesces a gesture into a single undo entry', () async {
    await controller.applyLive(
      const SetColorFilterMutation('warm', intensity: 0.2),
    );
    await controller.applyLive(
      const SetColorFilterMutation('warm', intensity: 0.8),
    );
    controller.endLive();
    expect(controller.project.activeFilterIntensity, 0.8);
    expect(controller.canUndo, isTrue);

    await controller.undo();
    expect(controller.project.activeFilterId, 'normal');
    expect(controller.canUndo, isFalse);

    await controller.redo();
    expect(controller.project.activeFilterIntensity, 0.8);
  });

  test('undo during applyLive restores the pre-gesture project', () async {
    await controller.applyLive(
      const SetColorFilterMutation('cool', intensity: 0.5),
    );
    expect(controller.isLive, isTrue);
    await controller.undo();
    expect(controller.isLive, isFalse);
    expect(controller.project.activeFilterId, 'normal');
    expect(controller.canRedo, isTrue);
  });

  test(
    'apply after applyLive closes the gesture then stacks a new entry',
    () async {
      await controller.applyLive(
        const SetColorFilterMutation('warm', intensity: 0.4),
      );
      await controller.apply(const SetColorFilterMutation('cool'));
      expect(controller.isLive, isFalse);
      expect(controller.project.activeFilterId, 'cool');

      await controller.undo();
      expect(controller.project.activeFilterId, 'warm');
      await controller.undo();
      expect(controller.project.activeFilterId, 'normal');
    },
  );

  test('load clears undo and redo', () async {
    await controller.apply(const SetColorFilterMutation('warm'));
    await controller.undo();
    await controller.load(clipProject());
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.isLive, isFalse);
  });

  test('undo stack is capped', () async {
    for (var i = 0; i < ComposerController.maxUndoDepth + 5; i++) {
      await controller.apply(
        SetColorFilterMutation('warm', intensity: (i % 10) / 10),
      );
    }
    var steps = 0;
    while (controller.canUndo) {
      await controller.undo();
      steps++;
    }
    expect(steps, ComposerController.maxUndoDepth);
  });
}

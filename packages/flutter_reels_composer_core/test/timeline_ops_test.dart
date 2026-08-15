import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

TimelineClip _clip({
  required String id,
  Duration source = const Duration(seconds: 10),
  Duration trimStart = Duration.zero,
  Duration? trimEnd,
  double speed = 1.0,
}) {
  return TimelineClip(
    id: id,
    sourcePath: '/tmp/$id.mp4',
    sourceDuration: source,
    trimStart: trimStart,
    trimEnd: trimEnd,
    speed: speed,
  );
}

ProjectDocument _project(List<TimelineClip> clips) {
  return ProjectDocument.fromClip(clip: clips.first).copyWith(clips: clips);
}

void main() {
  group('snapDuration', () {
    test('returns value when nothing is in the window', () {
      expect(
        snapDuration(
          const Duration(milliseconds: 500),
          targets: const [Duration.zero, Duration(seconds: 2)],
          window: const Duration(milliseconds: 80),
        ),
        const Duration(milliseconds: 500),
      );
    });

    test('snaps to the nearest junction', () {
      expect(
        snapDuration(
          const Duration(milliseconds: 980),
          targets: clipJunctions([
            _clip(id: 'a', source: const Duration(seconds: 1)),
            _clip(id: 'b', source: const Duration(seconds: 1)),
          ]),
          window: const Duration(milliseconds: 100),
        ),
        const Duration(seconds: 1),
      );
    });
  });

  group('clipIndexAt / junctions', () {
    test('maps composition time onto the covering clip', () {
      final clips = [
        _clip(id: 'a', source: const Duration(seconds: 2)),
        _clip(id: 'b', source: const Duration(seconds: 3)),
      ];
      expect(clipIndexAt(clips, Duration.zero), 0);
      expect(clipIndexAt(clips, const Duration(milliseconds: 1999)), 0);
      expect(clipIndexAt(clips, const Duration(seconds: 2)), 1);
      expect(clipIndexAt(clips, const Duration(seconds: 5)), 1);
      expect(clipJunctions(clips), const [
        Duration.zero,
        Duration(seconds: 2),
        Duration(seconds: 5),
      ]);
    });
  });

  group('clipFadeOpacity', () {
    test('hard cut stays fully opaque', () {
      expect(
        clipFadeOpacity(
          localTime: const Duration(milliseconds: 500),
          clipDuration: const Duration(seconds: 2),
        ),
        1.0,
      );
    });

    test('fades out over the last window', () {
      expect(
        clipFadeOpacity(
          localTime: const Duration(seconds: 2),
          clipDuration: const Duration(seconds: 2),
          fadeOut: const Duration(milliseconds: 400),
        ),
        0.0,
      );
      expect(
        clipFadeOpacity(
          localTime: const Duration(milliseconds: 1800),
          clipDuration: const Duration(seconds: 2),
          fadeOut: const Duration(milliseconds: 400),
        ),
        closeTo(0.5, 0.001),
      );
    });

    test('next clip fades in from the previous transitionOut', () {
      expect(
        clipFadeOpacity(
          localTime: Duration.zero,
          clipDuration: const Duration(seconds: 2),
          fadeIn: const Duration(milliseconds: 400),
        ),
        0.0,
      );
      expect(
        clipFadeOpacity(
          localTime: const Duration(milliseconds: 200),
          clipDuration: const Duration(seconds: 2),
          fadeIn: const Duration(milliseconds: 400),
        ),
        closeTo(0.5, 0.001),
      );
    });
  });

  group('splitLegacyClip / SplitClipMutation', () {
    test('splits a clip at the playhead and preserves source trim', () {
      final clip = _clip(
        id: 'a',
        source: const Duration(seconds: 10),
        trimStart: const Duration(seconds: 1),
        trimEnd: const Duration(seconds: 7),
      );
      final split = splitLegacyClip(
        clip: clip,
        prefix: Duration.zero,
        at: const Duration(seconds: 2),
        newClipId: 'b',
      );
      expect(split, isNotNull);
      expect(split!.left.id, 'a');
      expect(split.left.trimStart, const Duration(seconds: 1));
      expect(split.left.trimEnd, const Duration(seconds: 3));
      expect(split.right.id, 'b');
      expect(split.right.trimStart, const Duration(seconds: 3));
      expect(split.right.trimEnd, const Duration(seconds: 7));
      expect(
        split.left.trimmedDuration + split.right.trimmedDuration,
        clip.trimmedDuration,
      );
      expect(split.left.transitionOut, Duration.zero);
      expect(split.right.transitionOut, Duration.zero);
    });

    test('accounts for speed when mapping composition time to source', () {
      final clip = _clip(
        id: 'a',
        source: const Duration(seconds: 8),
        speed: 2.0,
      );
      // trimmedDuration = 4s. Split at 1s composition → 2s of source.
      final split = splitLegacyClip(
        clip: clip,
        prefix: Duration.zero,
        at: const Duration(seconds: 1),
        newClipId: 'b',
      );
      expect(split, isNotNull);
      expect(split!.left.trimEnd, const Duration(seconds: 2));
      expect(split.right.trimStart, const Duration(seconds: 2));
    });

    test('refuses a cut that would leave a sub-minimum piece', () {
      final clip = _clip(id: 'a', source: const Duration(seconds: 2));
      expect(
        splitLegacyClip(
          clip: clip,
          prefix: Duration.zero,
          at: const Duration(milliseconds: 50),
          newClipId: 'b',
        ),
        isNull,
      );
    });

    test('keeps dip-to-black fade on the right-hand piece only', () {
      final clip = _clip(
        id: 'a',
        source: const Duration(seconds: 6),
      ).copyWith(transitionOut: kDefaultClipFade);
      final split = splitLegacyClip(
        clip: clip,
        prefix: Duration.zero,
        at: const Duration(seconds: 2),
        newClipId: 'b',
      );
      expect(split, isNotNull);
      expect(split!.left.transitionOut, Duration.zero);
      expect(split.right.transitionOut, kDefaultClipFade);
    });
  });

  group('rollJunction', () {
    test('keeps the pair duration and stays gapless', () {
      final clips = [
        _clip(
          id: 'a',
          source: const Duration(seconds: 10),
          trimEnd: const Duration(seconds: 4),
        ),
        _clip(
          id: 'b',
          source: const Duration(seconds: 10),
          trimStart: const Duration(seconds: 2),
          trimEnd: const Duration(seconds: 6),
        ),
      ];
      final rolled = rollJunction(
        clips: clips,
        leftIndex: 0,
        junction: const Duration(seconds: 2),
      );
      expect(rolled, isNotNull);
      expect(rolled![0].trimEnd, const Duration(seconds: 2));
      expect(rolled[1].trimStart, Duration.zero);
      expect(
        rolled[0].trimmedDuration + rolled[1].trimmedDuration,
        const Duration(seconds: 8),
      );
    });
  });

  group('SplitClipMutation', () {
    test('mutation inserts the right-hand clip and is undoable', () async {
      final engine = FakeComposerEngine();
      await engine.initialize(const EngineInitConfig());
      final controller = ComposerController(engine);
      await controller.load(
        _project([_clip(id: 'a', source: const Duration(seconds: 6))]),
      );
      await controller.apply(
        const SplitClipMutation(
          clipId: 'a',
          at: Duration(seconds: 2),
          newClipId: 'b',
        ),
      );
      expect(controller.project.clips.map((c) => c.id), ['a', 'b']);
      expect(
        controller.project.clips[0].trimmedDuration,
        const Duration(seconds: 2),
      );
      expect(
        controller.project.clips[1].trimmedDuration,
        const Duration(seconds: 4),
      );
      final recipe = ExportRecipe.fromProject(controller.project);
      expect(recipe.needsConcat, isTrue);
      expect(recipe.segments, hasLength(2));

      await controller.undo();
      expect(controller.project.clips, hasLength(1));
      await engine.dispose();
    });
  });
}

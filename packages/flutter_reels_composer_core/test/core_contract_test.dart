import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

void main() {
  group('ProjectDocument + mutations', () {
    test('fromClip seeds original audio and normal filter', () {
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 10),
        ),
      );
      expect(project.schemaVersion, kProjectSchemaVersion);
      expect(project.clips, hasLength(1));
      expect(
        project.audioTracks.any((t) => t.kind == AudioTrackKind.original),
        isTrue,
      );
      expect(project.activeFilterId, 'normal');
    });

    test('trim mutation updates clip bounds', () {
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 10),
        ),
      );
      project = applyProjectMutation(
        project,
        const UpdateClipTrimMutation(
          clipId: 'c1',
          trimStart: Duration(seconds: 1),
          trimEnd: Duration(seconds: 4),
        ),
      );
      expect(project.clips.first.trimStart, const Duration(seconds: 1));
      expect(project.clips.first.trimmedDuration, const Duration(seconds: 3));
    });

    test('color filter intensity is stored', () {
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      project = applyProjectMutation(
        project,
        const SetColorFilterMutation('warm', intensity: 0.4),
      );
      expect(project.activeFilterId, 'warm');
      expect(project.activeFilterIntensity, closeTo(0.4, 0.001));
    });

    test('schema v1 json migrates to v2', () {
      final json = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 2),
        ),
      ).toJson();
      json.remove('schemaVersion');
      final restored = ProjectDocument.fromJson(json);
      expect(restored.schemaVersion, kProjectSchemaVersion);
    });
  });

  group('ExportPlanner', () {
    test('trim-only does not need reencode', () {
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      final plan = const ExportPlanner().plan(project);
      expect(plan.needsReencode, isFalse);
    });

    test('text overlay needs reencode', () {
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      project = applyProjectMutation(
        project,
        const AddTextLayerMutation(layerId: 't1', text: 'Hello'),
      );
      expect(const ExportPlanner().plan(project).needsText, isTrue);
      expect(const ExportPlanner().plan(project).needsReencode, isTrue);
    });

    test('music track needs reencode', () {
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      project = applyProjectMutation(
        project,
        const SetMusicTrackMutation(musicId: 'm1', sourcePath: '/tmp/song.m4a'),
      );
      final plan = const ExportPlanner().plan(project);
      expect(plan.needsMusic, isTrue);
      expect(plan.needsReencode, isTrue);
    });

    test('multi-clip concat needs reencode', () {
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      final two = project.copyWith(
        clips: [
          ...project.clips,
          const TimelineClip(
            id: 'c2',
            sourcePath: '/tmp/b.mp4',
            sourceDuration: Duration(seconds: 4),
          ),
        ],
      );
      final plan = const ExportPlanner().plan(two);
      expect(plan.needsConcat, isTrue);
      expect(plan.needsReencode, isTrue);
    });

    test('speed change needs reencode', () {
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 5),
        ),
      );
      project = applyProjectMutation(
        project,
        const UpdateClipSpeedMutation(clipId: 'c1', speed: 2.0),
      );
      final plan = const ExportPlanner().plan(project);
      expect(plan.needsSpeed, isTrue);
      expect(plan.needsReencode, isTrue);
    });
  });

  group('EditorToolRegistry', () {
    test('hides tools the gate does not allow', () {
      final registry = EditorToolRegistry(
        builtins: const [
          _StubTool('trim', ComposerFeature.trim),
          _StubTool('stickers', ComposerFeature.stickers),
        ],
      );
      final gate = CapabilityGate.resolve(
        engine: ComposerCapabilities.localV1,
        enabledFeatures: kDefaultV1Features,
      );
      final visible = registry.visible(gate);
      expect(visible.map((t) => t.id), ['trim']);
    });

    test('host tools are visible without changing the local engine', () {
      final registry = EditorToolRegistry(
        builtins: const [],
        extras: const [_StubTool('host-stickers', ComposerFeature.stickers)],
      );
      final gate = CapabilityGate.resolve(
        engine: ComposerCapabilities.localV1,
        enabledFeatures: kDefaultV1Features,
      );
      expect(registry.visible(gate).single.id, 'host-stickers');
    });

    test('host tool replaces a built-in with the same id', () {
      final registry = EditorToolRegistry(
        builtins: const [_StubTool('trim', ComposerFeature.trim)],
        extras: const [_StubTool('trim', ComposerFeature.colorFilters)],
      );
      expect(registry.all, hasLength(1));
      expect(registry.byId('trim')?.feature, ComposerFeature.colorFilters);
    });
  });

  group('TemplateCatalog', () {
    test('bundled ids are stable for host overrides', () {
      const ids = [
        'intro_trend',
        'punchline',
        'recap_3',
        'slow_mo',
        'quote',
        'duet_ready',
      ];
      expect(TemplateCatalog.bundled.templates.map((t) => t.id), ids);
      expect(
        TemplateCatalog.bundled.byId('duet_ready')?.duetLayout,
        DuetLayout.split,
      );
    });
  });

  group('ComposerController undo', () {
    test('undo restores previous project', () async {
      final engine = FakeComposerEngine();
      await engine.initialize(const EngineInitConfig());
      final controller = ComposerController(engine);
      await controller.load(
        ProjectDocument.fromClip(
          clip: const TimelineClip(
            id: 'c1',
            sourcePath: '/tmp/a.mp4',
            sourceDuration: Duration(seconds: 5),
          ),
        ),
      );
      await controller.apply(const SetColorFilterMutation('warm'));
      expect(controller.project.activeFilterId, 'warm');
      await controller.undo();
      expect(controller.project.activeFilterId, 'normal');
      await engine.dispose();
    });
  });
}

class _StubTool implements EditorTool {
  const _StubTool(this.id, this.feature);

  @override
  final String id;
  @override
  final ComposerFeature feature;

  @override
  IconData icon(BuildContext context) => Icons.extension;

  @override
  String label(ComposerToolL10n l10n) => id;

  @override
  Widget buildPanel(EditorToolContext context) => const SizedBox.shrink();
}

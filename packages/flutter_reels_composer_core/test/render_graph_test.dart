import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

void main() {
  group('ColorGrade', () {
    test('intensity 0 yields identity matrix', () {
      final grade = ColorGrade(
        effectId: 'warm',
        intensity: 0,
        matrix: matrixWithIntensity(const [
          1.1,
          0,
          0,
          0,
          0.02,
          0,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ], 0),
      );
      expect(grade.isIdentity, isTrue);
      expect(grade.isActive, isFalse);
    });

    test('fromProject lerps bundled matrix by intensity', () {
      final registry = EffectRegistry()
        ..register(
          LutColorEffectDescriptor(
            id: 'warm',
            name: 'Warm',
            matrix: const [
              2,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ],
          ),
        );
      var project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 2),
        ),
      );
      project = applyProjectMutation(
        project,
        const SetColorFilterMutation('warm', intensity: 0.5),
      );
      final grade = ColorGrade.fromProject(project, registry: registry);
      expect(grade.effectId, 'warm');
      expect(grade.matrix[0], closeTo(1.5, 0.001));
      expect(grade.isActive, isTrue);
    });

    test('normal is not active', () {
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 2),
        ),
      );
      expect(ColorGrade.fromProject(project).isActive, isFalse);
    });
  });

  group('RenderGraph', () {
    test('segmentAt returns the clip covering t', () {
      final project = ProjectDocument(
        id: 'p',
        settings: VideoSettings.vertical9x16,
        clips: const [
          TimelineClip(
            id: 'a',
            sourcePath: '/tmp/a.mp4',
            sourceDuration: Duration(seconds: 2),
          ),
          TimelineClip(
            id: 'b',
            sourcePath: '/tmp/b.mp4',
            sourceDuration: Duration(seconds: 3),
          ),
        ],
      );
      final graph = RenderGraph.fromProject(project);
      expect(graph.segmentAt(Duration.zero)?.clipId, 'a');
      expect(graph.segmentAt(const Duration(seconds: 1))?.clipId, 'a');
      expect(graph.segmentAt(const Duration(seconds: 2))?.clipId, 'b');
      expect(graph.segmentAt(const Duration(seconds: 5))?.clipId, 'b');
    });

    test('overlaysAt respects start/end', () {
      final layer = VisualLayer(
        id: 't1',
        type: VisualLayerType.text,
        normalizedPosition: const Offset(0.5, 0.5),
        text: 'Hi',
        startAt: const Duration(seconds: 1),
        endAt: const Duration(seconds: 2),
      );
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 4),
        ),
      ).copyWith(layers: [layer]);
      final graph = RenderGraph.fromProject(project);
      expect(graph.overlaysAt(Duration.zero), isEmpty);
      expect(graph.overlaysAt(const Duration(seconds: 1)), hasLength(1));
      expect(graph.overlaysAt(const Duration(seconds: 2)), isEmpty);
    });

    test('normal filter has no active color grade', () {
      final graph = RenderGraph.fromProject(
        ProjectDocument.fromClip(
          clip: const TimelineClip(
            id: 'c1',
            sourcePath: '/tmp/a.mp4',
            sourceDuration: Duration(seconds: 1),
          ),
        ),
      );
      expect(graph.colorGrade.isActive, isFalse);
    });
  });
}

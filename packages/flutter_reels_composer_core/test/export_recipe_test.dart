import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

ProjectDocument _clip({int seconds = 5}) {
  return ProjectDocument.fromClip(
    clip: TimelineClip(
      id: 'c1',
      sourcePath: '/tmp/a.mp4',
      sourceDuration: Duration(seconds: seconds),
    ),
  );
}

void main() {
  group('ExportRecipe', () {
    test('trim-only does not need reencode', () {
      final recipe = ExportRecipe.fromProject(_clip());
      expect(recipe.needsReencode, isFalse);
      expect(recipe.needsColor, isFalse);
    });

    test('text overlay needs reencode and textOverlay op', () {
      var project = _clip();
      project = applyProjectMutation(
        project,
        const AddTextLayerMutation(layerId: 't1', text: 'Hello'),
      );
      final recipe = ExportRecipe.fromProject(project);
      expect(recipe.needsText, isTrue);
      expect(recipe.needsReencode, isTrue);
      expect(
        recipe.requiredOperations,
        contains(ExportOperationKind.textOverlay),
      );
    });

    test('music track needs reencode', () {
      var project = _clip();
      project = applyProjectMutation(
        project,
        const SetMusicTrackMutation(musicId: 'm1', sourcePath: '/tmp/song.m4a'),
      );
      final recipe = ExportRecipe.fromProject(project);
      expect(recipe.needsMusic, isTrue);
      expect(recipe.needsReencode, isTrue);
    });

    test('multi-clip concat needs reencode', () {
      final two = _clip().copyWith(
        clips: [
          ..._clip().clips,
          const TimelineClip(
            id: 'c2',
            sourcePath: '/tmp/b.mp4',
            sourceDuration: Duration(seconds: 4),
          ),
        ],
      );
      final recipe = ExportRecipe.fromProject(two);
      expect(recipe.needsConcat, isTrue);
      expect(recipe.needsReencode, isTrue);
    });

    test('speed change needs reencode', () {
      var project = _clip();
      project = applyProjectMutation(
        project,
        const UpdateClipSpeedMutation(clipId: 'c1', speed: 2.0),
      );
      final recipe = ExportRecipe.fromProject(project);
      expect(recipe.needsSpeed, isTrue);
      expect(recipe.needsReencode, isTrue);
    });

    test('duet needs reencode', () {
      final project = _clip().copyWith(
        extras: {
          'duetLayout': DuetLayout.split.name,
          'parentVideoPath': '/tmp/parent.mp4',
        },
      );
      final recipe = ExportRecipe.fromProject(project);
      expect(recipe.needsDuet, isTrue);
      expect(recipe.requiredOperations, contains(ExportOperationKind.duet));
    });
  });

  group('ExportCapabilitySet', () {
    test('unknown operation is reported, never dropped', () {
      const caps = ExportCapabilitySet({ExportOperationKind.trim});
      var project = _clip();
      project = applyProjectMutation(
        project,
        const AddTextLayerMutation(layerId: 't1', text: 'Hi'),
      );
      final recipe = ExportRecipe.fromProject(project);
      expect(
        caps.unsupportedOperations(recipe.requiredOperations),
        contains(ExportOperationKind.textOverlay),
      );
    });

    test('ffmpegV1 rejects stickers and voice-over', () {
      final stickers = _clip().copyWith(
        layers: const [
          VisualLayer(
            id: 's1',
            type: VisualLayerType.sticker,
            normalizedPosition: Offset(0.5, 0.5),
            assetId: 'star',
          ),
        ],
      );
      final stickerRecipe = ExportRecipe.fromProject(stickers);
      expect(
        ExportCapabilitySet.ffmpegV1.unsupportedOperations(
          stickerRecipe.requiredOperations,
        ),
        contains(ExportOperationKind.stickerOverlay),
      );

      final vo = _clip().copyWith(
        audioTracks: const [
          AudioTrack(
            id: 'vo',
            kind: AudioTrackKind.voiceover,
            sourcePath: '/tmp/vo.m4a',
          ),
        ],
      );
      expect(
        ExportCapabilitySet.ffmpegV1.unsupportedOperations(
          ExportRecipe.fromProject(vo).requiredOperations,
        ),
        contains(ExportOperationKind.voiceover),
      );
    });

    test('ffmpegV1 supports color, text, concat', () {
      expect(
        ExportCapabilitySet.ffmpegV1.supports(ExportOperationKind.colorMatrix),
        isTrue,
      );
      expect(
        ExportCapabilitySet.ffmpegV1.unsupportedOperations(const {
          ExportOperationKind.concat,
          ExportOperationKind.textOverlay,
        }),
        isEmpty,
      );
    });
  });
}

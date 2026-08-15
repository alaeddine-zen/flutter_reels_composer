import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

void main() {
  group('Timeline', () {
    test('fromDocument duration matches ProjectDocument', () {
      final project = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 10),
          trimStart: Duration(seconds: 2),
          trimEnd: Duration(seconds: 8),
        ),
      );
      final timeline = Timeline.fromDocument(project);
      expect(timeline.duration, project.duration);
      expect(timeline.duration, const Duration(seconds: 6));
      expect(timeline.mediaClips, hasLength(1));
      expect(timeline.mediaClips.single, isA<VideoClip>());
    });

    test('multi-clip duration sums trimmed lengths', () {
      final project = ProjectDocument(
        id: 'p',
        settings: VideoSettings.vertical9x16,
        clips: const [
          TimelineClip(
            id: 'a',
            sourcePath: '/tmp/a.mp4',
            sourceDuration: Duration(seconds: 3),
          ),
          TimelineClip(
            id: 'b',
            sourcePath: '/tmp/b.mp4',
            sourceDuration: Duration(seconds: 4),
            speed: 2.0,
          ),
        ],
      );
      expect(
        Timeline.fromDocument(project).duration,
        const Duration(seconds: 5),
      );
    });

    test('very short clip keeps non-zero duration', () {
      const clip = TimelineClip(
        id: 'tiny',
        sourcePath: '/tmp/t.mp4',
        sourceDuration: Duration(milliseconds: 80),
      );
      expect(clip.trimmedDuration, const Duration(milliseconds: 80));
      expect(
        Timeline.fromDocument(
          ProjectDocument(
            id: 'p',
            settings: VideoSettings.vertical9x16,
            clips: [clip],
          ),
        ).duration,
        const Duration(milliseconds: 80),
      );
    });

    test('image clip uses displayDuration', () {
      const clip = TimelineClip(
        id: 'img',
        sourcePath: '/tmp/still.png',
        sourceDuration: Duration(seconds: 3),
        kind: TimelineClipKind.image,
      );
      final timeline = Timeline.fromDocument(
        ProjectDocument(
          id: 'p',
          settings: VideoSettings.vertical9x16,
          clips: const [clip],
        ),
      );
      expect(timeline.mediaClips.single, isA<ImageClip>());
      expect(timeline.duration, const Duration(seconds: 3));
      expect(
        (timeline.mediaClips.single as ImageClip).displayDuration,
        const Duration(seconds: 3),
      );
    });

    test('legacy round-trip preserves kind', () {
      const original = TimelineClip(
        id: 'img',
        sourcePath: '/tmp/still.webp',
        sourceDuration: Duration(seconds: 3),
        kind: TimelineClipKind.image,
      );
      final back = TimelineMediaClip.fromLegacy(original).toLegacyClip();
      expect(back.kind, TimelineClipKind.image);
      expect(back.sourcePath, original.sourcePath);
    });
  });
}

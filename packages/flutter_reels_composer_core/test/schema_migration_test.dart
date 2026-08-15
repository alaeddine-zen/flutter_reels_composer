import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

void main() {
  group('schema migration', () {
    test('v1 (no schemaVersion) migrates to v3 with timeline dual-write', () {
      final v1 = {
        'id': 'p1',
        'settings': {'width': 1080, 'height': 1920, 'fps': 30, 'bitrate': 1},
        'clips': [
          {
            'id': 'c1',
            'sourcePath': '/tmp/a.mp4',
            'sourceDurationMs': 2000,
            'trimStartMs': 0,
            'trimEndMs': 2000,
            'speed': 1.0,
          },
        ],
        'layers': <Map<String, dynamic>>[],
        'audioTracks': <Map<String, dynamic>>[],
        'effects': <Map<String, dynamic>>[],
        'cover': <String, dynamic>{},
      };

      final migrated = migrateProjectJson(v1);
      expect(migrated['schemaVersion'], kProjectSchemaVersion);
      expect(migrated['timeline'], isA<Map>());
      expect((migrated['clips'] as List).first['kind'], 'video');

      final restored = ProjectDocument.fromJson(v1);
      expect(restored.schemaVersion, 3);
      expect(restored.clips.single.id, 'c1');
      expect(restored.timeline.duration, const Duration(seconds: 2));
    });

    test('v2 json migrates and round-trips as v3', () {
      final v2 = ProjectDocument.fromClip(
        clip: const TimelineClip(
          id: 'c1',
          sourcePath: '/tmp/a.mp4',
          sourceDuration: Duration(seconds: 4),
        ),
      ).toJson();
      v2['schemaVersion'] = 2;
      v2.remove('timeline');

      final restored = ProjectDocument.fromJson(v2);
      expect(restored.schemaVersion, 3);
      final roundtrip = restored.toJson();
      expect(roundtrip['schemaVersion'], 3);
      expect(roundtrip['timeline'], isNotNull);
      expect(roundtrip['clips'], isNotEmpty);
      expect(ProjectDocument.fromJson(roundtrip).clips.single.id, 'c1');
    });

    test('v3 timeline-only json rebuilds flat clips', () {
      final timeline = Timeline(
        videoTracks: [
          VideoTrack(
            clips: [
              VideoClip(
                id: 'from-tl',
                media: const MediaRef(
                  path: '/tmp/b.mp4',
                  kind: MediaKind.video,
                  duration: Duration(seconds: 5),
                ),
                trimEnd: const Duration(seconds: 5),
              ),
            ],
          ),
        ],
      ).toJson();

      final restored = ProjectDocument.fromJson({
        'schemaVersion': 3,
        'id': 'p-tl',
        'settings': const VideoSettings().toJson(),
        'clips': <Map<String, dynamic>>[],
        'timeline': timeline,
        'cover': <String, dynamic>{},
      });
      expect(restored.clips.single.id, 'from-tl');
      expect(restored.clips.single.sourcePath, '/tmp/b.mp4');
    });

    test('unsupported future schema throws', () {
      expect(
        () => migrateProjectJson({'schemaVersion': 99, 'id': 'x'}),
        throwsA(isA<UnsupportedProjectSchemaException>()),
      );
    });
  });
}

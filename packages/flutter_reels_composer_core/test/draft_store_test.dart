import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MemoryDraftStore keeps existing updatedAt on save', () async {
    final store = MemoryDraftStore();
    final stamped = ProjectDocument(
      id: 'p1',
      settings: VideoSettings.vertical9x16,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await store.save(stamped);
    final loaded = await store.load('p1');
    expect(loaded!.updatedAt, DateTime.utc(2026, 1, 2));
  });

  test('MemoryDraftStore stamps a missing updatedAt once', () async {
    final store = MemoryDraftStore();
    final fresh = ProjectDocument(
      id: 'p2',
      settings: VideoSettings.vertical9x16,
    );
    await store.save(fresh);
    final loaded = await store.load('p2');
    expect(loaded!.updatedAt, isNotNull);
  });
}

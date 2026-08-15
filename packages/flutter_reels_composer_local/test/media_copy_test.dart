import 'dart:io';

import 'package:flutter_reels_composer_local/src/media_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('reels_copy_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('same path is already a copy', () {
    final file = File('${dir.path}/a.bin')..writeAsBytesSync(const [1, 2, 3]);
    expect(destinationAlreadyHasCopy(file, file), isTrue);
  });

  test('missing dest is not a copy', () {
    final source = File('${dir.path}/a.bin')..writeAsBytesSync(const [1, 2, 3]);
    final dest = File('${dir.path}/b.bin');
    expect(destinationAlreadyHasCopy(source, dest), isFalse);
  });

  test('matching length skips recopy', () {
    final source = File('${dir.path}/a.bin')..writeAsBytesSync(const [1, 2, 3]);
    final dest = File('${dir.path}/b.bin')..writeAsBytesSync(const [9, 8, 7]);
    expect(destinationAlreadyHasCopy(source, dest), isTrue);
  });

  test('different length recopies', () {
    final source = File('${dir.path}/a.bin')..writeAsBytesSync(const [1, 2, 3]);
    final dest = File('${dir.path}/b.bin')..writeAsBytesSync(const [1]);
    expect(destinationAlreadyHasCopy(source, dest), isFalse);
  });
}

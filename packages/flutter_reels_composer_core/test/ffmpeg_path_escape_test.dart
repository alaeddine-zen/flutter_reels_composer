import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ffmpegEscapePath escapes backslash before quotes', () {
    expect(
      ffmpegEscapePath(r'C:\clips\"quote".mp4'),
      r'C:\\clips\\\"quote\".mp4',
    );
  });

  test('ffmpegEscapePath escapes dollar and backtick', () {
    expect(
      ffmpegEscapePath(r'/tmp/$home/`cmd`.mp4'),
      r'/tmp/\$home/\`cmd\`.mp4',
    );
  });

  test('ffmpegEscapePath leaves ordinary unix paths unchanged', () {
    expect(ffmpegEscapePath('/tmp/clip.mp4'), '/tmp/clip.mp4');
  });
}

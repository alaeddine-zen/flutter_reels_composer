import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'package:flutter_reels_composer_export_lgpl/src/ffmpeg_color_matrix.dart';

void main() {
  group('ColorMatrixFfmpeg', () {
    test('identity matrix emits no filter', () {
      expect(ColorMatrixFfmpeg.toFilter(kIdentityColorMatrix), isNull);
    });

    test('scale-only matrix becomes colorchannelmixer', () {
      const matrix = <double>[
        1.1,
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
        0.9,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
      expect(
        ColorMatrixFfmpeg.toFilter(matrix),
        'colorchannelmixer=1.1:0:0:0:0:1:0:0:0:0:0.9:0:0:0:0:1',
      );
    });

    test('offset column adds lutrgb', () {
      const matrix = <double>[
        1,
        0,
        0,
        0,
        0.02,
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
      ];
      final filter = ColorMatrixFfmpeg.toFilter(matrix)!;
      expect(
        filter,
        contains('colorchannelmixer=1:0:0:0:0:1:0:0:0:0:1:0:0:0:0:1'),
      );
      expect(filter, contains("lutrgb=r='clip(val+(0.02)*maxval,0,maxval)'"));
    });
  });
}

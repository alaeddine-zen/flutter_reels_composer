import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reels_composer_export_lgpl/src/ffmpeg_filters.dart';

void main() {
  group('FfmpegFilters.canvasCover', () {
    test('matches preview BoxFit.cover (increase + crop)', () {
      expect(
        FfmpegFilters.canvasCover(width: 1080, height: 1920, fps: 30),
        'scale=1080:1920:force_original_aspect_ratio=increase,'
        'crop=1080:1920,fps=30,format=yuv420p',
      );
    });

    test('uses project fps and 720p ladder', () {
      expect(
        FfmpegFilters.canvasCover(width: 720, height: 1280, fps: 24),
        contains('scale=720:1280:force_original_aspect_ratio=increase'),
      );
      expect(
        FfmpegFilters.canvasCover(width: 720, height: 1280, fps: 24),
        contains('fps=24'),
      );
    });
  });

  group('FfmpegFilters.dipToBlack', () {
    test('emits sequential fade in/out on the output timeline', () {
      expect(
        FfmpegFilters.dipToBlack(
          durationSec: 2,
          fadeInSec: 0.3,
          fadeOutSec: 0.3,
        ),
        'fade=t=in:st=0:d=0.300,fade=t=out:st=1.700:d=0.300',
      );
    });

    test('omits unused edges', () {
      expect(FfmpegFilters.dipToBlack(durationSec: 2), isEmpty);
      expect(
        FfmpegFilters.dipToBlack(durationSec: 2, fadeOutSec: 0.25),
        'fade=t=out:st=1.750:d=0.250',
      );
    });
  });
}

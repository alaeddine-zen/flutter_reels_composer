import 'package:equatable/equatable.dart';

class VideoSettings extends Equatable {
  const VideoSettings({
    this.width = 1080,
    this.height = 1920,
    this.fps = 30,
    this.bitrate = 6_000_000,
    this.aspectRatio = 9 / 16,
  });

  final int width;
  final int height;
  final int fps;
  final int bitrate;
  final double aspectRatio;

  static const vertical9x16 = VideoSettings();

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'fps': fps,
    'bitrate': bitrate,
    'aspectRatio': aspectRatio,
  };

  factory VideoSettings.fromJson(Map<String, dynamic> json) {
    return VideoSettings(
      width: json['width'] as int? ?? 1080,
      height: json['height'] as int? ?? 1920,
      fps: json['fps'] as int? ?? 30,
      bitrate: json['bitrate'] as int? ?? 6_000_000,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 9 / 16,
    );
  }

  @override
  List<Object?> get props => [width, height, fps, bitrate, aspectRatio];
}

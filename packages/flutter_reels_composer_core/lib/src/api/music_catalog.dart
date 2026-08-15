import 'package:equatable/equatable.dart';

class MusicTrack extends Equatable {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.sourcePath,
    this.duration = Duration.zero,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String sourcePath;
  final Duration duration;
  final String? coverUrl;

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    sourcePath,
    duration,
    coverUrl,
  ];
}

class MusicCatalog {
  const MusicCatalog({this.tracks = const []});

  final List<MusicTrack> tracks;

  static const empty = MusicCatalog();

  MusicTrack? byId(String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }
}

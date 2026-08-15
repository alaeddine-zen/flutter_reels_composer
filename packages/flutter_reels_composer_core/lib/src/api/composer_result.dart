import 'dart:io';

import '../domain/project/project_document.dart';

class ComposerResult {
  const ComposerResult({
    required this.videoFile,
    this.coverFile,
    required this.project,
    required this.duration,
    this.metadata = const {},
  });

  final File videoFile;
  final File? coverFile;
  final ProjectSnapshot project;
  final Duration duration;
  final Map<String, dynamic> metadata;

  String? get filterId {
    final effects = project.json['effects'];
    if (effects is! List) return null;
    for (final e in effects) {
      if (e is Map && e['category'] == 'color') {
        return e['effectId'] as String?;
      }
    }
    return null;
  }

  String? get musicId {
    final tracks = project.json['audioTracks'];
    if (tracks is! List) return null;
    for (final t in tracks) {
      if (t is Map && t['kind'] == 'music') {
        return t['musicId'] as String?;
      }
    }
    return null;
  }
}

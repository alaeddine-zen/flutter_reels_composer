import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

class FileDraftStore implements DraftStore {
  FileDraftStore({this.folderName = 'reels_composer_drafts'});

  final String folderName;

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _projectFile(String id) async {
    final root = await _root();
    return File(p.join(root.path, id, 'project.json'));
  }

  bool _alreadyCopied(File source, File dest) {
    if (source.path == dest.path) return true;
    if (!dest.existsSync()) return false;
    try {
      return dest.lengthSync() == source.lengthSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyIfNeeded(File source, File dest) async {
    if (_alreadyCopied(source, dest)) return;
    await source.copy(dest.path);
  }

  @override
  Future<String> save(ProjectDocument project) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, project.id));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    var doc = project.updatedAt == null ? project.touch() : project;
    final updatedClips = <TimelineClip>[];
    for (var i = 0; i < doc.clips.length; i++) {
      final clip = doc.clips[i];
      final source = File(clip.sourcePath);
      if (!source.existsSync()) {
        updatedClips.add(clip);
        continue;
      }
      final dest = File(
        p.join(dir.path, 'source_$i${p.extension(clip.sourcePath)}'),
      );
      await _copyIfNeeded(source, dest);
      updatedClips.add(
        source.path == dest.path ? clip : clip.copyWith(sourcePath: dest.path),
      );
    }
    doc = doc.copyWith(clips: updatedClips);

    final musicTracks = doc.audioTracks.where((t) => t.sourcePath != null);
    for (final track in musicTracks) {
      final path = track.sourcePath!;
      final source = File(path);
      if (!source.existsSync()) continue;
      final dest = File(p.join(dir.path, 'music${p.extension(path)}'));
      await _copyIfNeeded(source, dest);
      if (source.path != dest.path) {
        doc = doc.copyWith(
          audioTracks: doc.audioTracks
              .map(
                (t) => t.id == track.id ? t.copyWith(sourcePath: dest.path) : t,
              )
              .toList(),
        );
      }
    }

    final file = await _projectFile(doc.id);
    await file.writeAsString(jsonEncode(doc.toJson()));
    return doc.id;
  }

  @override
  Future<ProjectDocument?> load(String id) async {
    final file = await _projectFile(id);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ProjectDocument.fromJson(json);
  }

  @override
  Future<List<ProjectDocument>> list() async {
    final root = await _root();
    final docs = <ProjectDocument>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, 'project.json'));
      if (!file.existsSync()) continue;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        docs.add(ProjectDocument.fromJson(json));
      } catch (error) {
        debugPrint(
          'FileDraftStore: skipped unreadable draft ${entity.path}: $error',
        );
      }
    }
    docs.sort(
      (a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return docs;
  }

  @override
  Future<void> delete(String id) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, id));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}

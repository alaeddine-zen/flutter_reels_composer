import '../domain/project/project_document.dart';

abstract class DraftStore {
  Future<String> save(ProjectDocument project);
  Future<ProjectDocument?> load(String id);
  Future<List<ProjectDocument>> list();
  Future<void> delete(String id);
}

class MemoryDraftStore implements DraftStore {
  final Map<String, ProjectDocument> _docs = {};

  @override
  Future<String> save(ProjectDocument project) async {
    final doc = project.updatedAt == null ? project.touch() : project;
    _docs[doc.id] = doc;
    return doc.id;
  }

  @override
  Future<ProjectDocument?> load(String id) async => _docs[id];

  @override
  Future<List<ProjectDocument>> list() async {
    final docs = _docs.values.toList()
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );
    return docs;
  }

  @override
  Future<void> delete(String id) async {
    _docs.remove(id);
  }
}

/// Current JSON schema version for [ProjectDocument].
///
/// v1: unversioned JSON (treated as 1). v2: explicit `schemaVersion`.
/// v3: structured `timeline` dual-write + optional [TimelineClip.kind].
const int kProjectSchemaVersion = 3;

class UnsupportedProjectSchemaException implements Exception {
  UnsupportedProjectSchemaException(this.version);
  final int version;

  @override
  String toString() =>
      'Unsupported ProjectDocument schema version: $version '
      '(supported: 1–$kProjectSchemaVersion)';
}

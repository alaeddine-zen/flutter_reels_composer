/// Current JSON schema version for [ProjectDocument].
const int kProjectSchemaVersion = 2;

class UnsupportedProjectSchemaException implements Exception {
  UnsupportedProjectSchemaException(this.version);
  final int version;

  @override
  String toString() =>
      'Unsupported ProjectDocument schema version: $version '
      '(supported: 1–$kProjectSchemaVersion)';
}

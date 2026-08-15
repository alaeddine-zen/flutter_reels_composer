import '../export/export_capabilities.dart';

class ComposerException implements Exception {
  const ComposerException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message == null ? code : '$code: $message';
}

class ExportCancelledException extends ComposerException {
  const ExportCancelledException() : super('export_cancelled');
}

class MissingClipException extends ComposerException {
  const MissingClipException(String path) : super('missing_clip', path);
}

/// Thrown when an [ExportPort] cannot perform operations required by a recipe.
class UnsupportedExportException extends ComposerException {
  UnsupportedExportException(this.operations)
    : super(
        'unsupported_export',
        'Exporter cannot perform: ${operations.map((o) => o.name).join(', ')}',
      );

  final List<ExportOperationKind> operations;
}

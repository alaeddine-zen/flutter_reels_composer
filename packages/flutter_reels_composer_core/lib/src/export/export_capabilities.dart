/// Operations an [ExportPort] may be asked to perform.
///
/// Keep this list exporter-agnostic. FFmpeg filter names do not belong here.
enum ExportOperationKind {
  trim,
  speed,
  concat,
  colorMatrix,
  textOverlay,
  stickerOverlay,
  audioMix,
  duet,
  stillImage,
  voiceover,
  fade,
}

class ExportCapabilitySet {
  const ExportCapabilitySet(this.supported);

  final Set<ExportOperationKind> supported;

  /// Palier 0 FFmpeg adapters (LGPL and GPL): no stickers, no voice-over bake.
  static const ffmpegV1 = ExportCapabilitySet({
    ExportOperationKind.trim,
    ExportOperationKind.speed,
    ExportOperationKind.concat,
    ExportOperationKind.colorMatrix,
    ExportOperationKind.textOverlay,
    ExportOperationKind.audioMix,
    ExportOperationKind.duet,
    ExportOperationKind.stillImage,
    ExportOperationKind.fade,
  });

  bool supports(ExportOperationKind operation) => supported.contains(operation);

  /// Operations in [required] that this set does not support.
  /// Empty means the exporter may proceed. Never drop unsupported ops silently.
  List<ExportOperationKind> unsupportedOperations(
    Iterable<ExportOperationKind> required,
  ) {
    return required
        .where((op) => !supported.contains(op))
        .toList(growable: false);
  }
}

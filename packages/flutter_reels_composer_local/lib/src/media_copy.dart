import 'dart:io';

/// True when [dest] already holds a byte-identical-enough copy of [source].
///
/// Used by [FileDraftStore] so autosave does not recopy gallery files every
/// 8 seconds. Length is a practical equality check (same as rsync `-s` skip).
bool destinationAlreadyHasCopy(File source, File dest) {
  if (source.path == dest.path) return true;
  if (!dest.existsSync()) return false;
  try {
    return dest.lengthSync() == source.lengthSync();
  } catch (_) {
    return false;
  }
}

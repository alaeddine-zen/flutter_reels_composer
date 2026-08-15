/// Escapes a filesystem path for a double-quoted FFmpeg CLI argument.
///
/// Backslash is replaced first so later escapes stay intact. `$` and `` ` ``
/// are escaped to avoid shell expansion when a host wraps the command.
String ffmpegEscapePath(String path) {
  return path
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('`', r'\`');
}

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// Translates a Flutter/Skia 4×5 [ColorFilter] matrix into FFmpeg filters
/// (`colorchannelmixer` + optional `lutrgb` offsets).
///
/// Preview uses the same matrix via `ColorFilter.matrix`. This is **not** a
/// `.cube` LUT compiler.
class ColorMatrixFfmpeg {
  const ColorMatrixFfmpeg._();

  static bool isIdentity(List<double> matrix) {
    final m = _pad20(matrix);
    for (var i = 0; i < 20; i++) {
      if ((m[i] - kIdentityColorMatrix[i]).abs() > 0.001) return false;
    }
    return true;
  }

  /// Returns an FFmpeg `-vf` fragment, or `null` when the matrix is identity.
  static String? toFilter(List<double> matrix) {
    final m = _pad20(matrix);
    if (isIdentity(m)) return null;

    final mixer =
        'colorchannelmixer='
        '${_n(m[0])}:${_n(m[1])}:${_n(m[2])}:${_n(m[3])}:'
        '${_n(m[5])}:${_n(m[6])}:${_n(m[7])}:${_n(m[8])}:'
        '${_n(m[10])}:${_n(m[11])}:${_n(m[12])}:${_n(m[13])}:'
        '${_n(m[15])}:${_n(m[16])}:${_n(m[17])}:${_n(m[18])}';

    final or = m[4];
    final og = m[9];
    final ob = m[14];
    if (or.abs() < 1e-6 && og.abs() < 1e-6 && ob.abs() < 1e-6) {
      return mixer;
    }
    return '$mixer,'
        "lutrgb=r='clip(val+(${_n(or)})*maxval,0,maxval)'"
        ":g='clip(val+(${_n(og)})*maxval,0,maxval)'"
        ":b='clip(val+(${_n(ob)})*maxval,0,maxval)'";
  }

  static List<double> _pad20(List<double> m) {
    if (m.length >= 20) return m.sublist(0, 20);
    return [...m, ...List<double>.filled(20 - m.length, 0)];
  }

  static String _n(double v) {
    if (v.abs() < 1e-12) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
    var s = v.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

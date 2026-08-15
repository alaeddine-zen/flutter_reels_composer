const List<double> kIdentityColorMatrix = [
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> lerpColorMatrix(List<double> from, List<double> to, double t) {
  final a = _pad20(from);
  final b = _pad20(to);
  final tt = t.clamp(0.0, 1.0);
  return [for (var i = 0; i < 20; i++) a[i] + (b[i] - a[i]) * tt];
}

List<double> matrixWithIntensity(List<double> lut, double intensity) {
  return lerpColorMatrix(kIdentityColorMatrix, lut, intensity.clamp(0.0, 1.0));
}

List<double> _pad20(List<double> m) {
  if (m.length >= 20) return m.sublist(0, 20);
  return [...m, ...List<double>.filled(20 - m.length, 0)];
}

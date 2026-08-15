import 'package:equatable/equatable.dart';

import '../domain/effects/color_matrix_utils.dart';
import '../domain/effects/effect_descriptor.dart';
import '../domain/effects/effect_registry.dart';
import '../domain/project/project_document.dart';

/// Intensity threshold matching [ExportPlanner] — below this, skip color bake.
const double kColorGradeActiveIntensity = 0.05;

/// Global color grade. This is a 4×5 [ColorFilter] matrix, **not** a .cube LUT.
///
/// File-based LUT (`.cube`) support is a later phase. [LutColorEffectDescriptor]
/// stores the same 4×5 matrix used by preview and export.
class ColorGrade extends Equatable {
  const ColorGrade({
    required this.effectId,
    this.intensity = 1.0,
    this.matrix = kIdentityColorMatrix,
  });

  static const identity = ColorGrade(
    effectId: 'normal',
    intensity: 0,
    matrix: kIdentityColorMatrix,
  );

  final String effectId;
  final double intensity;

  /// Effective 4×5 matrix (identity lerped toward the effect by [intensity]).
  final List<double> matrix;

  bool get isIdentity {
    if (matrix.length < 20) return false;
    for (var i = 0; i < 20; i++) {
      if ((matrix[i] - kIdentityColorMatrix[i]).abs() > 0.001) return false;
    }
    return true;
  }

  /// Whether export should apply a color operation (same rule as v1 planner).
  bool get isActive =>
      effectId != 'normal' && intensity > kColorGradeActiveIntensity;

  factory ColorGrade.fromProject(
    ProjectDocument project, {
    EffectRegistry? registry,
  }) {
    final id = project.activeFilterId ?? 'normal';
    final intensity = project.activeFilterIntensity;
    var base = kIdentityColorMatrix;
    if (registry != null) {
      final desc = registry[id];
      if (desc is LutColorEffectDescriptor) {
        base = desc.matrix;
      }
    }
    return ColorGrade(
      effectId: id,
      intensity: intensity,
      matrix: matrixWithIntensity(base, intensity),
    );
  }

  Map<String, dynamic> toJson() => {
    'effectId': effectId,
    'intensity': intensity,
    'matrix': matrix,
  };

  factory ColorGrade.fromJson(Map<String, dynamic> json) {
    return ColorGrade(
      effectId: json['effectId'] as String? ?? 'normal',
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
      matrix: (json['matrix'] as List? ?? kIdentityColorMatrix)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  @override
  List<Object?> get props => [effectId, intensity, matrix];
}

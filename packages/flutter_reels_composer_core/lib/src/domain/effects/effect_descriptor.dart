import 'package:flutter/widgets.dart';

import '../../capabilities/composer_feature.dart';
import 'effect_category.dart';

typedef EffectWidgetBuilder =
    Widget Function(
      BuildContext context,
      void Function(String effectId) onSelected,
      String? selectedId,
    );

abstract class EffectDescriptor {
  String get id;
  String get name;
  EffectCategory get category;
  ComposerFeature get requiredFeature;
  EffectWidgetBuilder? get editorUi => null;
}

class LutColorEffectDescriptor implements EffectDescriptor {
  LutColorEffectDescriptor({
    required this.id,
    required this.name,
    required this.matrix,
  });

  @override
  final String id;
  @override
  final String name;
  final List<double> matrix;

  @override
  EffectCategory get category => EffectCategory.color;

  @override
  ComposerFeature get requiredFeature => ComposerFeature.colorFilters;

  @override
  EffectWidgetBuilder? get editorUi => null;
}

class EffectPack {
  const EffectPack({
    required this.id,
    required this.version,
    required this.effects,
  });

  final String id;
  final int version;
  final List<EffectDescriptor> effects;
}

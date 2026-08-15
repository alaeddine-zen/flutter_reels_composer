import 'effect_descriptor.dart';

class EffectCatalog {
  const EffectCatalog({this.effects = const []});

  final List<EffectDescriptor> effects;

  static const empty = EffectCatalog();
}

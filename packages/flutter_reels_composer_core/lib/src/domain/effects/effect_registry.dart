import 'effect_category.dart';
import 'effect_descriptor.dart';

class EffectRegistry {
  final Map<String, EffectDescriptor> _byId = {};

  void register(EffectDescriptor effect) {
    _byId[effect.id] = effect;
  }

  void registerAll(Iterable<EffectDescriptor> effects) {
    for (final e in effects) {
      register(e);
    }
  }

  EffectDescriptor? operator [](String id) => _byId[id];

  List<EffectDescriptor> byCategory(EffectCategory category) {
    return _byId.values.where((e) => e.category == category).toList();
  }

  List<LutColorEffectDescriptor> get colorFilters {
    return _byId.values.whereType<LutColorEffectDescriptor>().toList();
  }

  List<EffectDescriptor> get all => List.unmodifiable(_byId.values);

  void clear() => _byId.clear();
}

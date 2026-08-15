import 'composer_feature.dart';

class ComposerCapabilities {
  const ComposerCapabilities(this._features);

  final Set<ComposerFeature> _features;

  bool has(ComposerFeature feature) => _features.contains(feature);

  Set<ComposerFeature> get features => Set.unmodifiable(_features);

  ComposerCapabilities intersect(Set<ComposerFeature> enabled) {
    return ComposerCapabilities(_features.intersection(enabled));
  }

  static const ComposerCapabilities localV1 = ComposerCapabilities(
    kDefaultV1Features,
  );
}

class CapabilityGate {
  const CapabilityGate(this.effective);

  final ComposerCapabilities effective;

  factory CapabilityGate.resolve({
    required ComposerCapabilities engine,
    required Set<ComposerFeature> enabledFeatures,
  }) {
    return CapabilityGate(engine.intersect(enabledFeatures));
  }

  bool allows(ComposerFeature feature) => effective.has(feature);

  List<ComposerFeature> get editorToolOrder {
    const order = [
      ComposerFeature.trim,
      ComposerFeature.colorFilters,
      ComposerFeature.textOverlays,
      ComposerFeature.aiCaptions,
      ComposerFeature.musicMix,
      ComposerFeature.cover,
      ComposerFeature.speed,
      ComposerFeature.templates,
      ComposerFeature.arMasks,
      ComposerFeature.beauty,
      ComposerFeature.stickers,
    ];
    return order.where(allows).toList();
  }
}

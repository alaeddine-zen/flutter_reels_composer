import 'dart:convert';

import '../effects/effect_descriptor.dart';

class EffectAssetStore {
  EffectPack parsePack(String raw, {required String id}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final effects = <EffectDescriptor>[];
    for (final item in (json['effects'] as List? ?? const [])) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['category'] == 'color') {
        effects.add(
          LutColorEffectDescriptor(
            id: map['id'] as String,
            name: map['name'] as String,
            matrix: (map['matrix'] as List)
                .map((e) => (e as num).toDouble())
                .toList(),
          ),
        );
      }
    }
    return EffectPack(
      id: id,
      version: json['version'] as int? ?? 1,
      effects: effects,
    );
  }
}

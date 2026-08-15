import 'package:equatable/equatable.dart';

class EffectInstance extends Equatable {
  const EffectInstance({
    required this.id,
    required this.effectId,
    required this.category,
    this.params = const {},
  });

  final String id;
  final String effectId;
  final String category;
  final Map<String, dynamic> params;

  EffectInstance copyWith({
    String? id,
    String? effectId,
    String? category,
    Map<String, dynamic>? params,
  }) {
    return EffectInstance(
      id: id ?? this.id,
      effectId: effectId ?? this.effectId,
      category: category ?? this.category,
      params: params ?? this.params,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'effectId': effectId,
    'category': category,
    'params': params,
  };

  factory EffectInstance.fromJson(Map<String, dynamic> json) {
    return EffectInstance(
      id: json['id'] as String,
      effectId: json['effectId'] as String,
      category: json['category'] as String,
      params: Map<String, dynamic>.from(json['params'] as Map? ?? const {}),
    );
  }

  @override
  List<Object?> get props => [id, effectId, category, params];
}

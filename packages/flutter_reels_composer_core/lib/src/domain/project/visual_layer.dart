import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

enum VisualLayerType { text, sticker, drawing }

enum TextBackdrop { none, stroke, fill }

const Object _unset = Object();

class VisualLayer extends Equatable {
  const VisualLayer({
    required this.id,
    required this.type,
    required this.normalizedPosition,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.text,
    this.colorValue = 0xFFFFFFFF,
    this.fontSize = 28,
    this.textBackdrop = TextBackdrop.stroke,
    this.assetId,
    this.zIndex = 0,
    this.startAt,
    this.endAt,
    this.role,
  });

  static const roleCaption = 'caption';
  static const roleTemplate = 'template';

  final String id;
  final VisualLayerType type;
  final Offset normalizedPosition;
  final double scale;
  final double rotation;
  final String? text;
  final int colorValue;
  final double fontSize;
  final TextBackdrop textBackdrop;
  final String? assetId;
  final int zIndex;
  final Duration? startAt;
  final Duration? endAt;
  final String? role;

  Color get color => Color(colorValue);

  bool get isTimed => startAt != null || endAt != null;

  bool visibleAt(Duration position) {
    if (startAt != null && position < startAt!) return false;
    if (endAt != null && position >= endAt!) return false;
    return true;
  }

  VisualLayer copyWith({
    String? id,
    VisualLayerType? type,
    Offset? normalizedPosition,
    double? scale,
    double? rotation,
    String? text,
    int? colorValue,
    double? fontSize,
    TextBackdrop? textBackdrop,
    String? assetId,
    int? zIndex,
    Object? startAt = _unset,
    Object? endAt = _unset,
    Object? role = _unset,
  }) {
    return VisualLayer(
      id: id ?? this.id,
      type: type ?? this.type,
      normalizedPosition: normalizedPosition ?? this.normalizedPosition,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      text: text ?? this.text,
      colorValue: colorValue ?? this.colorValue,
      fontSize: fontSize ?? this.fontSize,
      textBackdrop: textBackdrop ?? this.textBackdrop,
      assetId: assetId ?? this.assetId,
      zIndex: zIndex ?? this.zIndex,
      startAt: identical(startAt, _unset) ? this.startAt : startAt as Duration?,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as Duration?,
      role: identical(role, _unset) ? this.role : role as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'nx': normalizedPosition.dx,
    'ny': normalizedPosition.dy,
    'scale': scale,
    'rotation': rotation,
    'text': text,
    'colorValue': colorValue,
    'fontSize': fontSize,
    'textBackdrop': textBackdrop.name,
    'assetId': assetId,
    'zIndex': zIndex,
    'startAtMs': startAt?.inMilliseconds,
    'endAtMs': endAt?.inMilliseconds,
    'role': role,
  };

  factory VisualLayer.fromJson(Map<String, dynamic> json) {
    final backdropName = json['textBackdrop'] as String?;
    return VisualLayer(
      id: json['id'] as String,
      type: VisualLayerType.values.byName(json['type'] as String),
      normalizedPosition: Offset(
        (json['nx'] as num).toDouble(),
        (json['ny'] as num).toDouble(),
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
      textBackdrop: backdropName == null
          ? TextBackdrop.stroke
          : TextBackdrop.values.firstWhere(
              (e) => e.name == backdropName,
              orElse: () => TextBackdrop.stroke,
            ),
      assetId: json['assetId'] as String?,
      zIndex: json['zIndex'] as int? ?? 0,
      startAt: json['startAtMs'] == null
          ? null
          : Duration(milliseconds: json['startAtMs'] as int),
      endAt: json['endAtMs'] == null
          ? null
          : Duration(milliseconds: json['endAtMs'] as int),
      role: json['role'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    normalizedPosition,
    scale,
    rotation,
    text,
    colorValue,
    fontSize,
    textBackdrop,
    assetId,
    zIndex,
    startAt,
    endAt,
    role,
  ];
}

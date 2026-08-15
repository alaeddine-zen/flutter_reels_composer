import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../project/duet_layout.dart';
import '../project/visual_layer.dart';

class TemplateLayerSpec extends Equatable {
  const TemplateLayerSpec({
    required this.text,
    this.nx = 0.5,
    this.ny = 0.2,
    this.fontSize = 28,
    this.colorValue = 0xFFFFFFFF,
    this.textBackdrop = TextBackdrop.stroke,
    this.scale = 1.0,
  });

  final String text;
  final double nx;
  final double ny;
  final double fontSize;
  final int colorValue;
  final TextBackdrop textBackdrop;
  final double scale;

  VisualLayer toLayer(String id) {
    return VisualLayer(
      id: id,
      type: VisualLayerType.text,
      normalizedPosition: Offset(nx, ny),
      text: text,
      fontSize: fontSize,
      colorValue: colorValue,
      textBackdrop: textBackdrop,
      scale: scale,
      role: VisualLayer.roleTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'nx': nx,
    'ny': ny,
    'fontSize': fontSize,
    'colorValue': colorValue,
    'textBackdrop': textBackdrop.name,
    'scale': scale,
  };

  factory TemplateLayerSpec.fromJson(Map<String, dynamic> json) {
    final backdrop = json['textBackdrop'] as String?;
    return TemplateLayerSpec(
      text: json['text'] as String? ?? '',
      nx: (json['nx'] as num?)?.toDouble() ?? 0.5,
      ny: (json['ny'] as num?)?.toDouble() ?? 0.2,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28,
      colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
      textBackdrop: backdrop == null
          ? TextBackdrop.stroke
          : TextBackdrop.values.firstWhere(
              (e) => e.name == backdrop,
              orElse: () => TextBackdrop.stroke,
            ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  List<Object?> get props => [
    text,
    nx,
    ny,
    fontSize,
    colorValue,
    textBackdrop,
    scale,
  ];
}

class ReelTemplate extends Equatable {
  const ReelTemplate({
    required this.id,
    required this.name,
    this.filterId,
    this.speed,
    this.musicId,
    this.clipSlots = 1,
    this.suggestedDuration = const Duration(seconds: 15),
    this.duetLayout = DuetLayout.none,
    this.layers = const [],
  });

  final String id;
  final String name;
  final String? filterId;
  final double? speed;
  final String? musicId;
  final int clipSlots;
  final Duration suggestedDuration;
  final DuetLayout duetLayout;
  final List<TemplateLayerSpec> layers;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filterId': filterId,
    'speed': speed,
    'musicId': musicId,
    'clipSlots': clipSlots,
    'suggestedDurationMs': suggestedDuration.inMilliseconds,
    'duetLayout': duetLayout.name,
    'layers': layers.map((e) => e.toJson()).toList(),
  };

  factory ReelTemplate.fromJson(Map<String, dynamic> json) {
    return ReelTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      filterId: json['filterId'] as String?,
      speed: (json['speed'] as num?)?.toDouble(),
      musicId: json['musicId'] as String?,
      clipSlots: json['clipSlots'] as int? ?? 1,
      suggestedDuration: Duration(
        milliseconds: json['suggestedDurationMs'] as int? ?? 15000,
      ),
      duetLayout: DuetLayoutX.parse(json['duetLayout'] as String?),
      layers: (json['layers'] as List? ?? const [])
          .map(
            (e) =>
                TemplateLayerSpec.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    filterId,
    speed,
    musicId,
    clipSlots,
    suggestedDuration,
    duetLayout,
    layers,
  ];
}

class TemplateCatalog {
  const TemplateCatalog({this.templates = const []});

  final List<ReelTemplate> templates;

  static const empty = TemplateCatalog();

  ReelTemplate? byId(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  factory TemplateCatalog.fromJson(Map<String, dynamic> json) {
    return TemplateCatalog(
      templates: (json['templates'] as List? ?? const [])
          .map(
            (e) => ReelTemplate.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  /// Default English catalog. Keep ids and structure in sync with
  /// `packages/flutter_reels_composer_ui/assets/templates/templates.json`.
  static TemplateCatalog get bundled => const TemplateCatalog(
    templates: [
      ReelTemplate(
        id: 'intro_trend',
        name: 'Trend intro',
        filterId: 'vivid',
        layers: [TemplateLayerSpec(text: 'Write here', ny: 0.18, fontSize: 32)],
      ),
      ReelTemplate(
        id: 'punchline',
        name: 'Punchline',
        filterId: 'cinema',
        layers: [
          TemplateLayerSpec(text: 'Your punchline', ny: 0.45, fontSize: 36),
        ],
      ),
      ReelTemplate(
        id: 'recap_3',
        name: '3-clip recap',
        clipSlots: 3,
        suggestedDuration: Duration(seconds: 30),
        layers: [
          TemplateLayerSpec(text: '1', nx: 0.12, ny: 0.12, fontSize: 22),
          TemplateLayerSpec(text: '2', nx: 0.12, ny: 0.45, fontSize: 22),
          TemplateLayerSpec(text: '3', nx: 0.12, ny: 0.78, fontSize: 22),
        ],
      ),
      ReelTemplate(
        id: 'slow_mo',
        name: 'Slow-mo',
        filterId: 'cinema',
        speed: 0.5,
        layers: [
          TemplateLayerSpec(
            text: 'Slow motion',
            ny: 0.82,
            fontSize: 22,
            textBackdrop: TextBackdrop.fill,
          ),
        ],
      ),
      ReelTemplate(
        id: 'quote',
        name: 'Quote',
        filterId: 'fade',
        layers: [
          TemplateLayerSpec(
            text: '"Your quote"',
            ny: 0.42,
            fontSize: 28,
            textBackdrop: TextBackdrop.fill,
          ),
        ],
      ),
      ReelTemplate(
        id: 'duet_ready',
        name: 'Duet-ready',
        duetLayout: DuetLayout.split,
        layers: [TemplateLayerSpec(text: 'React', ny: 0.72, fontSize: 26)],
      ),
    ],
  );
}

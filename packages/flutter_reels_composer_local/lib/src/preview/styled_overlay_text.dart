import 'package:flutter/material.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// Shared text look for preview / editor / (mirror export styles).
class StyledOverlayText extends StatelessWidget {
  const StyledOverlayText({super.key, required this.layer, this.maxWidth});

  final VisualLayer layer;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: layer.color,
      fontSize: layer.fontSize,
      fontWeight: FontWeight.w800,
      height: 1.15,
      shadows: layer.textBackdrop == TextBackdrop.stroke
          ? _strokeShadows(layer.color)
          : const [
              Shadow(
                blurRadius: 4,
                color: Colors.black87,
                offset: Offset(0, 1),
              ),
            ],
    );

    Widget child = Text(
      layer.text ?? '',
      textAlign: TextAlign.center,
      textDirection: textLooksRtl(layer.text ?? '')
          ? TextDirection.rtl
          : TextDirection.ltr,
      style: style,
    );

    if (layer.textBackdrop == TextBackdrop.fill) {
      child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
    }

    if (maxWidth != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: child,
      );
    }

    return Transform.scale(
      scale: layer.scale,
      child: Transform.rotate(angle: layer.rotation, child: child),
    );
  }

  /// Outline via multi-offset shadows (same approach as the export PNG).
  static List<Shadow> _strokeShadows(Color fill) {
    const offsets = <Offset>[
      Offset(-1.5, -1.5),
      Offset(1.5, -1.5),
      Offset(-1.5, 1.5),
      Offset(1.5, 1.5),
      Offset(0, -1.8),
      Offset(0, 1.8),
      Offset(-1.8, 0),
      Offset(1.8, 0),
    ];
    return [
      for (final o in offsets)
        Shadow(blurRadius: 0, color: Colors.black, offset: o),
      Shadow(
        blurRadius: 2,
        color: fill.withValues(alpha: 0.2),
        offset: Offset.zero,
      ),
    ];
  }
}

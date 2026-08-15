import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'styled_overlay_text.dart';

/// Interactive text overlays: select, drag, pinch-scale, delete.
class EditableTextLayers extends StatefulWidget {
  const EditableTextLayers({
    super.key,
    required this.controller,
    required this.project,
    this.selectedId,
    this.onSelected,
    this.position,
  });

  final ComposerController controller;
  final ProjectDocument project;
  final String? selectedId;
  final ValueChanged<String?>? onSelected;
  final Duration? position;

  @override
  State<EditableTextLayers> createState() => _EditableTextLayersState();
}

class _EditableTextLayersState extends State<EditableTextLayers> {
  double _scaleAtStart = 1;
  double _rotationAtStart = 0;
  String? _draggingId;

  List<VisualLayer> get _layers {
    final pos = widget.position;
    return widget.project.layers
        .where((l) => l.type == VisualLayerType.text)
        .where((l) => pos == null || l.visibleAt(pos))
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  Future<void> _update(VisualLayer layer) async {
    await widget.controller.applyLive(UpdateLayerMutation(layer));
  }

  Future<void> _delete(String id) async {
    HapticFeedback.mediumImpact();
    widget.controller.endLive();
    await widget.controller.apply(RemoveLayerMutation(id));
    if (widget.selectedId == id) {
      widget.onSelected?.call(null);
    }
  }

  void _select(String id) {
    HapticFeedback.selectionClick();
    widget.onSelected?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // No full-screen hit target — empty space must pass taps to the
        // preview play/pause GestureDetector underneath.
        return Stack(
          fit: StackFit.expand,
          children: [
            ..._layers.map((layer) {
              final selected = layer.id == widget.selectedId;
              final left = layer.normalizedPosition.dx * w;
              final top = layer.normalizedPosition.dy * h;
              return Positioned(
                left: left,
                top: top,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: GestureDetector(
                    key: ValueKey('text-layer-${layer.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _select(layer.id),
                    onDoubleTap: () => _select(layer.id),
                    onLongPress: () => _delete(layer.id),
                    onScaleStart: (_) {
                      _draggingId = layer.id;
                      _scaleAtStart = layer.scale;
                      _rotationAtStart = layer.rotation;
                      _select(layer.id);
                    },
                    onScaleUpdate: (details) {
                      VisualLayer? current;
                      for (final l in widget.project.layers) {
                        if (l.id == layer.id) {
                          current = l;
                          break;
                        }
                      }
                      if (current == null) return;
                      if (details.pointerCount >= 2) {
                        final next = (_scaleAtStart * details.scale).clamp(
                          0.5,
                          3.0,
                        );
                        final rot = _rotationAtStart + details.rotation;
                        _update(current.copyWith(scale: next, rotation: rot));
                        return;
                      }
                      final nx =
                          (current.normalizedPosition.dx +
                                  details.focalPointDelta.dx / w)
                              .clamp(0.05, 0.95);
                      final ny =
                          (current.normalizedPosition.dy +
                                  details.focalPointDelta.dy / h)
                              .clamp(0.05, 0.95);
                      _update(
                        current.copyWith(normalizedPosition: Offset(nx, ny)),
                      );
                    },
                    onScaleEnd: (_) {
                      _draggingId = null;
                      widget.controller.endLive();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: selected || _draggingId == layer.id
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: StyledOverlayText(layer: layer),
                        ),
                        if (selected)
                          Positioned(
                            right: -10,
                            top: -10,
                            child: GestureDetector(
                              onTap: () => _delete(layer.id),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black87,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

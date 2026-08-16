import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';

/// Add or edit text overlays (TikTok-style: select → edit size/color/content).
class TextToolPanel extends StatefulWidget {
  const TextToolPanel({
    super.key,
    required this.theme,
    required this.controller,
    required this.project,
    this.selectedLayerId,
    this.onSelectedLayerId,
    this.onClearSelection,
  });

  final ComposerTheme theme;
  final ComposerController controller;
  final ProjectDocument project;
  final String? selectedLayerId;
  final ValueChanged<String?>? onSelectedLayerId;
  final VoidCallback? onClearSelection;

  @override
  State<TextToolPanel> createState() => _TextToolPanelState();
}

class _TextToolPanelState extends State<TextToolPanel> {
  final _controller = TextEditingController();
  static const _colors = [
    0xFFFFFFFF,
    0xFFFF2D55,
    0xFFFFCC00,
    0xFF34C759,
    0xFF5AC8FA,
    0xFFAF52DE,
  ];
  int _color = 0xFFFFFFFF;
  double _fontSize = 28;
  TextBackdrop _backdrop = TextBackdrop.stroke;
  String? _hydratedId;

  VisualLayer? get _selected {
    final id = widget.selectedLayerId;
    if (id == null) return null;
    for (final l in widget.project.layers) {
      if (l.id == id && l.type == VisualLayerType.text) return l;
    }
    return null;
  }

  bool get _editing => _selected != null;

  @override
  void initState() {
    super.initState();
    _hydrateFromSelection(force: true);
  }

  @override
  void didUpdateWidget(covariant TextToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLayerId != widget.selectedLayerId ||
        oldWidget.project != widget.project) {
      _hydrateFromSelection(
        force: oldWidget.selectedLayerId != widget.selectedLayerId,
      );
    }
  }

  void _hydrateFromSelection({bool force = false}) {
    final layer = _selected;
    if (layer == null) {
      if (force || _hydratedId != null) {
        _hydratedId = null;
        if (force) {
          _controller.clear();
          _color = 0xFFFFFFFF;
          _fontSize = 28;
          _backdrop = TextBackdrop.stroke;
        }
      }
      return;
    }
    if (!force && _hydratedId == layer.id) {
      // Sync size when changed externally (pinch); keep in-progress typing.
      if ((_fontSize - layer.fontSize).abs() > 0.5) {
        _fontSize = layer.fontSize;
      }
      return;
    }
    _hydratedId = layer.id;
    _controller.text = layer.text ?? '';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _color = layer.colorValue;
    _fontSize = layer.fontSize;
    _backdrop = layer.textBackdrop;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyColor(int color) async {
    HapticFeedback.selectionClick();
    setState(() => _color = color);
    final layer = _selected;
    if (layer == null) return;
    await widget.controller.apply(
      UpdateLayerMutation(layer.copyWith(colorValue: color)),
    );
  }

  Future<void> _applyFontSize(double size) async {
    setState(() => _fontSize = size);
    final layer = _selected;
    if (layer == null) return;
    await widget.controller.applyLive(
      UpdateLayerMutation(layer.copyWith(fontSize: size)),
    );
  }

  Future<void> _applyBackdrop(TextBackdrop backdrop) async {
    HapticFeedback.selectionClick();
    setState(() => _backdrop = backdrop);
    final layer = _selected;
    if (layer == null) return;
    await widget.controller.apply(
      UpdateLayerMutation(layer.copyWith(textBackdrop: backdrop)),
    );
  }

  Future<void> _commit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final existing = _selected;
    if (existing != null) {
      await widget.controller.apply(
        UpdateLayerMutation(
          existing.copyWith(
            text: text,
            colorValue: _color,
            fontSize: _fontSize,
            textBackdrop: _backdrop,
          ),
        ),
      );
      return;
    }

    final userTexts = widget.project.layers
        .where((l) => l.type == VisualLayerType.text && l.role == null)
        .length;
    if (userTexts >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.composerL10n.text('textMaxThree'))),
      );
      return;
    }
    final id = const Uuid().v4();
    await widget.controller.apply(
      AddTextLayerMutation(
        layerId: id,
        text: text,
        colorValue: _color,
        fontSize: _fontSize,
        textBackdrop: _backdrop,
      ),
    );
    _controller.clear();
  }

  Future<void> _deleteSelected() async {
    final layer = _selected;
    if (layer == null) return;
    HapticFeedback.mediumImpact();
    await widget.controller.apply(RemoveLayerMutation(layer.id));
    widget.onClearSelection?.call();
    _controller.clear();
    setState(() {
      _hydratedId = null;
      _color = 0xFFFFFFFF;
      _fontSize = 28;
      _backdrop = TextBackdrop.stroke;
    });
  }

  void _startNew() {
    widget.onClearSelection?.call();
    setState(() {
      _hydratedId = null;
      _controller.clear();
      _color = 0xFFFFFFFF;
      _fontSize = 28;
      _backdrop = TextBackdrop.stroke;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                context.composerL10n.text(_editing ? 'editText' : 'addText'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_editing) ...[
                TextButton(
                  onPressed: _startNew,
                  child: Text(
                    context.composerL10n.text('newText'),
                    style: TextStyle(color: widget.theme.accent),
                  ),
                ),
                IconButton(
                  onPressed: _deleteSelected,
                  tooltip: context.composerL10n.text('delete'),
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: context.composerL10n.text(
                      _editing ? 'editText' : 'writeSomething',
                    ),
                    hintStyle: TextStyle(color: widget.theme.muted),
                    filled: true,
                    fillColor: widget.theme.secondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (value) {
                    final layer = _selected;
                    if (layer == null) return;
                    // Live-update overlay while typing (trimmed empty ignored).
                    final next = value.trimRight();
                    if (next.isEmpty) return;
                    widget.controller.applyLive(
                      UpdateLayerMutation(
                        layer.copyWith(
                          text: next,
                          colorValue: _color,
                          fontSize: _fontSize,
                          textBackdrop: _backdrop,
                        ),
                      ),
                    );
                  },
                  onSubmitted: (_) {
                    widget.controller.endLive();
                    _commit();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _commit,
                style: IconButton.styleFrom(
                  backgroundColor: widget.theme.accent,
                ),
                icon: Icon(_editing ? Icons.done : Icons.check),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StyleChip(
                label: context.composerL10n.text('textShadow'),
                selected: _backdrop == TextBackdrop.none,
                accent: widget.theme.accent,
                onTap: () => _applyBackdrop(TextBackdrop.none),
              ),
              const SizedBox(width: 8),
              _StyleChip(
                label: context.composerL10n.text('textOutline'),
                selected: _backdrop == TextBackdrop.stroke,
                accent: widget.theme.accent,
                onTap: () => _applyBackdrop(TextBackdrop.stroke),
              ),
              const SizedBox(width: 8),
              _StyleChip(
                label: context.composerL10n.text('textFill'),
                selected: _backdrop == TextBackdrop.fill,
                accent: widget.theme.accent,
                onTap: () => _applyBackdrop(TextBackdrop.fill),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.text_fields, color: widget.theme.muted, size: 18),
              Expanded(
                child: Slider(
                  value: _fontSize.clamp(16, 72),
                  min: 16,
                  max: 72,
                  activeColor: widget.theme.accent,
                  inactiveColor: Colors.white24,
                  onChanged: _applyFontSize,
                  onChangeEnd: (_) => widget.controller.endLive(),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${_fontSize.round()}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: widget.theme.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          Row(
            children: _colors.map((c) {
              final selected = c == _color;
              return GestureDetector(
                onTap: () => _applyColor(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? widget.theme.accent : Colors.white24,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Builder(
            builder: (context) {
              final texts = widget.project.layers
                  .where(
                    (l) =>
                        l.type == VisualLayerType.text &&
                        l.role != VisualLayer.roleCaption,
                  )
                  .toList();
              if (texts.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: texts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final layer = texts[index];
                      final selected = layer.id == widget.selectedLayerId;
                      final label = (layer.text ?? '').trim();
                      return ChoiceChip(
                        label: Text(
                          label.isEmpty
                              ? context.composerL10n.textWith('textNumber', {
                                  'number': index + 1,
                                })
                              : (label.length > 18
                                    ? '${label.substring(0, 18)}…'
                                    : label),
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        selected: selected,
                        selectedColor: widget.theme.accent,
                        backgroundColor: Colors.white12,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          widget.onSelectedLayerId?.call(layer.id);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.35) : Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

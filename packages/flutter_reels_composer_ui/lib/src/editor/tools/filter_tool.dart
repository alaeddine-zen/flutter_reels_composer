import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';

class FilterToolPanel extends StatefulWidget {
  const FilterToolPanel({
    super.key,
    required this.theme,
    required this.controller,
    required this.selectedId,
    required this.intensity,
    this.frameExtractor = const NoopFrameExtractor(),
    this.previewSourcePath,
    this.onCompareChanged,
  });

  final ComposerTheme theme;
  final ComposerController controller;
  final String? selectedId;
  final double intensity;
  final FrameExtractorPort frameExtractor;
  final String? previewSourcePath;
  final ValueChanged<bool>? onCompareChanged;

  ComposerEngine get engine => controller.engine;

  @override
  State<FilterToolPanel> createState() => _FilterToolPanelState();
}

class _FilterToolPanelState extends State<FilterToolPanel> {
  late double _intensity;
  File? _thumb;

  @override
  void initState() {
    super.initState();
    _intensity = widget.intensity.clamp(0.0, 1.0);
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant FilterToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      _intensity = widget.intensity.clamp(0.0, 1.0);
    }
    if (oldWidget.previewSourcePath != widget.previewSourcePath) {
      _loadThumb();
    }
  }

  Future<void> _loadThumb() async {
    final path = widget.previewSourcePath;
    if (path == null || path.isEmpty) {
      setState(() => _thumb = null);
      return;
    }
    final f = await widget.frameExtractor.extractOne(
      sourcePath: path,
      height: 128,
    );
    if (!mounted) return;
    setState(() => _thumb = f);
  }

  Future<void> _applyFilter(String id) async {
    HapticFeedback.selectionClick();
    await widget.controller.apply(
      SetColorFilterMutation(id, intensity: _intensity),
    );
  }

  Future<void> _applyIntensity(double v) async {
    setState(() => _intensity = v);
    final id = widget.selectedId ?? 'normal';
    await widget.controller.applyLive(SetColorFilterMutation(id, intensity: v));
  }

  @override
  Widget build(BuildContext context) {
    final filters = widget.controller.engine.effectRegistry.colorFilters;
    if (filters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.composerL10n.text('noFilter'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.composerL10n.text('filter'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final f = filters[index];
              final selected = f.id == (widget.selectedId ?? 'normal');
              final matrix = matrixWithIntensity(f.matrix, _intensity);
              return GestureDetector(
                onTap: () => _applyFilter(f.id),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? widget.theme.accent
                              : Colors.white24,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: _thumb != null
                            ? Image.file(_thumb!, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF667788),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.landscape,
                                  color: Colors.white70,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.name,
                      style: TextStyle(
                        color: selected
                            ? widget.theme.accent
                            : widget.theme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text(
                context.composerL10n.text('intensity'),
                style: TextStyle(color: widget.theme.muted, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _intensity,
                  onChanged: _applyIntensity,
                  onChangeEnd: (_) => widget.controller.endLive(),
                  activeColor: widget.theme.accent,
                  inactiveColor: Colors.white24,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(_intensity * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: widget.theme.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Listener(
              onPointerDown: (_) => widget.onCompareChanged?.call(true),
              onPointerUp: (_) => widget.onCompareChanged?.call(false),
              onPointerCancel: (_) => widget.onCompareChanged?.call(false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Maintenir · original',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

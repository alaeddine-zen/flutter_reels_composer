import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';

const kSpeedPresets = [0.3, 0.5, 1.0, 1.5, 2.0, 3.0];

class SpeedToolPanel extends StatelessWidget {
  const SpeedToolPanel({
    super.key,
    required this.theme,
    required this.engine,
    required this.project,
    required this.preview,
    this.onChanged,
  });

  final ComposerTheme theme;
  final ComposerEngine engine;
  final ProjectDocument project;
  final PreviewPort preview;
  final ValueChanged<double>? onChanged;

  int get _clipIndex {
    if (project.clips.isEmpty) return 0;
    var remaining = preview.position;
    var index = 0;
    while (index < project.clips.length - 1 &&
        remaining > project.clips[index].trimmedDuration) {
      remaining -= project.clips[index].trimmedDuration;
      index++;
    }
    return index;
  }

  String _label(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toStringAsFixed(0)}×';
    return '${speed.toStringAsFixed(1)}×';
  }

  @override
  Widget build(BuildContext context) {
    if (project.clips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.composerL10n.text('noClip'),
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    final clip = project.clips[_clipIndex.clamp(0, project.clips.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            project.clips.length > 1
                ? context.composerL10n.textWith('speedClip', {
                    'current': _clipIndex + 1,
                    'total': project.clips.length,
                  })
                : context.composerL10n.text('speed'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final speed in kSpeedPresets)
                ChoiceChip(
                  label: Text(_label(speed)),
                  selected: (clip.speed - speed).abs() < 0.001,
                  onSelected: (_) async {
                    HapticFeedback.selectionClick();
                    await engine.applyMutation(
                      UpdateClipSpeedMutation(clipId: clip.id, speed: speed),
                    );
                    onChanged?.call(speed);
                  },
                  selectedColor: theme.accent,
                  labelStyle: TextStyle(
                    color: (clip.speed - speed).abs() < 0.001
                        ? Colors.white
                        : theme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: theme.secondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

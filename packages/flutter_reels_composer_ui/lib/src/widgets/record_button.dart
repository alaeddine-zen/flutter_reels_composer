import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.theme,
    required this.progress,
    required this.isRecording,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final ComposerTheme theme;
  final double progress;
  final bool isRecording;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final size = theme.recordButtonSize;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        onLongPressStart();
      },
      onLongPressEnd: (_) => onLongPressEnd(),
      child: SizedBox(
        width: size + 16,
        height: size + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size + 16,
              height: size + 16,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 4,
                color: theme.accent,
                backgroundColor: Colors.white24,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: isRecording ? size * 0.55 : size,
              height: isRecording ? size * 0.55 : size,
              decoration: BoxDecoration(
                color: theme.recordRed,
                shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isRecording ? BorderRadius.circular(12) : null,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

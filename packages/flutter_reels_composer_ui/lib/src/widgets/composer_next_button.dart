import 'package:flutter/material.dart';

/// TikTok editor chrome: bold white « Next » + chevron, not a filled stadium.
class ComposerNextButton extends StatelessWidget {
  const ComposerNextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
            ),
          ),
          const Icon(Icons.chevron_right, size: 22),
        ],
      ),
    );
  }
}

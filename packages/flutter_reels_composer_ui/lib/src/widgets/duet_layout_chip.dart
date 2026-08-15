import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact Split / PiP chip used on camera and editor.
class DuetLayoutChip extends StatelessWidget {
  const DuetLayoutChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.black54,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? accent : Colors.white24),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

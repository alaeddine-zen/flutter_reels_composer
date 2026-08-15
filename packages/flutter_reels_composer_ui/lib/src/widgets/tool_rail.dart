import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// TikTok-style vertical rail (default) or horizontal bottom rail.
class ToolRail extends StatelessWidget {
  const ToolRail({
    super.key,
    required this.theme,
    required this.tools,
    required this.selected,
    required this.l10n,
    required this.onSelected,
    this.axis = Axis.vertical,
  });

  final ComposerTheme theme;
  final List<EditorTool> tools;
  final String? selected;
  final ComposerToolL10n l10n;
  final ValueChanged<EditorTool> onSelected;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _ToolChip(
              theme: theme,
              icon: tools[i].icon(context),
              label: tools[i].label(l10n),
              active: tools[i].id == selected,
              vertical: true,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(tools[i]);
              },
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return _ToolChip(
            theme: theme,
            icon: tool.icon(context),
            label: tool.label(l10n),
            active: tool.id == selected,
            vertical: false,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(tool);
            },
          );
        },
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.theme,
    required this.icon,
    required this.label,
    required this.active,
    required this.vertical,
    required this.onTap,
  });

  final ComposerTheme theme;
  final IconData icon;
  final String label;
  final bool active;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: vertical ? 44 : null,
            height: vertical ? 44 : null,
            alignment: Alignment.center,
            decoration: vertical
                ? BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? theme.accent : Colors.white24,
                      width: active ? 2 : 1,
                    ),
                  )
                : null,
            child: Icon(
              icon,
              color: active ? theme.accent : theme.foreground,
              size: theme.toolIconSize,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? theme.accent : Colors.white,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
            ),
          ),
        ],
      ),
    );
  }
}

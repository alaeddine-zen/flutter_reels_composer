import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';

class TemplateToolPanel extends StatelessWidget {
  const TemplateToolPanel({
    super.key,
    required this.theme,
    required this.engine,
    required this.project,
    required this.catalog,
    this.onApplied,
  });

  final ComposerTheme theme;
  final ComposerEngine engine;
  final ProjectDocument project;
  final TemplateCatalog catalog;
  final ValueChanged<ReelTemplate>? onApplied;

  @override
  Widget build(BuildContext context) {
    final templates = catalog.templates.isEmpty
        ? TemplateCatalog.bundled.templates
        : catalog.templates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.composerL10n.text('templates'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final selected = project.templateId == null;
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await engine.applyMutation(const ClearTemplateMutation());
                    },
                    child: SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.secondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? theme.accent : Colors.white24,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.block,
                              color: selected ? theme.accent : Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.composerL10n.text('none'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? theme.accent : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final t = templates[index - 1];
                final selected = project.templateId == t.id;
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await engine.applyMutation(ApplyTemplateMutation(t));
                    onApplied?.call(t);
                  },
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.secondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? theme.accent : Colors.white24,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.dashboard_customize_outlined,
                            color: selected ? theme.accent : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? theme.accent : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

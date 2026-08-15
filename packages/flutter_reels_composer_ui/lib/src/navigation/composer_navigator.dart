import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../camera/camera_page.dart';
import '../editor/editor_page.dart';
import '../gallery/gallery_page.dart';
import '../l10n/composer_l10n.dart';

enum _ComposerStep { camera, gallery, editor }

class ComposerNavigator extends StatefulWidget {
  const ComposerNavigator({
    super.key,
    required this.config,
    required this.engine,
    this.draftStore,
  });

  final ComposerConfig config;
  final ComposerEngine engine;
  final DraftStore? draftStore;

  @override
  State<ComposerNavigator> createState() => _ComposerNavigatorState();
}

class _ComposerNavigatorState extends State<ComposerNavigator> {
  _ComposerStep _step = _ComposerStep.camera;
  ProjectDocument? _project;
  ReelTemplate? _pendingTemplate;
  late final DraftStore _drafts = widget.draftStore ?? MemoryDraftStore();
  late final ComposerToolL10n _l10n =
      widget.config.l10n ?? ComposerL10n.resolve(widget.config.locale);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_offerDraftResume());
    });
  }

  Future<void> _offerDraftResume() async {
    List<ProjectDocument> drafts;
    try {
      drafts = await _drafts.list();
    } catch (error) {
      debugPrint('ComposerNavigator: draft list failed: $error');
      return;
    }
    if (!mounted || drafts.isEmpty) return;

    final chosen = await showModalBottomSheet<ProjectDocument>(
      context: context,
      backgroundColor: widget.config.theme.sheet,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  _l10n.text('resumeDraft'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: drafts.length.clamp(0, 8),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (context, index) {
                    final d = drafts[index];
                    final updated = d.updatedAt;
                    final subtitle = updated == null
                        ? '${d.duration.inSeconds}s'
                        : '${d.duration.inSeconds}s · ${_formatRelative(updated)}';
                    return ListTile(
                      leading: const Icon(
                        Icons.movie_outlined,
                        color: Colors.white70,
                      ),
                      title: Text(
                        '${_l10n.text('draft')} ${_shortId(d.id)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white54,
                        ),
                        onPressed: () async {
                          await _drafts.delete(d.id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _offerDraftResume();
                        },
                      ),
                      onTap: () => Navigator.pop(ctx, d),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_l10n.text('newReel')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.draftRestored,
          properties: {'draftId': chosen.id},
        ),
      );
      _toEditor(chosen);
    }
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${_l10n.text('ago')} ${diff.inMinutes} ${_l10n.text('minutesShort')}';
    }
    if (diff.inHours < 48) {
      return '${_l10n.text('ago')} ${diff.inHours} ${_l10n.text('hoursShort')}';
    }
    return '${_l10n.text('ago')} ${diff.inDays} ${_l10n.text('daysShort')}';
  }

  void _close() {
    widget.config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.cancelled),
    );
    Navigator.of(context).pop();
  }

  void _toEditor(ProjectDocument project) {
    var next = project;
    final parent = widget.config.parentVideoPath;
    if (parent != null && parent.isNotEmpty && next.parentVideoPath == null) {
      next = applyProjectMutation(
        next,
        SetDuetLayoutMutation(
          layout: widget.config.duetLayout.isActive
              ? widget.config.duetLayout
              : DuetLayout.split,
          parentVideoPath: parent,
        ),
      );
    }
    if (_pendingTemplate != null && next.templateId == null) {
      next = applyProjectMutation(
        next,
        ApplyTemplateMutation(_pendingTemplate!),
      );
    }
    next = _bindTemplateMusic(next, replaceExisting: false);
    setState(() {
      _project = next;
      _step = _ComposerStep.editor;
    });
  }

  ProjectDocument _bindTemplateMusic(
    ProjectDocument project, {
    required bool replaceExisting,
  }) {
    final id = project.extras['templateMusicId'] as String?;
    if (id == null || id.isEmpty) return project;
    final track = widget.config.musicCatalog.byId(id);
    if (track == null || track.sourcePath.isEmpty) return project;
    final hasMusic = project.audioTracks.any(
      (t) =>
          t.kind == AudioTrackKind.music && (t.sourcePath?.isNotEmpty ?? false),
    );
    if (hasMusic && !replaceExisting) return project;
    return applyProjectMutation(
      project,
      SetMusicTrackMutation(
        musicId: track.id,
        sourcePath: track.sourcePath,
        volume: 1.0,
        originalVolume: 0.35,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: widget.config.theme.toThemeData(),
      child: ComposerL10nScope(
        l10n: widget.config.l10n ?? ComposerL10n.resolve(widget.config.locale),
        child: switch (_step) {
          _ComposerStep.camera => CameraPage(
            config: widget.config,
            engine: widget.engine,
            initialTemplate: _pendingTemplate,
            onTemplateChanged: (t) => _pendingTemplate = t,
            onCaptured: _toEditor,
            onOpenGallery: () => setState(() => _step = _ComposerStep.gallery),
            onClose: _close,
          ),
          _ComposerStep.gallery => GalleryPage(
            config: widget.config,
            engine: widget.engine,
            onImported: _toEditor,
            onBack: () => setState(() => _step = _ComposerStep.camera),
          ),
          _ComposerStep.editor => EditorPage(
            config: widget.config,
            engine: widget.engine,
            initialProject: _project!,
            draftStore: _drafts,
            onRetake: () => setState(() {
              _project = null;
              _step = _ComposerStep.camera;
            }),
            onCompleted: (ComposerResult result) {
              Navigator.of(context).pop(result);
            },
          ),
        },
      ),
    );
  }
}

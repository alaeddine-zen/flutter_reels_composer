import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

import '../widgets/clip_timeline.dart';
import '../widgets/duet_layout_chip.dart';
import '../widgets/tool_rail.dart';
import 'default_tools.dart';
import 'widgets/editable_text_layers.dart';
import 'widgets/preview_scrubber.dart';
import '../l10n/composer_l10n.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.config,
    required this.engine,
    required this.initialProject,
    required this.onRetake,
    required this.onCompleted,
    this.draftStore,
  });

  final ComposerConfig config;
  final ComposerEngine engine;
  final ProjectDocument initialProject;
  final VoidCallback onRetake;
  final ValueChanged<ComposerResult> onCompleted;
  final DraftStore? draftStore;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late CapabilityGate _gate;
  PreviewPort? _preview;
  String? _selectedToolId;
  String? _selectedTextId;
  bool _exporting = false;
  double _exportProgress = 0;
  ExportSession? _exportSession;
  int _exportToken = 0;
  late final DraftStore _drafts;
  late final ComposerController _controller;
  late final EditorToolRegistry _registry;
  late final ComposerToolL10n _l10n;
  Timer? _autosaveTimer;

  bool get _previewReady => _preview != null;

  @override
  void initState() {
    super.initState();
    _gate = CapabilityGate.resolve(
      engine: widget.engine.capabilities,
      enabledFeatures: widget.config.enabledFeatures,
    );
    _drafts = widget.draftStore ?? MemoryDraftStore();
    _controller = ComposerController(widget.engine);
    _l10n = widget.config.l10n ?? ComposerL10n.resolve(widget.config.locale);
    _registry = EditorToolRegistry(
      builtins: defaultEditorTools(),
      extras: widget.config.extraTools,
    );
    // Start with no panel open — TikTok opens tools on demand.
    _selectedToolId = null;
    unawaited(_bootstrap());
    final interval = widget.config.autosaveInterval;
    if (interval > Duration.zero) {
      _autosaveTimer = Timer.periodic(interval, (_) {
        unawaited(_autosaveDraft());
      });
    }
  }

  Future<void> _autosaveDraft() async {
    if (!mounted || _exporting) return;
    try {
      await _drafts.save(widget.engine.project);
    } catch (error) {
      debugPrint('EditorPage: autosave failed: $error');
    }
  }

  Future<void> _bootstrap() async {
    await widget.engine.loadProject(widget.initialProject);
    // Gallery-picked filter is initial state, not a user edit — skip undo.
    final pending = widget.initialProject.extras['pendingFilterId'] as String?;
    if (pending != null) {
      await widget.engine.applyMutation(SetColorFilterMutation(pending));
    }
    if (!mounted) return;
    final preview = widget.engine.attachPreview(widget.engine.project);
    _preview = preview;
    await preview.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    final session = _exportSession;
    _exportSession = null;
    if (session != null) {
      unawaited(session.cancel());
    }
    unawaited(_preview?.disposePreview() ?? Future<void>.value());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _persistDraftQuietly() async {
    try {
      final id = await _drafts.save(widget.engine.project);
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.draftSaved,
          properties: {'draftId': id},
        ),
      );
    } catch (error) {
      // Never block navigation on draft IO failures.
      debugPrint('EditorPage: draft save failed: $error');
    }
  }

  Future<bool> _onWillPop() async {
    if (_exporting) {
      await _cancelExport();
      return false;
    }
    // Fire-and-forget so system back never hangs on disk IO.
    unawaited(_persistDraftQuietly());
    return true;
  }

  Future<void> _cancelExport() async {
    // Invalidate in-flight export so a late success cannot complete/navigate.
    ++_exportToken;
    final session = _exportSession;
    _exportSession = null;
    await session?.cancel();
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportProgress = 0;
    });
  }

  Future<void> _confirmRetake() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          _l10n.text('retake'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _l10n.text('retakeBody'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.text('stay')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _l10n.text('retake'),
              style: TextStyle(color: widget.config.theme.accent),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _persistDraftQuietly();
      if (mounted) widget.onRetake();
    }
  }

  Future<void> _togglePlay() async {
    final preview = _preview;
    if (preview == null) return;
    HapticFeedback.selectionClick();
    if (preview.isPlaying) {
      await preview.pause();
    } else {
      await preview.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _export() async {
    if (_exporting) return;
    final token = ++_exportToken;
    setState(() {
      _exporting = true;
      _exportProgress = 0;
      _selectedToolId = null;
    });
    widget.config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.exportStarted),
    );
    final exporter = widget.config.exporter;
    if (exporter == null) {
      const error = ComposerException(
        'missing_exporter',
        'ComposerConfig.exporter is required.',
      );
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.exportFailed,
          properties: {'error': error.toString()},
        ),
      );
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.text('missingExporter'))));
      }
      return;
    }
    final session = exporter.export(
      widget.engine.project,
      const ExportOptions(includeCover: true),
    );
    _exportSession = session;
    final sub = session.progress.listen((p) {
      if (!mounted || token != _exportToken) return;
      setState(() => _exportProgress = p.progress);
    });
    try {
      final out = await session.result;
      if (!mounted || token != _exportToken) return;
      widget.config.onEvent?.call(
        const ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.exportCompleted,
        ),
      );
      final result = ComposerResult(
        videoFile: out.videoFile,
        coverFile: out.coverFile,
        project: widget.engine.project.toSnapshot(),
        duration: out.duration,
        metadata: {
          'parentPostUuid': widget.config.parentPostUuid,
          'projectId': widget.engine.project.id,
          'duetLayout': widget.engine.project.duetLayout.name,
          'templateId': widget.engine.project.templateId,
          if (out.coverFile == null) 'coverPending': true,
        },
      );
      widget.config.onEvent?.call(
        const ComposerAnalyticsEvent(ComposerAnalyticsEventType.completed),
      );
      if (!mounted || token != _exportToken) return;
      // Publication belongs to the host. Keep the draft until the host confirms
      // upload and deletes metadata['projectId'] from its DraftStore.
      widget.onCompleted(result);
    } catch (e) {
      if (token != _exportToken) return;
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.exportFailed,
          properties: {'error': e.toString()},
        ),
      );
      if (mounted && e is! ExportCancelledException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_l10n.text('exportFailed')}: $e')),
        );
      }
    } finally {
      await sub.cancel();
      if (token == _exportToken) {
        _exportSession = null;
        if (mounted) setState(() => _exporting = false);
      }
    }
  }

  void _selectTool(EditorTool tool) {
    _controller.endLive();
    widget.config.onEvent?.call(
      ComposerAnalyticsEvent(
        ComposerAnalyticsEventType.toolSelected,
        properties: {'tool': tool.id},
      ),
    );
    setState(() {
      _selectedToolId = _selectedToolId == tool.id ? null : tool.id;
      if (tool.feature != ComposerFeature.textOverlays &&
          tool.feature != ComposerFeature.aiCaptions) {
        _selectedTextId = null;
      }
    });
  }

  Future<void> _undoEdit() async {
    if (!_controller.canUndo || _exporting) return;
    HapticFeedback.selectionClick();
    await _controller.undo();
    widget.config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.undo),
    );
    if (mounted) setState(() {});
  }

  Future<void> _redoEdit() async {
    if (!_controller.canRedo || _exporting) return;
    HapticFeedback.selectionClick();
    await _controller.redo();
    widget.config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.redo),
    );
    if (mounted) setState(() {});
  }

  void _onTextSelected(String? id) {
    if (id == null) {
      setState(() => _selectedTextId = null);
      return;
    }
    VisualLayer? layer;
    for (final l in widget.engine.project.layers) {
      if (l.id == id) {
        layer = l;
        break;
      }
    }
    setState(() {
      _selectedTextId = id;
      if (layer?.role == VisualLayer.roleCaption) {
        _selectedToolId = 'captions';
      } else {
        _selectedToolId = 'text';
      }
    });
  }

  void _onPreviewTap() {
    if (_selectedTextId != null) {
      setState(() => _selectedTextId = null);
      return;
    }
    unawaited(_togglePlay());
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.config.theme;
    final tools = _registry.visible(_gate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
            unawaited(_undoEdit());
          },
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
            unawaited(_undoEdit());
          },
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): () {
            unawaited(_redoEdit());
          },
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): () {
            unawaited(_redoEdit());
          },
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
            unawaited(_redoEdit());
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: theme.background,
            body: ListenableBuilder(
              listenable: Listenable.merge([
                widget.engine.projectListenable,
                _controller,
                if (_previewReady) _preview!,
              ]),
              builder: (context, _) {
                final preview = _preview;
                if (preview == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final project = widget.engine.project;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onTap: _onPreviewTap,
                                child: preview.buildPreview(
                                  showTextLayers: false,
                                ),
                              ),
                              if (!preview.isPlaying)
                                const IgnorePointer(
                                  child: Center(
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white54,
                                      size: 72,
                                    ),
                                  ),
                                ),
                              EditableTextLayers(
                                controller: _controller,
                                project: project,
                                selectedId: _selectedTextId,
                                onSelected: _onTextSelected,
                                position: preview.position,
                              ),
                              SafeArea(
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: _exporting
                                                ? null
                                                : _confirmRetake,
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            tooltip: _l10n.text('retake'),
                                          ),
                                          IconButton(
                                            onPressed:
                                                !_exporting &&
                                                    _controller.canUndo
                                                ? () => unawaited(_undoEdit())
                                                : null,
                                            icon: Icon(
                                              Icons.undo,
                                              color:
                                                  !_exporting &&
                                                      _controller.canUndo
                                                  ? Colors.white
                                                  : Colors.white38,
                                            ),
                                            tooltip: _l10n.text('undo'),
                                          ),
                                          IconButton(
                                            onPressed:
                                                !_exporting &&
                                                    _controller.canRedo
                                                ? () => unawaited(_redoEdit())
                                                : null,
                                            icon: Icon(
                                              Icons.redo,
                                              color:
                                                  !_exporting &&
                                                      _controller.canRedo
                                                  ? Colors.white
                                                  : Colors.white38,
                                            ),
                                            tooltip: _l10n.text('redo'),
                                          ),
                                          const Spacer(),
                                          FilledButton(
                                            onPressed: _exporting
                                                ? null
                                                : _export,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: theme.accent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 10,
                                                  ),
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(
                                              _l10n.text('next'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                    if (project.parentVideoPath != null &&
                                        project.parentVideoPath!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          56,
                                          48,
                                          88,
                                          0,
                                        ),
                                        child: Row(
                                          children: [
                                            DuetLayoutChip(
                                              label: 'Split',
                                              selected:
                                                  project.duetLayout ==
                                                  DuetLayout.split,
                                              accent: theme.accent,
                                              onTap: () {
                                                unawaited(
                                                  _controller.apply(
                                                    SetDuetLayoutMutation(
                                                      layout: DuetLayout.split,
                                                      parentVideoPath: project
                                                          .parentVideoPath,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            DuetLayoutChip(
                                              label: 'PiP',
                                              selected:
                                                  project.duetLayout ==
                                                  DuetLayout.pip,
                                              accent: theme.accent,
                                              onTap: () {
                                                unawaited(
                                                  _controller.apply(
                                                    SetDuetLayoutMutation(
                                                      layout: DuetLayout.pip,
                                                      parentVideoPath: project
                                                          .parentVideoPath,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_selectedToolId == null)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            0,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (project.clips.isNotEmpty)
                                                ClipTimeline(
                                                  theme: theme,
                                                  project: project,
                                                  position: preview.position,
                                                  frameExtractor: widget
                                                      .config
                                                      .frameExtractor,
                                                  controller: _controller,
                                                  maxDuration:
                                                      widget.config.maxDuration,
                                                  canSplit: _gate.allows(
                                                    ComposerFeature.multiClip,
                                                  ),
                                                  canDelete: _gate.allows(
                                                    ComposerFeature.multiClip,
                                                  ),
                                                  l10n: _l10n,
                                                  onSeek: (d) {
                                                    preview.pause();
                                                    preview.seek(d);
                                                  },
                                                  onSplit: () {
                                                    widget.config.onEvent?.call(
                                                      const ComposerAnalyticsEvent(
                                                        ComposerAnalyticsEventType
                                                            .clipSplit,
                                                      ),
                                                    );
                                                  },
                                                )
                                              else
                                                PreviewScrubber(
                                                  theme: theme,
                                                  preview: preview,
                                                  bottomInset: 8,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      right: 8,
                                      top: 72,
                                      bottom: _selectedToolId == null ? 140 : 8,
                                      width: 72,
                                      child: SingleChildScrollView(
                                        child: ToolRail(
                                          theme: theme,
                                          tools: tools,
                                          selected: _selectedToolId,
                                          l10n: _l10n,
                                          onSelected: _selectTool,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedToolId != null)
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) > 280) {
                                setState(() {
                                  _selectedToolId = null;
                                  _selectedTextId = null;
                                });
                                preview.setCompareOriginal(false);
                              }
                            },
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.42,
                              ),
                              child: SingleChildScrollView(
                                child: _buildToolPanel(_selectedToolId!),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_exporting)
                      ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: _exportProgress.clamp(0.0, 1.0),
                                color: theme.accent,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_l10n.text('exporting')} '
                                '${(_exportProgress * 100).round()}%',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolPanel(String toolId) {
    final tool = _registry.byId(toolId);
    if (tool == null || !_registry.isVisible(tool, _gate)) {
      return const SizedBox.shrink();
    }
    return tool.buildPanel(
      EditorToolContext(
        controller: _controller,
        project: widget.engine.project,
        preview: _preview,
        l10n: _l10n,
        theme: widget.config.theme,
        config: widget.config,
        selectedLayerId: _selectedTextId,
        onSelectedLayerId: _onTextSelected,
      ),
    );
  }
}

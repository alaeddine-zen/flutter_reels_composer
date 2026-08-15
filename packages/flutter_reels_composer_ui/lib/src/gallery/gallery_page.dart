import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import 'gallery_preview_page.dart';
import '../l10n/composer_l10n.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.config,
    required this.engine,
    required this.onImported,
    required this.onBack,
  });

  final ComposerConfig config;
  final ComposerEngine engine;
  final ValueChanged<ProjectDocument> onImported;
  final VoidCallback onBack;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MediaPickerPort _picker;
  List<GalleryAsset> _videos = const [];
  List<GalleryAsset> _photos = const [];
  bool _loading = true;
  bool _permissionDenied = false;
  bool _importing = false;
  bool _showPreview = false;
  CapturedMedia? _previewMedia;
  bool _previewFromPhoto = false;

  /// Ordered multi-select (TikTok-style). Empty = single-tap preview mode.
  final List<GalleryAsset> _selected = [];
  bool _multiMode = false;

  static const _maxClips = 6;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _picker = widget.engine.createMediaPicker();
    widget.config.onEvent?.call(
      const ComposerAnalyticsEvent(ComposerAnalyticsEventType.galleryOpened),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    final videos = await _picker.listVideos();
    final photos = await _picker.listPhotos();
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _photos = photos;
      _permissionDenied = _picker.permissionDenied;
      _loading = false;
    });
  }

  void _toggleMulti() {
    HapticFeedback.selectionClick();
    setState(() {
      _multiMode = !_multiMode;
      if (!_multiMode) _selected.clear();
    });
  }

  void _onAssetTap(GalleryAsset asset) {
    if (_multiMode) {
      setState(() {
        final idx = _selected.indexWhere((a) => a.id == asset.id);
        if (idx >= 0) {
          _selected.removeAt(idx);
        } else if (_selected.length < _maxClips) {
          _selected.add(asset);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum $_maxClips clips')),
          );
        }
      });
      return;
    }
    unawaited(_importSingle(asset));
  }

  void _onAssetLongPress(GalleryAsset asset) {
    HapticFeedback.mediumImpact();
    setState(() {
      _multiMode = true;
      if (!_selected.any((a) => a.id == asset.id) &&
          _selected.length < _maxClips) {
        _selected.add(asset);
      }
    });
  }

  Future<void> _importSingle(GalleryAsset asset) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final media = await _picker.importAsset(asset);
      if (media == null || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                asset.isVideo
                    ? context.composerL10n.text('videoImportError')
                    : context.composerL10n.text('photoConvertError'),
              ),
            ),
          );
        }
        return;
      }
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.assetImported,
          properties: {'isVideo': media.isVideo, 'fromPhoto': !asset.isVideo},
        ),
      );
      setState(() {
        _previewMedia = media;
        _previewFromPhoto = !asset.isVideo;
        _showPreview = true;
      });
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty || _importing) return;
    setState(() => _importing = true);
    try {
      final clips = <TimelineClip>[];
      for (final asset in List<GalleryAsset>.from(_selected)) {
        final media = await _picker.importAsset(asset);
        if (media == null) continue;
        clips.add(
          TimelineClip(
            id: const Uuid().v4(),
            sourcePath: media.path,
            sourceDuration: media.duration <= Duration.zero
                ? const Duration(seconds: 3)
                : media.duration,
          ),
        );
      }
      if (!mounted) return;
      if (clips.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.composerL10n.text('noMediaImported'))),
        );
        return;
      }
      var project = ProjectDocument.fromClip(clip: clips.first);
      if (clips.length > 1) {
        project = applyProjectMutation(project, SetClipsMutation(clips));
      }
      widget.config.onEvent?.call(
        ComposerAnalyticsEvent(
          ComposerAnalyticsEventType.assetImported,
          properties: {'count': clips.length, 'multi': true},
        ),
      );
      widget.onImported(project);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _picker.dispose();
    super.dispose();
  }

  Future<void> _closePreview({bool deleteTemp = true}) async {
    final media = _previewMedia;
    setState(() {
      _showPreview = false;
      _previewMedia = null;
    });
    if (deleteTemp && media != null) {
      try {
        final f = File(media.path);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreview && _previewMedia != null) {
      return GalleryPreviewPage(
        config: widget.config,
        media: _previewMedia!,
        fromPhoto: _previewFromPhoto,
        onBack: () => _closePreview(deleteTemp: true),
        onConfirm: (project) {
          setState(() {
            _showPreview = false;
            _previewMedia = null;
          });
          widget.onImported(project);
        },
      );
    }

    final theme = widget.config.theme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: _importing ? null : widget.onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          title: Text(
            _multiMode
                ? context.composerL10n.textWith('selectedCount', {
                    'count': _selected.length,
                  })
                : context.composerL10n.text('gallery'),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: _importing ? null : _toggleMulti,
              child: Text(
                _multiMode ? 'OK' : 'Multi',
                style: TextStyle(color: theme.accent),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: theme.accent,
            labelColor: Colors.white,
            unselectedLabelColor: theme.muted,
            tabs: [
              Tab(text: context.composerL10n.text('videos')),
              Tab(text: context.composerL10n.text('photos')),
            ],
          ),
        ),
        body: Column(
          children: [
            if (widget.config.isDuet)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  context.composerL10n.text('duetHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.muted, fontSize: 12),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_permissionDenied)
                    _PermissionDenied(
                      onRetry: () async {
                        await PhotoManagerOpenSettings.open();
                        await _load();
                      },
                    )
                  else
                    TabBarView(
                      controller: _tabs,
                      children: [
                        _Grid(
                          assets: _videos,
                          emptyLabel: context.composerL10n.text('noVideo'),
                          selectedOrder: _selected.map((e) => e.id).toList(),
                          multiMode: _multiMode,
                          onTap: _onAssetTap,
                          onLongPress: _onAssetLongPress,
                        ),
                        _Grid(
                          assets: _photos,
                          emptyLabel: context.composerL10n.text('noPhoto'),
                          badge: '3s',
                          selectedOrder: _selected.map((e) => e.id).toList(),
                          multiMode: _multiMode,
                          onTap: _onAssetTap,
                          onLongPress: _onAssetLongPress,
                        ),
                      ],
                    ),
                  if (_importing)
                    ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              context.composerL10n.text('preparing'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _multiMode && _selected.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _importing ? null : _importSelected,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      context.composerL10n.textWith('addClips', {
                        'count': _selected.length,
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class PhotoManagerOpenSettings {
  static Future<void> open() => openAppSettings();
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              context.composerL10n.text('galleryPermission'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.composerL10n.text('openSettings')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.assets,
    required this.onTap,
    required this.onLongPress,
    required this.emptyLabel,
    required this.selectedOrder,
    required this.multiMode,
    this.badge,
  });

  final List<GalleryAsset> assets;
  final ValueChanged<GalleryAsset> onTap;
  final ValueChanged<GalleryAsset> onLongPress;
  final String emptyLabel;
  final List<String> selectedOrder;
  final bool multiMode;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Center(
        child: Text(emptyLabel, style: const TextStyle(color: Colors.white54)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        final order = selectedOrder.indexOf(asset.id);
        final selected = order >= 0;
        return GestureDetector(
          onTap: () => onTap(asset),
          onLongPress: () => onLongPress(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (asset.thumbnailBytes != null)
                Image.memory(asset.thumbnailBytes!, fit: BoxFit.cover)
              else
                const ColoredBox(color: Colors.white12),
              if (multiMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: selected
                        ? const Color(0xFFFF2D55)
                        : Colors.black45,
                    child: selected
                        ? Text(
                            '${order + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                  ),
                ),
              if (asset.isVideo && asset.duration > Duration.zero)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Text(
                    _fmt(asset.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                )
              else if (badge != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

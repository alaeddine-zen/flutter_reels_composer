import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
import '../../l10n/composer_l10n.dart';

/// Maps source-file transcription times onto the composition timeline
/// (trim window + clip speed + prefix offset).
List<CaptionCue> mapSourceCuesOntoClip({
  required TimelineClip clip,
  required List<CaptionCue> cues,
  required Duration timelineOffset,
}) {
  final mapped = <CaptionCue>[];
  for (final cue in cues) {
    var startSrc = cue.start;
    var endSrc = cue.end;
    if (endSrc <= clip.trimStart || startSrc >= clip.trimEnd) continue;
    if (startSrc < clip.trimStart) startSrc = clip.trimStart;
    if (endSrc > clip.trimEnd) endSrc = clip.trimEnd;
    final startLocal = startSrc - clip.trimStart;
    final endLocal = endSrc - clip.trimStart;
    final start =
        timelineOffset +
        Duration(
          microseconds: (startLocal.inMicroseconds / clip.speed).round(),
        );
    final end =
        timelineOffset +
        Duration(microseconds: (endLocal.inMicroseconds / clip.speed).round());
    if (end <= start) continue;
    mapped.add(CaptionCue(text: cue.text, start: start, end: end));
  }
  return mapped;
}

class CaptionsToolPanel extends StatefulWidget {
  const CaptionsToolPanel({
    super.key,
    required this.theme,
    required this.controller,
    required this.project,
    required this.captionEngine,
    this.preview,
    this.onGenerated,
    this.selectedLayerId,
  });

  final ComposerTheme theme;
  final ComposerController controller;
  final ProjectDocument project;
  final CaptionEngine captionEngine;
  final PreviewPort? preview;
  final VoidCallback? onGenerated;
  final String? selectedLayerId;

  @override
  State<CaptionsToolPanel> createState() => _CaptionsToolPanelState();
}

class _CaptionsToolPanelState extends State<CaptionsToolPanel> {
  final _controller = TextEditingController();
  bool _busy = false;

  List<VisualLayer> get _captions => widget.project.layers
      .where((l) => l.role == VisualLayer.roleCaption)
      .toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (widget.project.clips.isEmpty) return;
    setState(() => _busy = true);
    try {
      final cues = <CaptionCue>[];
      var offset = Duration.zero;
      for (final clip in widget.project.clips) {
        final raw = await widget.captionEngine.transcribe(clip.sourcePath);
        cues.addAll(
          mapSourceCuesOntoClip(clip: clip, cues: raw, timelineOffset: offset),
        );
        offset += clip.trimmedDuration;
      }
      if (!mounted) return;
      if (cues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.composerL10n.text('captionsEmpty'))),
        );
        return;
      }
      await widget.controller.apply(SetCaptionCuesMutation(cues));
      widget.onGenerated?.call();
      await widget.preview?.seek(cues.first.start);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyManual() async {
    final lines = _controller.text
        .split(RegExp(r'[\n.]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    HapticFeedback.selectionClick();
    var total = widget.project.duration;
    if (total < const Duration(milliseconds: 400)) {
      total = Duration(milliseconds: 1200 * lines.length);
    }
    final slice = (total.inMilliseconds / lines.length).round().clamp(
      1,
      600000,
    );
    final cues = <CaptionCue>[];
    for (var i = 0; i < lines.length; i++) {
      cues.add(
        CaptionCue(
          text: lines[i],
          start: Duration(milliseconds: i * slice),
          end: Duration(
            milliseconds: i == lines.length - 1
                ? total.inMilliseconds
                : (i + 1) * slice,
          ),
        ),
      );
    }
    await widget.controller.apply(SetCaptionCuesMutation(cues));
    widget.onGenerated?.call();
    await widget.preview?.seek(cues.first.start);
  }

  Future<void> _clear() async {
    await widget.controller.apply(const SetCaptionCuesMutation([]));
  }

  Future<void> _seekTo(VisualLayer layer) async {
    final start = layer.startAt ?? Duration.zero;
    await widget.preview?.pause();
    await widget.preview?.seek(start);
  }

  String _fmt(Duration d) {
    final s = d.inMilliseconds / 1000.0;
    return '${s.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.composerL10n.text('captions'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.captionEngine.canTranscribe) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(context.composerL10n.text('generate')),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.theme.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: _captions.isEmpty ? null : _clear,
                child: Text(context.composerL10n.text('clear')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.composerL10n.text('captionsHint'),
              hintStyle: TextStyle(color: widget.theme.muted),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _applyManual,
              child: Text(context.composerL10n.text('apply')),
            ),
          ),
          if (_captions.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                itemCount: _captions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final layer = _captions[index];
                  final selected = layer.id == widget.selectedLayerId;
                  final start = layer.startAt ?? Duration.zero;
                  final end = layer.endAt ?? widget.project.duration;
                  return Material(
                    color: selected ? Colors.white12 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        layer.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${_fmt(start)} – ${_fmt(end)}',
                        style: TextStyle(
                          color: widget.theme.muted,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => _seekTo(layer),
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

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

/// Bakes ProjectDocument edits into a final MP4 via FFmpeg (export-only).
enum FfmpegLgplVideoCodec {
  /// LGPL-native MPEG-4 Part 2. Available on every supported platform.
  mpeg4,

  /// Platform H.264 hardware encoder (VideoToolbox / MediaCodec).
  hardwareH264,
}

class FfmpegLgplExportPort
    implements
        ExportPort,
        StillImageEncoderPort,
        EffectRegistryAwareExportPort {
  FfmpegLgplExportPort({
    EffectRegistry? registry,
    this.videoCodec = FfmpegLgplVideoCodec.mpeg4,
  }) : _registry = registry;

  EffectRegistry? _registry;
  final FfmpegLgplVideoCodec videoCodec;

  String _videoEncodeArgs() {
    if (videoCodec == FfmpegLgplVideoCodec.hardwareH264) {
      if (Platform.isIOS || Platform.isMacOS) {
        return '-c:v h264_videotoolbox -b:v 6M -pix_fmt yuv420p';
      }
      if (Platform.isAndroid) {
        return '-c:v h264_mediacodec -b:v 6M -pix_fmt yuv420p';
      }
    }
    return '-c:v mpeg4 -q:v 5 -pix_fmt yuv420p';
  }

  @override
  ExportLicenseKind get licenseKind => ExportLicenseKind.lgpl;

  @override
  void attachRegistry(EffectRegistry registry) {
    _registry = registry;
  }

  /// Pure helper for tests: multi-clip projects need a concat pass.
  static bool needsConcat(ProjectDocument project) => project.clips.length > 1;

  static bool needsSpeed(ProjectDocument project) => project.hasSpeedChange;

  static bool needsDuet(ProjectDocument project) =>
      project.duetLayout.isActive &&
      project.parentVideoPath != null &&
      project.parentVideoPath!.isNotEmpty;

  /// Converts a still image into a three-second clip consumable by the editor.
  @override
  Future<CapturedMedia?> encodeStillImage(
    File image,
    Directory directory,
  ) async {
    if (!image.existsSync()) return null;
    final output = File(
      p.join(
        directory.path,
        'reels_photo_${DateTime.now().microsecondsSinceEpoch}.mp4',
      ),
    );
    final command =
        '-y -loop 1 -t 3 -i "${_escape(image.path)}" '
        '-f lavfi -t 3 -i anullsrc=channel_layout=stereo:sample_rate=44100 '
        '-vf "scale=1080:1920:force_original_aspect_ratio=decrease,'
        'pad=1080:1920:(ow-iw)/2:(oh-ih)/2" '
        '-map 0:v:0 -map 1:a:0 ${_videoEncodeArgs()} -r 30 '
        '-c:a aac -b:a 128k -shortest -movflags +faststart '
        '"${_escape(output.path)}"';
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code) ||
        !output.existsSync() ||
        output.lengthSync() == 0) {
      return null;
    }
    return CapturedMedia(
      path: output.path,
      duration: const Duration(seconds: 3),
      isVideo: true,
    );
  }

  @override
  ExportSession export(ProjectDocument project, ExportOptions options) {
    return ProgressiveExportSession((onProgress, cancelToken) async {
      onProgress(
        const ExportProgress(phase: ExportPhase.preparing, progress: 0.05),
      );
      if (project.clips.isEmpty) {
        throw StateError('No source video in project');
      }
      for (final clip in project.clips) {
        if (!File(clip.sourcePath).existsSync()) {
          throw StateError('Missing clip file: ${clip.sourcePath}');
        }
      }
      if (cancelToken.isCancelled) {
        throw StateError('Export cancelled');
      }

      final outDir =
          options.outputDirectory ??
          Directory(
            p.join(
              (await getTemporaryDirectory()).path,
              'reel_export_${DateTime.now().millisecondsSinceEpoch}',
            ),
          );
      if (!outDir.existsSync()) {
        await outDir.create(recursive: true);
      }

      // Persist a sanitized snapshot (no absolute local paths).
      final projectFile = File(p.join(outDir.path, 'project.json'));
      final sanitized = Map<String, dynamic>.from(project.toJson());
      sanitized['clips'] = project.clips
          .map((c) => {...c.toJson(), 'sourcePath': p.basename(c.sourcePath)})
          .toList();
      sanitized['audioTracks'] = project.audioTracks
          .map(
            (t) => {
              ...t.toJson(),
              if (t.sourcePath != null) 'sourcePath': p.basename(t.sourcePath!),
            },
          )
          .toList();
      await projectFile.writeAsString(jsonEncode(sanitized));

      onProgress(
        const ExportProgress(phase: ExportPhase.encoding, progress: 0.2),
      );

      final videoOut = File(p.join(outDir.path, 'reel.mp4'));
      await _bake(
        project: project,
        outputPath: videoOut.path,
        workDir: outDir,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      if (cancelToken.isCancelled) {
        throw StateError('Export cancelled');
      }

      File? cover;
      if (options.includeCover) {
        onProgress(
          const ExportProgress(phase: ExportPhase.writingCover, progress: 0.85),
        );
        cover = await _writeCover(videoOut, outDir, project);
      }

      onProgress(const ExportProgress(phase: ExportPhase.done, progress: 1));

      return ExportOutput(
        videoFile: videoOut,
        coverFile: cover,
        duration: project.duration,
      );
    });
  }

  Future<void> _bake({
    required ProjectDocument project,
    required String outputPath,
    required Directory workDir,
    required CancelToken cancelToken,
    required void Function(ExportProgress) onProgress,
  }) async {
    final sourcePath = await _resolveSourceVideo(
      project: project,
      workDir: workDir,
      cancelToken: cancelToken,
    );
    final durationSec = (project.duration.inMilliseconds / 1000.0).clamp(
      0.05,
      600.0,
    );

    final needsFilter =
        (project.activeFilterId ?? 'normal') != 'normal' &&
        project.activeFilterIntensity > 0.05;
    final textLayers = project.layers
        .where((l) => l.type == VisualLayerType.text)
        .toList();
    final untimedLayers = textLayers.where((l) => !l.isTimed).toList();
    final timedLayers = textLayers.where((l) => l.isTimed).toList();
    AudioTrack? music;
    AudioTrack? original;
    for (final t in project.audioTracks) {
      if (t.kind == AudioTrackKind.music && t.sourcePath != null) {
        music ??= t;
      } else if (t.kind == AudioTrackKind.original) {
        original ??= t;
      }
    }

    final hasMusic =
        music?.sourcePath != null && File(music!.sourcePath!).existsSync();
    final duet = needsDuet(project);
    final bakePath = duet ? p.join(workDir.path, 'user_baked.mp4') : outputPath;
    final needsReencode = needsFilter || textLayers.isNotEmpty || hasMusic;

    if (!needsReencode) {
      if (sourcePath != bakePath) {
        await File(sourcePath).copy(bakePath);
      }
      onProgress(
        const ExportProgress(phase: ExportPhase.encoding, progress: 0.7),
      );
    } else {
      final vf = <String>[];
      if (needsFilter && project.activeFilterIntensity > 0.05) {
        final eq = _eqForFilter(
          project.activeFilterId!,
          project.activeFilterIntensity,
        );
        if (eq != null) vf.add(eq);
      }

      File? overlayPng;
      if (untimedLayers.isNotEmpty) {
        overlayPng = File(p.join(workDir.path, 'text_overlay.png'));
        await _renderTextOverlayPng(
          layers: untimedLayers,
          width: project.settings.width,
          height: project.settings.height,
          output: overlayPng,
        );
      }

      final timedPngs = <File>[];
      for (var i = 0; i < timedLayers.length; i++) {
        final f = File(p.join(workDir.path, 'caption_$i.png'));
        await _renderTextOverlayPng(
          layers: [timedLayers[i]],
          width: project.settings.width,
          height: project.settings.height,
          output: f,
        );
        timedPngs.add(f);
      }

      final videoFilters = vf
          .where((e) => e != 'null' && e.isNotEmpty)
          .toList();
      final originalVol = (original?.volume ?? 1.0).clamp(0.0, 2.0);
      final musicVol = (music?.volume ?? 1.0).clamp(0.0, 2.0);
      final musicStartSec = ((music?.startOffset.inMilliseconds ?? 0) / 1000.0)
          .clamp(0.0, 36000.0);
      final musicEndSec = musicStartSec + durationSec;
      final musicTrim =
          'atrim=$musicStartSec:$musicEndSec,asetpts=PTS-STARTPTS';

      final overlayInputs = <File>[
        if (overlayPng case final File overlay) overlay,
        ...timedPngs,
      ];
      final inputFlags = StringBuffer('-y -i "${_escape(sourcePath)}"');
      for (final f in overlayInputs) {
        inputFlags.write(' -i "${_escape(f.path)}"');
      }
      if (hasMusic) {
        inputFlags.write(' -stream_loop -1 -i "${_escape(music.sourcePath!)}"');
      }

      final w = project.settings.width;
      final h = project.settings.height;
      final fc = StringBuffer();
      final baseChain = videoFilters.isEmpty
          ? '[0:v]null[v0]'
          : '[0:v]${videoFilters.join(',')}[v0]';
      fc.write(baseChain);
      var last = 'v0';
      var overlayIndex = 1;
      if (overlayPng != null) {
        fc.write(
          ';[$overlayIndex:v]format=rgba,scale=$w:$h[ov0];'
          '[$last][ov0]overlay=0:0[v$overlayIndex]',
        );
        last = 'v$overlayIndex';
        overlayIndex++;
      }
      for (var i = 0; i < timedLayers.length; i++) {
        final layer = timedLayers[i];
        final start = layer.startAt ?? Duration.zero;
        final end = layer.endAt ?? project.duration;
        final enable = FfmpegFilters.overlayEnable(start, end);
        final tag = 'ovt$i';
        final out = 'vt$i';
        fc.write(
          ';[$overlayIndex:v]format=rgba,scale=$w:$h[$tag];'
          '[$last][$tag]overlay=0:0:$enable[$out]',
        );
        last = out;
        overlayIndex++;
      }

      late final String cmd;
      if (hasMusic) {
        final musicIdx = overlayInputs.length + 1;
        fc.write(
          ';[0:a]volume=$originalVol[a0];'
          '[$musicIdx:a]volume=$musicVol,$musicTrim[a1];'
          '[a0][a1]amix=inputs=2:duration=first:dropout_transition=0[a]',
        );
        cmd =
            '$inputFlags -filter_complex "${fc.toString()}" '
            '-map "[$last]" -map "[a]" '
            '${_videoEncodeArgs()} '
            '-c:a aac -b:a 128k -shortest -movflags +faststart '
            '"$bakePath"';
      } else if (overlayInputs.isNotEmpty) {
        cmd =
            '$inputFlags -filter_complex "${fc.toString()}" '
            '-map "[$last]" -map 0:a? '
            '${_videoEncodeArgs()} '
            '-c:a aac -b:a 128k -af "volume=$originalVol" '
            '-movflags +faststart "$bakePath"';
      } else {
        cmd =
            '-y -i "${_escape(sourcePath)}" '
            '-vf "${videoFilters.join(',')}" '
            '-af "volume=$originalVol" '
            '${_videoEncodeArgs()} '
            '-c:a aac -b:a 128k -movflags +faststart '
            '"$bakePath"';
      }

      onProgress(
        const ExportProgress(phase: ExportPhase.encoding, progress: 0.45),
      );
      await _runFfmpeg(cmd, cancelToken);
      onProgress(
        const ExportProgress(phase: ExportPhase.encoding, progress: 0.75),
      );
    }

    if (duet) {
      await _composeDuet(
        userPath: bakePath,
        parentPath: project.parentVideoPath!,
        layout: project.duetLayout,
        outputPath: outputPath,
        width: project.settings.width,
        height: project.settings.height,
        durationSec: durationSec,
        cancelToken: cancelToken,
      );
    }
  }

  /// Single clip: trim + ensure AAC. Multi: normalize + concat.
  Future<String> _resolveSourceVideo({
    required ProjectDocument project,
    required Directory workDir,
    required CancelToken cancelToken,
  }) async {
    if (project.clips.length == 1) {
      final clip = project.clips.first;
      final startSec = clip.trimStart.inMilliseconds / 1000.0;
      final durationSec = (clip.sourceSpan.inMilliseconds / 1000.0).clamp(
        0.05,
        600.0,
      );
      final trimmed = File(p.join(workDir.path, 'clip0.mp4'));
      await _encodeSegment(
        inputPath: clip.sourcePath,
        outputPath: trimmed.path,
        startSec: startSec,
        durationSec: durationSec,
        speed: clip.speed,
        cancelToken: cancelToken,
      );
      return trimmed.path;
    }

    final segmentPaths = <String>[];
    for (var i = 0; i < project.clips.length; i++) {
      final clip = project.clips[i];
      final startSec = clip.trimStart.inMilliseconds / 1000.0;
      final durationSec = (clip.sourceSpan.inMilliseconds / 1000.0).clamp(
        0.05,
        600.0,
      );
      final out = File(p.join(workDir.path, 'seg_$i.mp4'));
      final w = project.settings.width;
      final h = project.settings.height;
      await _encodeSegment(
        inputPath: clip.sourcePath,
        outputPath: out.path,
        startSec: startSec,
        durationSec: durationSec,
        speed: clip.speed,
        videoFilter:
            'scale=$w:$h:force_original_aspect_ratio=decrease,'
            'pad=$w:$h:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p',
        cancelToken: cancelToken,
      );
      segmentPaths.add(out.path);
    }

    final listFile = File(p.join(workDir.path, 'concat.txt'));
    final body = segmentPaths
        .map((path) => "file '${path.replaceAll("'", r"'\''")}'")
        .join('\n');
    await listFile.writeAsString(body);

    final concatOut = File(p.join(workDir.path, 'concat.mp4'));
    final concatCmd =
        '-y -f concat -safe 0 -i "${_escape(listFile.path)}" '
        '-c copy -movflags +faststart "${concatOut.path}"';
    await _runFfmpeg(concatCmd, cancelToken);
    return concatOut.path;
  }

  Future<void> _renderTextOverlayPng({
    required List<VisualLayer> layers,
    required int width,
    required int height,
    required File output,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0x00000000),
    );

    for (final layer in layers) {
      final text = layer.text;
      if (text == null || text.isEmpty) continue;
      final fontSize = layer.fontSize * (width / 390);
      final shadows = switch (layer.textBackdrop) {
        TextBackdrop.stroke => <Shadow>[
          for (final o in const [
            Offset(-1.5, -1.5),
            Offset(1.5, -1.5),
            Offset(-1.5, 1.5),
            Offset(1.5, 1.5),
            Offset(0, -1.8),
            Offset(0, 1.8),
            Offset(-1.8, 0),
            Offset(1.8, 0),
          ])
            Shadow(blurRadius: 0, color: const Color(0xFF000000), offset: o),
        ],
        TextBackdrop.none || TextBackdrop.fill => const [
          Shadow(blurRadius: 4, color: Color(0xCC000000), offset: Offset(0, 1)),
        ],
      };
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: layer.color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: shadows,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final cx = layer.normalizedPosition.dx * width;
      final cy = layer.normalizedPosition.dy * height;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(layer.rotation);
      canvas.scale(layer.scale);
      if (layer.textBackdrop == TextBackdrop.fill) {
        final padX = 10.0 * (width / 390);
        final padY = 4.0 * (width / 390);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: tp.width + padX * 2,
            height: tp.height + padY * 2,
          ),
          Radius.circular(8 * (width / 390)),
        );
        canvas.drawRRect(rect, Paint()..color = const Color(0x8C000000));
      }
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Failed to render text overlay');
    }
    await output.writeAsBytes(bytes.buffer.asUint8List());
  }

  String? _eqForFilter(String filterId, [double intensity = 1.0]) {
    final t = intensity.clamp(0.0, 1.0);
    switch (filterId) {
      case 'warm':
        return 'eq=brightness=${0.03 * t}:saturation=${1 + 0.15 * t},hue=h=${10 * t}';
      case 'cool':
        return 'eq=brightness=${0.02 * t}:saturation=${1 + 0.1 * t},hue=h=${-12 * t}';
      case 'cinema':
        return 'eq=contrast=${1 + 0.1 * t}:saturation=${1 - 0.1 * t}:brightness=${-0.02 * t}';
      case 'vivid':
        return 'eq=contrast=${1 + 0.2 * t}:saturation=${1 + 0.35 * t}';
      case 'mono':
        return 'hue=s=${1 - t}';
      case 'soft':
        return 'eq=brightness=${0.05 * t}:contrast=${1 - 0.05 * t}:saturation=${1 + 0.05 * t}';
      case 'night':
        return 'eq=brightness=${-0.08 * t}:contrast=${1 + 0.15 * t}:saturation=${1 - 0.15 * t},hue=h=${-20 * t}';
      case 'sunset':
        return 'eq=brightness=${0.04 * t}:saturation=${1 + 0.2 * t},hue=h=${18 * t}';
      case 'fade':
        return 'eq=contrast=${1 - 0.1 * t}:brightness=${0.06 * t}:saturation=${1 - 0.15 * t}';
      default:
        final desc = _registry?[filterId];
        if (desc is LutColorEffectDescriptor) {
          return 'eq=saturation=${1 + 0.05 * t}';
        }
        return null;
    }
  }

  /// Encode a trimmed segment with AAC. Falls back to anullsrc if source has no audio.
  Future<void> _encodeSegment({
    required String inputPath,
    required String outputPath,
    required double startSec,
    required double durationSec,
    String? videoFilter,
    double speed = 1.0,
    required CancelToken cancelToken,
  }) async {
    final speedVf = FfmpegFilters.setpts(speed);
    var vfBody = videoFilter ?? '';
    if (speedVf.isNotEmpty) {
      vfBody = vfBody.isEmpty ? speedVf : '$vfBody,$speedVf';
    }
    final vf = vfBody.isEmpty ? '' : '-vf "$vfBody" ';
    final atempo = FfmpegFilters.atempoChain(speed);
    final af = atempo.isEmpty ? '' : '-af "$atempo" ';
    final withAudio =
        '-y -ss $startSec -t $durationSec -i "${_escape(inputPath)}" '
        '$vf$af'
        '${_videoEncodeArgs()} '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '-movflags +faststart "$outputPath"';
    try {
      await _runFfmpeg(withAudio, cancelToken);
      return;
    } catch (_) {
      // Video-only sources (legacy photo clips, muted imports).
    }
    final outDur = (durationSec / speed.clamp(0.3, 3.0)).clamp(0.05, 600.0);
    final silent =
        '-y -ss $startSec -t $durationSec -i "${_escape(inputPath)}" '
        '-f lavfi -t $outDur -i anullsrc=channel_layout=stereo:sample_rate=44100 '
        '$vf'
        '-map 0:v:0 -map 1:a:0 '
        '${_videoEncodeArgs()} '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k -shortest '
        '-movflags +faststart "$outputPath"';
    await _runFfmpeg(silent, cancelToken);
  }

  Future<void> _composeDuet({
    required String userPath,
    required String parentPath,
    required DuetLayout layout,
    required String outputPath,
    required int width,
    required int height,
    required double durationSec,
    required CancelToken cancelToken,
  }) async {
    final halfH = height ~/ 2;
    late final String vchain;
    if (layout == DuetLayout.pip) {
      vchain =
          '[1:v]scale=$width:$height:force_original_aspect_ratio=decrease,'
          'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1[base];'
          '[0:v]scale=360:640:force_original_aspect_ratio=decrease,'
          'pad=360:640:(ow-iw)/2:(oh-ih)/2,setsar=1[pip];'
          '[base][pip]overlay=W-w-24:72[v]';
    } else {
      vchain =
          '[0:v]scale=$width:$halfH:force_original_aspect_ratio=decrease,'
          'pad=$width:$halfH:(ow-iw)/2:(oh-ih)/2,setsar=1[top];'
          '[1:v]scale=$width:$halfH:force_original_aspect_ratio=decrease,'
          'pad=$width:$halfH:(ow-iw)/2:(oh-ih)/2,setsar=1[bot];'
          '[top][bot]vstack=inputs=2[v]';
    }
    final durSec = durationSec.clamp(0.05, 600.0);
    final cmd =
        '-y -i "${_escape(parentPath)}" -i "${_escape(userPath)}" '
        '-filter_complex '
        '"$vchain;'
        '[0:a]volume=0.4[a0];[1:a]volume=1.0[a1];'
        '[a0][a1]amix=inputs=2:duration=shortest:dropout_transition=0[a]" '
        '-map "[v]" -map "[a]" -t $durSec '
        '${_videoEncodeArgs()} '
        '-c:a aac -b:a 128k -shortest -movflags +faststart '
        '"$outputPath"';
    try {
      await _runFfmpeg(cmd, cancelToken);
    } catch (_) {
      final silent =
          '-y -i "${_escape(parentPath)}" -i "${_escape(userPath)}" '
          '-filter_complex "$vchain" '
          '-map "[v]" -map 1:a? -t $durSec '
          '${_videoEncodeArgs()} '
          '-c:a aac -b:a 128k -shortest -movflags +faststart '
          '"$outputPath"';
      await _runFfmpeg(silent, cancelToken);
    }
  }

  Future<void> _runFfmpeg(String command, CancelToken cancelToken) async {
    if (cancelToken.isCancelled) throw StateError('Export cancelled');
    final session = await FFmpegKit.executeAsync(command, null);
    // Poll until done so cancel can interrupt.
    while (!cancelToken.isCancelled) {
      final code = await session.getReturnCode();
      if (code != null) {
        if (!ReturnCode.isSuccess(code)) {
          final logs = await session.getAllLogsAsString();
          throw StateError('FFmpeg export failed: ${logs ?? code}');
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await FFmpegKit.cancel();
    throw StateError('Export cancelled');
  }

  Future<File?> _writeCover(
    File video,
    Directory outDir,
    ProjectDocument project,
  ) async {
    try {
      if (project.cover.customPath != null &&
          File(project.cover.customPath!).existsSync()) {
        final dest = File(p.join(outDir.path, 'cover.jpg'));
        await File(project.cover.customPath!).copy(dest.path);
        return dest;
      }
      final offsetSec = project.cover.timeOffset.inMilliseconds / 1000.0;
      final dest = File(p.join(outDir.path, 'cover.jpg'));
      final cmd =
          '-y -ss $offsetSec -i "${_escape(video.path)}" -frames:v 1 -q:v 2 '
          '"${dest.path}"';
      await _runFfmpeg(cmd, CancelToken());
      if (dest.existsSync()) return dest;
    } catch (error) {
      debugPrint('FfmpegLgplExportPort: cover extract failed: $error');
    }
    return null;
  }

  String _escape(String path) => path.replaceAll('"', r'\"');
}

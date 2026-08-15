import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart'
    hide FfmpegFilters;

import 'ffmpeg_color_matrix.dart';
import 'ffmpeg_filters.dart';

/// Bakes ProjectDocument edits into a final MP4 via FFmpeg (export-only).
class FfmpegGplExportPort
    implements
        ExportPort,
        StillImageEncoderPort,
        EffectRegistryAwareExportPort {
  FfmpegGplExportPort({EffectRegistry? registry}) : _registry = registry;

  EffectRegistry? _registry;

  ExportCapabilitySet get capabilities => ExportCapabilitySet.ffmpegV1;

  String _videoEncodeArgs([int bitrate = 6_000_000]) {
    final b = '${(bitrate / 1e6).clamp(0.4, 50.0).toStringAsFixed(1)}M';
    return '-c:v libx264 -preset veryfast -b:v $b -pix_fmt yuv420p';
  }

  @override
  ExportLicenseKind get licenseKind => ExportLicenseKind.gpl;

  @override
  void attachRegistry(EffectRegistry registry) {
    _registry = registry;
  }

  /// Pure helper for tests: multi-clip projects need a concat pass.
  static bool needsConcat(ProjectDocument project) =>
      ExportRecipe.fromProject(project).needsConcat;

  static bool needsSpeed(ProjectDocument project) =>
      ExportRecipe.fromProject(project).needsSpeed;

  static bool needsDuet(ProjectDocument project) =>
      ExportRecipe.fromProject(project).needsDuet;

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
        '-y -loop 1 -t 3 -i "${ffmpegEscapePath(image.path)}" '
        '-f lavfi -t 3 -i anullsrc=channel_layout=stereo:sample_rate=44100 '
        '-vf "${FfmpegFilters.canvasCover(width: 1080, height: 1920, fps: 30)}" '
        '-map 0:v:0 -map 1:a:0 '
        '-c:v libx264 -tune stillimage -pix_fmt yuv420p -r 30 '
        '-c:a aac -b:a 128k -shortest -movflags +faststart '
        '"${ffmpegEscapePath(output.path)}"';
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
        throw const ComposerException('no_clips', 'No source video in project');
      }
      for (final clip in project.clips) {
        if (!File(clip.sourcePath).existsSync()) {
          throw MissingClipException(clip.sourcePath);
        }
      }
      final recipe = ExportRecipe.fromProject(project, registry: _registry);
      if (recipe.needsDuet) {
        final parent = project.parentVideoPath;
        if (parent == null || parent.isEmpty || !File(parent).existsSync()) {
          throw MissingClipException(parent ?? '');
        }
      }
      if (cancelToken.isCancelled) {
        throw const ExportCancelledException();
      }
      final unsupported = capabilities.unsupportedOperations(
        recipe.requiredOperations,
      );
      if (unsupported.isNotEmpty) {
        throw UnsupportedExportException(unsupported);
      }

      final recipe = ExportRecipe.fromProject(project, registry: _registry);
      final unsupported = capabilities.unsupportedOperations(
        recipe.requiredOperations,
      );
      if (unsupported.isNotEmpty) {
        throw UnsupportedExportException(unsupported);
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
        recipe: recipe,
        outputPath: videoOut.path,
        workDir: outDir,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      if (cancelToken.isCancelled) {
        throw const ExportCancelledException();
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
    required ExportRecipe recipe,
    required String outputPath,
    required Directory workDir,
    required CancelToken cancelToken,
    required void Function(ExportProgress) onProgress,
  }) async {
    final sourcePath = await _resolveSourceVideo(
      project: project,
      recipe: recipe,
      workDir: workDir,
      cancelToken: cancelToken,
    );
    final durationSec = (recipe.duration.inMilliseconds / 1000.0).clamp(
      0.05,
      600.0,
    );

    final needsFilter = recipe.needsColor;
    final textLayers = recipe.textOverlays;
    final untimedLayers = textLayers.where((l) => !l.isTimed).toList();
    final timedLayers = textLayers.where((l) => l.isTimed).toList();
    final music = recipe.music;
    final original = recipe.originalAudio;

    final hasMusic =
        music?.sourcePath != null && File(music!.sourcePath!).existsSync();
    final duet = recipe.needsDuet;
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
      if (needsFilter) {
        final filter = ColorMatrixFfmpeg.toFilter(recipe.colorGrade.matrix);
        if (filter != null) vf.add(filter);
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
      final originalVol = (original?.volume ?? 1.0).clamp(0.0, 1.0);
      final musicVol = (music?.volume ?? 1.0).clamp(0.0, 1.0);
      final musicStartSec = ((music?.startOffset.inMilliseconds ?? 0) / 1000.0)
          .clamp(0.0, 36000.0);
      final musicEndSec = musicStartSec + durationSec;
      final musicTrim =
          'atrim=$musicStartSec:$musicEndSec,asetpts=PTS-STARTPTS';

      final overlayInputs = <File>[
        if (overlayPng case final File overlay) overlay,
        ...timedPngs,
      ];
      final inputFlags = StringBuffer(
        '-y -i "${ffmpegEscapePath(sourcePath)}"',
      );
      for (final f in overlayInputs) {
        inputFlags.write(' -i "${ffmpegEscapePath(f.path)}"');
      }
      if (hasMusic) {
        inputFlags.write(
          ' -stream_loop -1 -i "${ffmpegEscapePath(music.sourcePath!)}"',
        );
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
            '${_videoEncodeArgs(project.settings.bitrate)} '
            '-c:a aac -b:a 128k -shortest -movflags +faststart '
            '"$bakePath"';
      } else if (overlayInputs.isNotEmpty) {
        cmd =
            '$inputFlags -filter_complex "${fc.toString()}" '
            '-map "[$last]" -map 0:a? '
            '${_videoEncodeArgs(project.settings.bitrate)} '
            '-c:a aac -b:a 128k -af "volume=$originalVol" '
            '-movflags +faststart "$bakePath"';
      } else {
        cmd =
            '-y -i "${ffmpegEscapePath(sourcePath)}" '
            '-vf "${videoFilters.join(',')}" '
            '-af "volume=$originalVol" '
            '${_videoEncodeArgs(project.settings.bitrate)} '
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
        bitrate: project.settings.bitrate,
        cancelToken: cancelToken,
      );
    }
  }

  /// Every segment is canvas-cover cropped (preview `BoxFit.cover`), including
  /// the single-clip case. Multi-clip then concatenates.
  Future<String> _resolveSourceVideo({
    required ProjectDocument project,
    required ExportRecipe recipe,
    required Directory workDir,
    required CancelToken cancelToken,
  }) async {
    final segmentPaths = <String>[];
    for (var i = 0; i < recipe.segments.length; i++) {
      final segment = recipe.segments[i];
      final startSec = segment.trimStart.inMilliseconds / 1000.0;
      final durationSec = (segment.sourceSpan.inMilliseconds / 1000.0).clamp(
        0.05,
        600.0,
      );
      final out = File(
        p.join(
          workDir.path,
          recipe.segments.length == 1 ? 'clip0.mp4' : 'seg_$i.mp4',
        ),
      );
      await _encodeSegment(
        inputPath: segment.sourcePath,
        outputPath: out.path,
        startSec: startSec,
        durationSec: durationSec,
        speed: segment.speed,
        isImage: segment.isImage,
        settings: project.settings,
        fadeIn: segment.fadeIn,
        fadeOut: segment.transitionOut,
        cancelToken: cancelToken,
      );
      segmentPaths.add(out.path);
    }
    if (segmentPaths.length == 1) return segmentPaths.first;

    final listFile = File(p.join(workDir.path, 'concat.txt'));
    final body = segmentPaths
        .map((path) => "file '${path.replaceAll("'", r"'\''")}'")
        .join('\n');
    await listFile.writeAsString(body);

    final concatOut = File(p.join(workDir.path, 'concat.mp4'));
    final concatCmd =
        '-y -f concat -safe 0 -i "${ffmpegEscapePath(listFile.path)}" '
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
        textDirection: textLooksRtl(text)
            ? TextDirection.rtl
            : TextDirection.ltr,
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

  /// Encode a trimmed segment with AAC. Falls back to anullsrc if source has no audio.
  Future<void> _encodeSegment({
    required String inputPath,
    required String outputPath,
    required double startSec,
    required double durationSec,
    required VideoSettings settings,
    required CancelToken cancelToken,
    double speed = 1.0,
    bool isImage = false,
    Duration fadeIn = Duration.zero,
    Duration fadeOut = Duration.zero,
  }) async {
    final outDur = (durationSec / speed.clamp(0.3, 3.0)).clamp(0.05, 600.0);
    final vfBody = FfmpegFilters.join([
      FfmpegFilters.canvasCover(
        width: settings.width,
        height: settings.height,
        fps: settings.fps,
      ),
      FfmpegFilters.setpts(speed),
      FfmpegFilters.dipToBlack(
        durationSec: outDur,
        fadeInSec: fadeIn.inMilliseconds / 1000.0,
        fadeOutSec: fadeOut.inMilliseconds / 1000.0,
      ),
    ]);
    final vf = '-vf "$vfBody" ';
    final encode = _videoEncodeArgs(settings.bitrate);
    final fps = settings.fps.clamp(1, 120);
    final stillTune = isImage ? '-tune stillimage ' : '';

    if (isImage) {
      final still =
          '-y -loop 1 -t $outDur -i "${ffmpegEscapePath(inputPath)}" '
          '-f lavfi -t $outDur -i anullsrc=channel_layout=stereo:sample_rate=44100 '
          '$vf'
          '-map 0:v:0 -map 1:a:0 '
          '$encode $stillTune-r $fps '
          '-c:a aac -ar 44100 -ac 2 -b:a 128k -shortest '
          '-movflags +faststart "$outputPath"';
      await _runFfmpeg(still, cancelToken);
      return;
    }

    final atempo = FfmpegFilters.atempoChain(speed);
    final af = atempo.isEmpty ? '' : '-af "$atempo" ';
    final withAudio =
        '-y -ss $startSec -t $durationSec -i "${ffmpegEscapePath(inputPath)}" '
        '$vf$af'
        '$encode '
        '-c:a aac -ar 44100 -ac 2 -b:a 128k '
        '-movflags +faststart "$outputPath"';
    try {
      await _runFfmpeg(withAudio, cancelToken);
      return;
    } catch (_) {
      // Video-only sources (legacy photo clips, muted imports).
    }
    final silent =
        '-y -ss $startSec -t $durationSec -i "${ffmpegEscapePath(inputPath)}" '
        '-f lavfi -t $outDur -i anullsrc=channel_layout=stereo:sample_rate=44100 '
        '$vf'
        '-map 0:v:0 -map 1:a:0 '
        '$encode '
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
    required int bitrate,
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
        '-y -i "${ffmpegEscapePath(parentPath)}" -i "${ffmpegEscapePath(userPath)}" '
        '-filter_complex '
        '"$vchain;'
        '[0:a]volume=0.4[a0];[1:a]volume=1.0[a1];'
        '[a0][a1]amix=inputs=2:duration=shortest:dropout_transition=0[a]" '
        '-map "[v]" -map "[a]" -t $durSec '
        '${_videoEncodeArgs(bitrate)} '
        '-c:a aac -b:a 128k -shortest -movflags +faststart '
        '"$outputPath"';
    try {
      await _runFfmpeg(cmd, cancelToken);
    } catch (_) {
      final silent =
          '-y -i "${ffmpegEscapePath(parentPath)}" -i "${ffmpegEscapePath(userPath)}" '
          '-filter_complex "$vchain" '
          '-map "[v]" -map 1:a? -t $durSec '
          '${_videoEncodeArgs(bitrate)} '
          '-c:a aac -b:a 128k -shortest -movflags +faststart '
          '"$outputPath"';
      await _runFfmpeg(silent, cancelToken);
    }
  }

  Future<void> _runFfmpeg(String command, CancelToken cancelToken) async {
    if (cancelToken.isCancelled) throw const ExportCancelledException();
    final finished = Completer<void>();
    final session = await FFmpegKit.executeAsync(command, (_) {
      if (!finished.isCompleted) finished.complete();
    });
    while (!finished.isCompleted) {
      if (cancelToken.isCancelled) {
        await FFmpegKit.cancel();
        throw const ExportCancelledException();
      }
      await Future.any([
        finished.future,
        Future<void>.delayed(const Duration(milliseconds: 200)),
      ]);
    }
    if (cancelToken.isCancelled) {
      await FFmpegKit.cancel();
      throw const ExportCancelledException();
    }
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw StateError('FFmpeg export failed: ${logs ?? code}');
    }
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
          '-y -ss $offsetSec -i "${ffmpegEscapePath(video.path)}" -frames:v 1 -q:v 2 '
          '"${ffmpegEscapePath(dest.path)}"';
      await _runFfmpeg(cmd, CancelToken());
      if (dest.existsSync()) return dest;
    } catch (error) {
      debugPrint('FfmpegGplExportPort: cover extract failed: $error');
    }
    return null;
  }
}

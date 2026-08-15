import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';

class LocalMediaPicker implements MediaPickerPort {
  LocalMediaPicker({this.photoClipEncoder});

  /// Optional still-to-clip encoder (usually the LGPL FFmpeg adapter).
  final Future<CapturedMedia?> Function(File image, Directory dir)?
  photoClipEncoder;

  static const photoClipDuration = Duration(seconds: 3);

  Future<bool> _ensurePermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  @override
  bool get permissionDenied => _permissionDenied;
  bool _permissionDenied = false;

  Future<List<GalleryAsset>> _list({
    required RequestType type,
    int page = 0,
    int pageSize = 60,
  }) async {
    if (!await _ensurePermission()) {
      _permissionDenied = true;
      return const [];
    }
    _permissionDenied = false;
    final albums = await PhotoManager.getAssetPathList(
      type: type,
      onlyAll: true,
    );
    if (albums.isEmpty) return const [];
    final assets = await albums.first.getAssetListPaged(
      page: page,
      size: pageSize,
    );
    final out = <GalleryAsset>[];
    // Parallel thumbs with a small concurrency cap.
    const chunk = 8;
    for (var i = 0; i < assets.length; i += chunk) {
      final slice = assets.skip(i).take(chunk);
      final mapped = await Future.wait(
        slice.map((asset) async {
          Uint8List? thumb;
          try {
            thumb = await asset.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );
          } catch (_) {}
          return GalleryAsset(
            id: asset.id,
            thumbnailBytes: thumb,
            duration: Duration(seconds: asset.duration),
            isVideo: asset.type == AssetType.video,
            width: asset.width,
            height: asset.height,
          );
        }),
      );
      out.addAll(mapped);
    }
    return out;
  }

  @override
  Future<List<GalleryAsset>> listVideos({int page = 0, int pageSize = 60}) {
    return _list(type: RequestType.video, page: page, pageSize: pageSize);
  }

  @override
  Future<List<GalleryAsset>> listPhotos({int page = 0, int pageSize = 60}) {
    return _list(type: RequestType.image, page: page, pageSize: pageSize);
  }

  @override
  Future<CapturedMedia?> importAsset(GalleryAsset asset) async {
    if (!await _ensurePermission()) return null;
    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) return null;
    final file = await entity.file;
    if (file == null) return null;

    final dir = await getTemporaryDirectory();

    if (!asset.isVideo) {
      return _importPhoto(file, dir);
    }

    final ext = p.extension(file.path).isEmpty
        ? '.mp4'
        : p.extension(file.path);
    final dest = File(
      p.join(
        dir.path,
        'reel_import_${DateTime.now().millisecondsSinceEpoch}$ext',
      ),
    );
    await file.copy(dest.path);

    var duration = Duration(seconds: entity.duration);
    if (duration == Duration.zero) {
      try {
        final controller = VideoPlayerController.file(dest);
        await controller.initialize();
        duration = controller.value.duration;
        await controller.dispose();
      } catch (_) {}
    }

    return CapturedMedia(path: dest.path, duration: duration, isVideo: true);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<PickedAudio?> pickAudio() async {
    // iOS: FileType.audio opens MPMediaPicker / Apple Music and requires
    // NSAppleMusicUsageDescription — missing key = instant process kill.
    // Also DRM Apple Music tracks return null paths. Use Files (custom
    // extensions) instead of the Apple Music picker.
    try {
      final FilePickerResult? result;
      if (Platform.isIOS) {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'caf'],
          allowMultiple: false,
          withData: true,
        );
      } else {
        result = await FilePicker.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
          withData: false,
        );
      }
      final files = result?.files;
      if (files == null || files.isEmpty) return null;
      final file = files.first;
      final dir = await getTemporaryDirectory();
      final rawName = file.name.isEmpty ? 'audio' : file.name;
      final ext = p.extension(rawName).isEmpty
          ? (file.extension == null || file.extension!.isEmpty
                ? '.m4a'
                : '.${file.extension}')
          : p.extension(rawName);
      final dest = File(
        p.join(
          dir.path,
          'reel_audio_${DateTime.now().millisecondsSinceEpoch}$ext',
        ),
      );

      if (file.bytes != null && file.bytes!.isNotEmpty) {
        await dest.writeAsBytes(file.bytes!, flush: true);
      } else {
        final path = file.path;
        if (path == null || path.isEmpty) return null;
        final source = File(path);
        if (!source.existsSync()) return null;
        await source.copy(dest.path);
      }

      if (!dest.existsSync() || dest.lengthSync() == 0) return null;
      return PickedAudio(path: dest.path, title: rawName);
    } catch (_) {
      return null;
    }
  }

  Future<CapturedMedia?> _importPhoto(File image, Directory dir) async {
    final ext = p.extension(image.path).isEmpty
        ? '.jpg'
        : p.extension(image.path);
    final dest = File(
      p.join(
        dir.path,
        'reel_photo_${DateTime.now().millisecondsSinceEpoch}$ext',
      ),
    );
    await image.copy(dest.path);
    if (!dest.existsSync() || dest.lengthSync() == 0) {
      final encoder = photoClipEncoder;
      if (encoder == null) return null;
      return encoder(image, dir);
    }
    return CapturedMedia(
      path: dest.path,
      duration: photoClipDuration,
      isVideo: false,
    );
  }
}

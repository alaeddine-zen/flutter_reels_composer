import 'package:flutter/widgets.dart';

import '../domain/project/project_document.dart';

abstract class PreviewPort extends ChangeNotifier {
  ProjectDocument get project;
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get isInitialized;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setLooping(bool looping);
  void setCompareOriginal(bool value) {}
  Widget buildPreview({Key? key, bool showTextLayers = true});
  Future<void> disposePreview();
}

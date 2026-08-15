enum ComposerAnalyticsEventType {
  opened,
  permissionDenied,
  recordStarted,
  recordStopped,
  galleryOpened,
  assetImported,
  toolSelected,
  filterSelected,
  textAdded,
  musicSelected,
  speedChanged,
  captionsGenerated,
  templateApplied,
  undo,
  redo,
  effectPackLoadFailed,
  templateCatalogLoadFailed,
  duetStarted,
  exportStarted,
  exportCompleted,
  exportFailed,
  draftSaved,
  draftRestored,
  cancelled,
  completed,
}

class ComposerAnalyticsEvent {
  const ComposerAnalyticsEvent(this.type, {this.properties = const {}});

  final ComposerAnalyticsEventType type;
  final Map<String, dynamic> properties;
}

typedef ComposerAnalyticsCallback = void Function(ComposerAnalyticsEvent event);

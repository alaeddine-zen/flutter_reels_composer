/// Drop-in TikTok/Snap-style video composer for Flutter.
///
/// Stable host surface: [FlutterReelsComposer.open], [ComposerConfig],
/// catalogs, theme, l10n, ports, and [EditorTool] extras. Do not import
/// `flutter_reels_composer_gpl` in the same app — the native FFmpeg builds
/// are mutually exclusive.
library;

export 'package:flutter_reels_composer_core/flutter_reels_composer_core.dart';
export 'package:flutter_reels_composer_ui/flutter_reels_composer_ui.dart';
export 'package:flutter_reels_composer_local/flutter_reels_composer_local.dart';
export 'package:flutter_reels_composer_export_lgpl/flutter_reels_composer_export_lgpl.dart';
export 'src/flutter_reels_composer.dart';

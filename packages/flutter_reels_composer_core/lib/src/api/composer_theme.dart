import 'package:flutter/material.dart';

class ComposerTheme {
  const ComposerTheme({
    this.background = const Color(0xFF000000),
    this.foreground = const Color(0xFFFFFFFF),
    this.accent = const Color(0xFFFF2D55),
    this.secondary = const Color(0xFF2C2C2E),
    this.sheet = const Color(0xFF161616),
    this.muted = const Color(0x99FFFFFF),
    this.recordRed = const Color(0xFFFF3B30),
    this.toolIconSize = 26,
    this.recordButtonSize = 78,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final Color secondary;

  /// Modal sheets, dialogs, and editor tool panels.
  final Color sheet;
  final Color muted;
  final Color recordRed;
  final double toolIconSize;
  final double recordButtonSize;

  static const snapTikTok = ComposerTheme();

  ThemeData toThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: secondary,
        surface: background,
        onPrimary: foreground,
        onSurface: foreground,
      ),
      dialogTheme: DialogThemeData(backgroundColor: sheet),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        modalBackgroundColor: sheet,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: foreground),
      useMaterial3: true,
    );
  }
}

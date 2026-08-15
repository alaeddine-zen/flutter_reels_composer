/// Heuristic for overlay text direction. Not a full bidi implementation.
bool textLooksRtl(String text) => RegExp(r'[\u0590-\u08FF]').hasMatch(text);
